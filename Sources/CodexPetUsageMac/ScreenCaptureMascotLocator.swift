import AppKit
import CoreGraphics
import Foundation
import OSLog
import ScreenCaptureKit

enum MascotCaptureRefreshPolicy {
    static let movementInterval: TimeInterval = 1
    static let missingResultRetryInterval: TimeInterval = 5

    static func shouldCapture(hasCachedResult: Bool,
                              inputChanged: Bool,
                              lastAttempt: TimeInterval?,
                              now: TimeInterval) -> Bool {
        guard !hasCachedResult || inputChanged else { return false }
        guard let lastAttempt else { return true }
        let interval = hasCachedResult ? movementInterval : missingResultRetryInterval
        return now - lastAttempt >= interval
    }
}

enum PixelMascotLocationCapability {
    static func isSupported(on operatingSystemVersion: OperatingSystemVersion) -> Bool {
        operatingSystemVersion.majorVersion >= 14
    }

    static func shouldRequestAuthorization(on operatingSystemVersion: OperatingSystemVersion,
                                           hasPermission: Bool) -> Bool {
        isSupported(on: operatingSystemVersion) && !hasPermission
    }
}

enum ScreenRecordingAuthorizationStatus {
    static func menuTitle(on operatingSystemVersion: OperatingSystemVersion,
                          hasPermission: Bool) -> String {
        guard PixelMascotLocationCapability.isSupported(on: operatingSystemVersion) else {
            return "定位精度：使用估算（像素级定位需要 macOS 14+）"
        }
        return hasPermission
            ? "屏幕录制：已授权（像素级定位）"
            : "屏幕录制：未授权（使用估算）"
    }
}

enum MascotCaptureResultValidation {
    static func isPlausible(_ detected: CGRect,
                            estimatedFrame: CGRect,
                            container: CGRect) -> Bool {
        guard container.contains(detected), estimatedFrame.width > 0, estimatedFrame.height > 0 else {
            return false
        }
        let centerDistance = hypot(detected.midX - estimatedFrame.midX,
                                   detected.midY - estimatedFrame.midY)
        let maximumCenterDistance = max(container.width, container.height) * 0.28
        let aspectRatio = detected.width / detected.height
        let fillsTransparentWindow = detected.width >= container.width * 0.85
            || detected.height >= container.height * 0.85
        // Pet scale is user-controlled, so default-size ratios are not a
        // validity check. The task card is wide; an accidental whole-window
        // capture fills the transparent container. Both are rejected here.
        return centerDistance <= maximumCenterDistance
            && (0.35...1.25).contains(aspectRatio)
            && !fillsTransparentWindow
    }
}

/// Finds the visible mascot inside Codex's transparent Electron window.
///
/// Codex's global state contains the overlay container, but recent builds do
/// not always persist the nested `mascot` rectangle. ScreenCaptureKit lets us
/// use the actual rendered content as the source of truth instead of guessing
/// which edge of the container the mascot occupies.
final class ScreenCaptureMascotLocator: @unchecked Sendable {
    private static let logger = Logger(subsystem: "com.codexusageloop.mac", category: "petGeometry")
    private static let measurementSampleCount = 3
    private static let measurementSampleDelay: TimeInterval = 0.06
    private struct Result {
        let frame: CGRect
        let container: CGRect
        let timestamp: TimeInterval
    }

    private let lock = NSLock()
    private var results: [CGWindowID: Result] = [:]
    private var pending: Set<CGWindowID> = []
    private var lastInputs: [CGWindowID: (container: CGRect, estimate: CGRect, layoutSignature: String)] = [:]
    private var lastAttempts: [CGWindowID: TimeInterval] = [:]
    private var generation: UInt = 0
    private var shareableContentTask: Task<Void, Never>?
    private var windowsByID: [CGWindowID: SCWindow] = [:]
    private var lastContentQuery: TimeInterval = 0
    private var screenRecordingUnavailable = false
    private var screenRecordingAuthorizationRequested = false

    func reset() {
        lock.lock()
        generation &+= 1
        results.removeAll()
        pending.removeAll()
        lastInputs.removeAll()
        lastAttempts.removeAll()
        screenRecordingUnavailable = false
        lock.unlock()
    }

    func requestScreenRecordingAuthorization() {
        let operatingSystemVersion = ProcessInfo.processInfo.operatingSystemVersion
        guard PixelMascotLocationCapability.isSupported(on: operatingSystemVersion) else {
            Self.logger.notice("pet capture authorization ignored reason=unsupportedMacOS")
            return
        }
        guard PixelMascotLocationCapability.shouldRequestAuthorization(
            on: operatingSystemVersion,
            hasPermission: CGPreflightScreenCaptureAccess()
        ) else { return }
        let shouldRequest = synchronized {
            guard !screenRecordingAuthorizationRequested else { return false }
            screenRecordingAuthorizationRequested = true
            return true
        }
        guard shouldRequest else { return }
        // Consent is never requested automatically. It only follows an
        // explicit menu action, so it cannot compete with System Settings'
        // required quit-and-reopen flow.
        DispatchQueue.main.async {
            let grantedImmediately = CGRequestScreenCaptureAccess()
            Self.logger.notice("pet capture authorization userInitiated grantedImmediately=\(grantedImmediately, privacy: .public)")
        }
    }

    func frame(for windowID: CGWindowID,
               container: CGRect,
               estimatedFrame: CGRect,
               layoutSignature: String) -> (frame: CGRect, source: PetGeometrySource) {
        guard windowID != 0 else { return (estimatedFrame, .anchoredFallback) }
        guard PixelMascotLocationCapability.isSupported(
            on: ProcessInfo.processInfo.operatingSystemVersion
        ) else {
            return (estimatedFrame, .anchoredFallback)
        }
        let now = Date.timeIntervalSinceReferenceDate

        lock.lock()
        let cached = results[windowID]
        let previousInput = lastInputs[windowID]
        let lastAttempt = lastAttempts[windowID]
        let captureUnavailable = screenRecordingUnavailable
        let inputChanged: Bool
        if let previous = lastInputs[windowID] {
            inputChanged = Self.inputChanged(
                previousContainer: previous.container,
                previousEstimate: previous.estimate,
                previousLayoutSignature: previous.layoutSignature,
                container: container,
                estimate: estimatedFrame,
                layoutSignature: layoutSignature
            )
        } else {
            inputChanged = true
        }
        let shouldRefresh = !captureUnavailable && MascotCaptureRefreshPolicy.shouldCapture(
            hasCachedResult: cached != nil,
            inputChanged: inputChanged,
            lastAttempt: lastAttempt,
            now: now
        )
        let isPending = pending.contains(windowID)
        let requestGeneration: UInt?
        if shouldRefresh && !isPending {
            pending.insert(windowID)
            lastInputs[windowID] = (container, estimatedFrame, layoutSignature)
            lastAttempts[windowID] = now
            requestGeneration = generation
        } else {
            requestGeneration = nil
        }
        lock.unlock()

        if let requestGeneration {
            let reason = cached == nil ? "noCachedMeasurement" : "layoutInputChanged"
            Self.logger.debug("pet capture requested reason=\(reason, privacy: .public) window=\(windowID, privacy: .public)")
            refresh(windowID: windowID,
                    container: container,
                    estimatedFrame: estimatedFrame,
                    generation: requestGeneration)
        }
        // Never replace a confirmed frame with a raw estimate while its next
        // asynchronous capture is pending. Project it through the container
        // movement instead, so pet dragging remains smooth and the diameter
        // stays stable.
        if let cached {
            guard inputChanged, previousInput != nil else { return (cached.frame, .measured) }
            return (Self.projectedFrame(cached.frame,
                                        from: cached.container,
                                        to: container), .measured)
        }
        return (estimatedFrame, .anchoredFallback)
    }

    static func projectedFrame(_ frame: CGRect,
                               from previousContainer: CGRect,
                               to currentContainer: CGRect) -> CGRect {
        guard previousContainer.width > 0, previousContainer.height > 0 else { return frame }
        return CGRect(
            x: currentContainer.minX + (frame.minX - previousContainer.minX) / previousContainer.width * currentContainer.width,
            y: currentContainer.minY + (frame.minY - previousContainer.minY) / previousContainer.height * currentContainer.height,
            width: frame.width / previousContainer.width * currentContainer.width,
            height: frame.height / previousContainer.height * currentContainer.height
        )
    }

    static func inputChanged(previousContainer: CGRect,
                             previousEstimate: CGRect,
                             previousLayoutSignature: String,
                             container: CGRect,
                             estimate: CGRect,
                             layoutSignature: String) -> Bool {
        !approximatelyEqual(previousContainer, container)
            || !approximatelyEqual(previousEstimate, estimate)
            || previousLayoutSignature != layoutSignature
    }

    private static func approximatelyEqual(_ lhs: CGRect, _ rhs: CGRect) -> Bool {
        abs(lhs.minX - rhs.minX) < 1
            && abs(lhs.minY - rhs.minY) < 1
            && abs(lhs.width - rhs.width) < 1
            && abs(lhs.height - rhs.height) < 1
    }

    private func refresh(windowID: CGWindowID,
                         container: CGRect,
                         estimatedFrame: CGRect,
                         generation: UInt) {
        guard PixelMascotLocationCapability.isSupported(
            on: ProcessInfo.processInfo.operatingSystemVersion
        ) else {
            Self.logger.notice("pet capture unavailable reason=unsupportedMacOS")
            finish(windowID: windowID, generation: generation)
            return
        }
        let hasScreenRecordingPermission = CGPreflightScreenCaptureAccess()
        if !hasScreenRecordingPermission {
            synchronized { screenRecordingUnavailable = true }
            Self.logger.notice("pet capture unavailable reason=screenRecordingNotAuthorized")
            finish(windowID: windowID, generation: generation)
            return
        }
        guard #available(macOS 14.0, *) else {
            Self.logger.notice("pet capture unavailable reason=unsupportedMacOS")
            finish(windowID: windowID, generation: generation)
            return
        }

        Task { [weak self] in
            guard let self else { return }
            let window = await self.window(withID: windowID)
            guard let window else {
                Self.logger.notice("pet capture unavailable reason=windowNotShareable window=\(windowID, privacy: .public)")
                self.finish(windowID: windowID, generation: generation)
                return
            }

            let filter = SCContentFilter(desktopIndependentWindow: window)
            let configuration = SCStreamConfiguration()
            // Mascot detection uses connected components, not fine detail.
            // A bounded native-size capture keeps the first calibration cheap.
            configuration.width = max(160, min(420, Int(container.width)))
            configuration.height = max(160, min(420, Int(container.height)))
            configuration.showsCursor = false
            configuration.capturesAudio = false
            configuration.ignoreShadowsSingleWindow = true

            self.captureMeasurementSamples(
                contentFilter: filter,
                configuration: configuration,
                container: container,
                estimatedFrame: estimatedFrame,
                windowID: windowID,
                generation: generation,
                remainingSamples: Self.measurementSampleCount,
                samples: []
            )
        }
    }

    @available(macOS 14.0, *)
    private func captureMeasurementSamples(contentFilter: SCContentFilter,
                                           configuration: SCStreamConfiguration,
                                           container: CGRect,
                                           estimatedFrame: CGRect,
                                           windowID: CGWindowID,
                                           generation: UInt,
                                           remainingSamples: Int,
                                           samples: [CGRect]) {
        SCScreenshotManager.captureImage(contentFilter: contentFilter, configuration: configuration) { [weak self] image, _ in
            guard let self else { return }
            var nextSamples = samples
            if let image,
               let detected = Self.detectMascot(in: image,
                                                container: container,
                                                estimatedFrame: estimatedFrame),
               MascotCaptureResultValidation.isPlausible(detected,
                                                         estimatedFrame: estimatedFrame,
                                                         container: container) {
                nextSamples.append(detected)
            }

            guard remainingSamples > 1 else {
                if let measured = Self.stabilizedFrame(from: nextSamples) {
                    self.store(measured,
                               container: container,
                               sampleCount: nextSamples.count,
                               for: windowID,
                               generation: generation)
                } else {
                    Self.logger.notice("pet capture unavailable reason=detectorRejected window=\(windowID, privacy: .public)")
                }
                self.finish(windowID: windowID, generation: generation)
                return
            }

            DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + Self.measurementSampleDelay) { [weak self] in
                self?.captureMeasurementSamples(
                    contentFilter: contentFilter,
                    configuration: configuration,
                    container: container,
                    estimatedFrame: estimatedFrame,
                    windowID: windowID,
                    generation: generation,
                    remainingSamples: remainingSamples - 1,
                    samples: nextSamples
                )
            }
        }
    }

    @available(macOS 14.0, *)
    private func window(withID windowID: CGWindowID) async -> SCWindow? {
        if let cached = cachedWindow(withID: windowID) { return cached }

        startContentQueryIfNeeded(now: Date.timeIntervalSinceReferenceDate)

        // The first content query is asynchronous. Give it a short chance to
        // complete; later frames use the cached SCWindow immediately.
        for _ in 0..<8 {
            try? await Task.sleep(for: .milliseconds(15))
            if let result = cachedWindow(withID: windowID) { return result }
        }
        return nil
    }

    private func store(_ frame: CGRect,
                       container: CGRect,
                       sampleCount: Int,
                       for windowID: CGWindowID,
                       generation: UInt) {
        synchronized {
            guard Self.accepts(completionGeneration: generation, currentGeneration: self.generation) else {
                return
            }
            results[windowID] = Result(frame: frame,
                                       container: container,
                                       timestamp: Date.timeIntervalSinceReferenceDate)
            Self.logger.debug("pet measurement accepted samples=\(sampleCount, privacy: .public) x=\(frame.minX, privacy: .public) y=\(frame.minY, privacy: .public) w=\(frame.width, privacy: .public) h=\(frame.height, privacy: .public)")
        }
    }

    private func cachedWindow(withID windowID: CGWindowID) -> SCWindow? {
        synchronized { windowsByID[windowID] }
    }


    @available(macOS 14.0, *)
    private func startContentQueryIfNeeded(now: TimeInterval) {
        synchronized {
            guard shareableContentTask == nil, now - lastContentQuery > 5 else { return }
            lastContentQuery = now
            shareableContentTask = Task { [weak self] in
                guard let self else { return }
                let content = try? await SCShareableContent.excludingDesktopWindows(false,
                                                                                     onScreenWindowsOnly: true)
                if let content {
                    self.synchronized {
                        self.windowsByID = Dictionary(uniqueKeysWithValues: content.windows.map { ($0.windowID, $0) })
                    }
                }
                self.synchronized {
                    self.shareableContentTask = nil
                }
            }
        }
    }

    private func synchronized<T>(_ body: () -> T) -> T {
        lock.lock()
        defer { lock.unlock() }
        return body()
    }

    private func finish(windowID: CGWindowID, generation: UInt) {
        lock.lock()
        guard Self.accepts(completionGeneration: generation, currentGeneration: self.generation) else {
            lock.unlock()
            return
        }
        pending.remove(windowID)
        lock.unlock()
    }

    static func accepts(completionGeneration: UInt, currentGeneration: UInt) -> Bool {
        completionGeneration == currentGeneration
    }

    static func stabilizedFrame(from samples: [CGRect]) -> CGRect? {
        guard !samples.isEmpty else { return nil }
        func median(_ values: [CGFloat]) -> CGFloat {
            let sorted = values.sorted()
            return sorted[sorted.count / 2]
        }
        return CGRect(
            x: median(samples.map(\.minX)),
            y: median(samples.map(\.minY)),
            width: median(samples.map(\.width)),
            height: median(samples.map(\.height))
        )
    }

    static func detectMascot(in image: CGImage,
                             container: CGRect,
                             estimatedFrame: CGRect) -> CGRect? {
        let width = image.width
        let height = image.height
        guard width > 20, height > 20 else { return nil }

        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        guard let context = CGContext(data: &pixels,
                                      width: width,
                                      height: height,
                                      bitsPerComponent: 8,
                                      bytesPerRow: width * 4,
                                      space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
            return nil
        }
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

        let step = 2
        let gridWidth = (width + step - 1) / step
        let gridHeight = (height + step - 1) / step
        var active = [Bool](repeating: false, count: gridWidth * gridHeight)
        for gy in 0..<gridHeight {
            for gx in 0..<gridWidth {
                let x = min(width - 1, gx * step)
                let y = min(height - 1, gy * step)
                let offset = (y * width + x) * 4
                let alpha = pixels[offset + 3]
                // The desktop-independent window capture preserves the pet
                // overlay alpha. Restricting detection to it prevents a task
                // card or desktop background from becoming the pet frame.
                active[gy * gridWidth + gx] = alpha > 24
            }
        }

        let expectedLocal = CGRect(x: estimatedFrame.minX - container.minX,
                                   y: estimatedFrame.minY - container.minY,
                                   width: estimatedFrame.width,
                                   height: estimatedFrame.height)
        let expectedCenter = CGPoint(x: expectedLocal.midX / container.width,
                                     y: expectedLocal.midY / container.height)
        var visited = [Bool](repeating: false, count: active.count)
        var candidates: [(rect: CGRect, area: Int)] = []

        for start in 0..<active.count where active[start] && !visited[start] {
            var queue = [start]
            visited[start] = true
            var minX = gridWidth, minY = gridHeight, maxX = 0, maxY = 0, area = 0
            var cursor = 0
            while cursor < queue.count {
                let index = queue[cursor]
                cursor += 1
                let x = index % gridWidth
                let y = index / gridWidth
                minX = min(minX, x); minY = min(minY, y)
                maxX = max(maxX, x); maxY = max(maxY, y)
                area += 1
                for dy in -1...1 {
                    for dx in -1...1 where dx != 0 || dy != 0 {
                        let nx = x + dx, ny = y + dy
                        guard nx >= 0, nx < gridWidth, ny >= 0, ny < gridHeight else { continue }
                        let neighbor = ny * gridWidth + nx
                        if active[neighbor] && !visited[neighbor] {
                            visited[neighbor] = true
                            queue.append(neighbor)
                        }
                    }
                }
            }

            let rect = CGRect(x: CGFloat(minX * step),
                              y: CGFloat(minY * step),
                              width: CGFloat((maxX - minX + 1) * step),
                              height: CGFloat((maxY - minY + 1) * step))
            let aspectRatio = rect.height > 0 ? rect.width / rect.height : .infinity
            if area >= 20, rect.width >= 12, rect.height >= 16,
               rect.width < CGFloat(width) * 0.85,
               rect.height < CGFloat(height) * 0.85,
               (0.35...1.25).contains(aspectRatio) {
                candidates.append((rect, area))
            }
        }

        guard let anchor = candidates.min(by: { lhs, rhs in
            score(lhs.rect, area: lhs.area, expectedCenter: expectedCenter, imageSize: CGSize(width: width, height: height))
                < score(rhs.rect, area: rhs.area, expectedCenter: expectedCenter, imageSize: CGSize(width: width, height: height))
        }) else { return nil }

        // A pixel pet is often made of several disconnected components (hair,
        // face, robe and feet). Treat the nearby components as one mascot;
        // selecting only the largest component shifts the ring upward when the
        // pet is near the bottom of its overlay window.
        let anchorCenter = CGPoint(x: anchor.rect.midX / CGFloat(width),
                                   y: anchor.rect.midY / CGFloat(height))
        let cluster = candidates.filter { candidate in
            let center = CGPoint(x: candidate.rect.midX / CGFloat(width),
                                 y: candidate.rect.midY / CGFloat(height))
            return abs(center.x - anchorCenter.x) < 0.24
                && abs(center.y - anchorCenter.y) < 0.30
        }
        let mascotRect = cluster.reduce(anchor.rect) { partial, candidate in
            partial.union(candidate.rect)
        }

        let x = container.minX + mascotRect.minX / CGFloat(width) * container.width
        // SCScreenshotManager's pixel rows match the top-origin CG window
        // bounds. Do not flip this coordinate a second time.
        let y = container.minY + mascotRect.minY / CGFloat(height) * container.height
        let w = mascotRect.width / CGFloat(width) * container.width
        let h = mascotRect.height / CGFloat(height) * container.height
        return CGRect(x: x, y: y, width: w, height: h)
    }

    private static func score(_ rect: CGRect,
                              area: Int,
                              expectedCenter: CGPoint,
                              imageSize: CGSize) -> CGFloat {
        let center = CGPoint(x: rect.midX / imageSize.width,
                             y: rect.midY / imageSize.height)
        let distance = hypot(center.x - expectedCenter.x, center.y - expectedCenter.y)
        let sizePenalty = abs(rect.width / imageSize.width - 0.34)
            + abs(rect.height / imageSize.height - 0.40)
        return distance * 10 + sizePenalty * 2 - min(CGFloat(area) / 3000, 1)
    }
}
