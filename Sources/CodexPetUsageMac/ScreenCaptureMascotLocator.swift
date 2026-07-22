import AppKit
import CoreGraphics
import Foundation
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

/// Finds the visible mascot inside Codex's transparent Electron window.
///
/// Codex's global state contains the overlay container, but recent builds do
/// not always persist the nested `mascot` rectangle. ScreenCaptureKit lets us
/// use the actual rendered content as the source of truth instead of guessing
/// which edge of the container the mascot occupies.
final class ScreenCaptureMascotLocator: @unchecked Sendable {
    private struct Result {
        let frame: CGRect
        let timestamp: TimeInterval
    }

    private let lock = NSLock()
    private var results: [CGWindowID: Result] = [:]
    private var pending: Set<CGWindowID> = []
    private var lastInputs: [CGWindowID: (container: CGRect, estimate: CGRect)] = [:]
    private var lastAttempts: [CGWindowID: TimeInterval] = [:]
    private var shareableContentTask: Task<Void, Never>?
    private var windowsByID: [CGWindowID: SCWindow] = [:]
    private var lastContentQuery: TimeInterval = 0

    func reset() {
        lock.lock()
        results.removeAll()
        lastInputs.removeAll()
        lastAttempts.removeAll()
        lock.unlock()
    }

    func frame(for windowID: CGWindowID, container: CGRect, estimatedFrame: CGRect) -> CGRect {
        guard windowID != 0 else { return estimatedFrame }
        let now = Date.timeIntervalSinceReferenceDate

        lock.lock()
        let cached = results[windowID]
        let lastAttempt = lastAttempts[windowID]
        let inputChanged: Bool
        if let previous = lastInputs[windowID] {
            inputChanged = !approximatelyEqual(previous.container, container)
                || !approximatelyEqual(previous.estimate, estimatedFrame)
        } else {
            inputChanged = true
        }
        let shouldRefresh = MascotCaptureRefreshPolicy.shouldCapture(
            hasCachedResult: cached != nil,
            inputChanged: inputChanged,
            lastAttempt: lastAttempt,
            now: now
        )
        let isPending = pending.contains(windowID)
        if shouldRefresh && !isPending {
            pending.insert(windowID)
            lastInputs[windowID] = (container, estimatedFrame)
            lastAttempts[windowID] = now
        }
        lock.unlock()

        if shouldRefresh && !isPending {
            refresh(windowID: windowID, container: container, estimatedFrame: estimatedFrame)
        }
        // Keep a successful detection until the container geometry changes.
        // This avoids repeated image analysis while the pet is stationary.
        if let cached, !inputChanged {
            return cached.frame
        }
        return estimatedFrame
    }

    private func approximatelyEqual(_ lhs: CGRect, _ rhs: CGRect) -> Bool {
        abs(lhs.minX - rhs.minX) < 1
            && abs(lhs.minY - rhs.minY) < 1
            && abs(lhs.width - rhs.width) < 1
            && abs(lhs.height - rhs.height) < 1
    }

    private func refresh(windowID: CGWindowID, container: CGRect, estimatedFrame: CGRect) {
        // This check is non-interactive. Refresh/recalibrate must never show a
        // fresh system consent dialog; without existing permission, fall back
        // to the normal window geometry path.
        guard CGPreflightScreenCaptureAccess() else {
            finish(windowID: windowID)
            return
        }
        guard #available(macOS 14.0, *) else {
            finish(windowID: windowID)
            return
        }

        Task { [weak self] in
            guard let self else { return }
            let window = await self.window(withID: windowID)
            guard let window else {
                self.finish(windowID: windowID)
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

            SCScreenshotManager.captureImage(contentFilter: filter, configuration: configuration) { [weak self] image, _ in
                guard let self, let image else {
                    self?.finish(windowID: windowID)
                    return
                }
                let detected = Self.detectMascot(in: image,
                                                 container: container,
                                                 estimatedFrame: estimatedFrame)
                if let detected {
                    self.store(detected, for: windowID)
                }
                self.finish(windowID: windowID)
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

    private func store(_ frame: CGRect, for windowID: CGWindowID) {
        synchronized {
            results[windowID] = Result(frame: frame,
                                       timestamp: Date.timeIntervalSinceReferenceDate)
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

    private func finish(windowID: CGWindowID) {
        lock.lock()
        pending.remove(windowID)
        lock.unlock()
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
                let r = pixels[offset]
                let g = pixels[offset + 1]
                let b = pixels[offset + 2]
                // Transparent mascot windows expose real alpha. The color
                // fallback also handles opaque captures by rejecting a smooth
                // background sampled from the four corners.
                let alphaHit = alpha > 24
                let colorHit = max(r, max(g, b)) - min(r, min(g, b)) > 28
                active[gy * gridWidth + gx] = alphaHit || colorHit
            }
        }

        let expectedLocal = CGRect(x: estimatedFrame.minX - container.minX,
                                   y: estimatedFrame.minY - container.minY,
                                   width: estimatedFrame.width,
                                   height: estimatedFrame.height)
        let expectedCenter = CGPoint(x: expectedLocal.midX / container.width,
                                     // CGImage pixel rows are bottom-origin;
                                     // CGWindow bounds are top-origin.
                                     y: 1 - expectedLocal.midY / container.height)
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
            if area >= 50, rect.width >= 35, rect.height >= 45,
               rect.width < CGFloat(width) * 0.85,
               rect.height < CGFloat(height) * 0.85 {
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
        let y = container.minY
            + (CGFloat(height) - mascotRect.maxY) / CGFloat(height) * container.height
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
