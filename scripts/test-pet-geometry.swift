#!/usr/bin/env swift

import AppKit
import CoreGraphics
import Foundation
import ScreenCaptureKit

/// Standalone geometry probe. It does not import or modify CodexUsageLoop.
/// Usage:
///   swift scripts/test-pet-geometry.swift
///   swift scripts/test-pet-geometry.swift --capture --label no-task-card
///   swift scripts/test-pet-geometry.swift --watch 45 --capture --label edge-right
///
/// With --capture, Screen Recording permission for the invoking terminal is
/// required. A capture is made only when the candidate container, overlay
/// placement, or overlay anchor changes. Run one explicit command per desired
/// UI state when collecting the acceptance matrix.

struct Candidate: Equatable {
    let windowID: CGWindowID
    let owner: String
    let title: String
    let container: CGRect
    let placement: String?
    let overlayOrigin: CGPoint?

    var estimatedPet: CGRect {
        let width = container.width * (119.0 / 356.0)
        let height = container.height * (129.0 / 320.0)
        let y = placement?.localizedCaseInsensitiveContains("top") == true
            ? container.maxY - height
            : container.minY
        return CGRect(x: container.midX - width / 2, y: y, width: width, height: height)
    }
}

struct PetMeasurement {
    let localFrame: CGRect
    let topOriginFrame: CGRect
    let flippedYFrame: CGRect
}

struct Options {
    var watchSeconds: TimeInterval = 0
    var capture = false
    var outputDirectory = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent("CodexUsageLoop-pet-probe", isDirectory: true)
    var label: String?
    var notify = true
}

func parseOptions() -> Options {
    var options = Options()
    var arguments = Array(CommandLine.arguments.dropFirst())
    while let argument = arguments.first {
        arguments.removeFirst()
        switch argument {
        case "--watch":
            if let value = arguments.first, let seconds = TimeInterval(value) {
                arguments.removeFirst()
                options.watchSeconds = min(max(seconds, 0), 120)
            }
        case "--capture":
            options.capture = true
        case "--output":
            if let value = arguments.first {
                arguments.removeFirst()
                options.outputDirectory = URL(fileURLWithPath: value, isDirectory: true)
            }
        case "--label":
            if let value = arguments.first {
                arguments.removeFirst()
                options.label = value
            }
        case "--no-notify":
            options.notify = false
        default:
            fputs("Unknown option: \(argument)\n", stderr)
            exit(64)
        }
    }
    return options
}

func announceProbeStart(_ options: Options) {
    guard options.notify else { return }

    // A sound is immediate even if the terminal has notifications disabled.
    // The notification itself gives the user a clear cue to begin switching
    // pet states while the explicit, bounded probe is running.
    NSSound.beep()
    let body = options.watchSeconds > 0
        ? "请切换任务卡状态并将 pet 拖到左右边缘；仅布局变化时采样。"
        : "正在采集当前 pet 的单次几何样本。"
    let escapedBody = body.replacingOccurrences(of: "\\", with: "\\\\")
        .replacingOccurrences(of: "\"", with: "\\\"")
    let task = Process()
    task.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
    task.arguments = [
        "-e",
        "display dialog \"\(escapedBody)\" with title \"CodexUsageLoop 几何探针已启动\" buttons {\"开始采样\"} default button \"开始采样\" giving up after 5"
    ]
    try? task.run()
}

func number(_ value: Any?) -> CGFloat? {
    if let value = value as? NSNumber { return CGFloat(truncating: value) }
    if let value = value as? CGFloat { return value }
    if let value = value as? Double { return CGFloat(value) }
    return nil
}

func overlayState() -> (origin: CGPoint?, placement: String?) {
    let path = URL(fileURLWithPath: NSHomeDirectory())
        .appendingPathComponent(".codex/.codex-global-state.json")
    guard let data = try? Data(contentsOf: path),
          let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
          let state = root["electron-avatar-overlay-bounds"] as? [String: Any] else {
        return (nil, nil)
    }
    let origin: CGPoint?
    if let x = number(state["x"]), let y = number(state["y"]) {
        origin = CGPoint(x: x, y: y)
    } else {
        origin = nil
    }
    return (origin, state["placement"] as? String)
}

func currentCandidate() -> Candidate? {
    let state = overlayState()
    let windows = (CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements],
                                               kCGNullWindowID) as? [[String: Any]]) ?? []
    return windows.compactMap { info -> (candidate: Candidate, score: Int)? in
        guard let owner = info[kCGWindowOwnerName as String] as? String,
              owner != "CodexUsageLoop",
              owner.localizedCaseInsensitiveContains("codex") || owner.localizedCaseInsensitiveContains("chatgpt"),
              let bounds = info[kCGWindowBounds as String] as? [String: Any],
              let x = number(bounds["X"]), let y = number(bounds["Y"]),
              let width = number(bounds["Width"]), let height = number(bounds["Height"]),
              width > 40, height > 40, width < 700, height < 700 else { return nil }
        let title = info[kCGWindowName as String] as? String ?? ""
        let windowID = (info[kCGWindowNumber as String] as? NSNumber)?.uint32Value ?? 0
        let container = CGRect(x: x, y: y, width: width, height: height)
        let titleHint = title.localizedCaseInsensitiveContains("pet") || title.localizedCaseInsensitiveContains("avatar")
        let ownerHint = owner.localizedCaseInsensitiveContains("chatgpt") ? 100_000 : 0
        let originPenalty = state.origin.map { Int(hypot(container.minX - $0.x, container.minY - $0.y) * 100) } ?? 0
        let score = ownerHint + (titleHint ? 10_000 : 0) - Int(width * height) - originPenalty
        return (Candidate(windowID: windowID,
                          owner: owner,
                          title: title,
                          container: container,
                          placement: state.placement,
                          overlayOrigin: state.origin), score)
    }.max { $0.score < $1.score }?.candidate
}

func object(_ candidate: Candidate,
            measurement: PetMeasurement?,
            capture: String?,
            label: String?) -> [String: Any] {
    var value: [String: Any] = [
        "timestamp": ISO8601DateFormatter().string(from: Date()),
        "windowID": candidate.windowID,
        "owner": candidate.owner,
        "title": candidate.title,
        "placement": candidate.placement ?? "",
        "container": ["x": candidate.container.minX, "y": candidate.container.minY,
                      "width": candidate.container.width, "height": candidate.container.height],
        "estimatedPet": ["x": candidate.estimatedPet.minX, "y": candidate.estimatedPet.minY,
                         "width": candidate.estimatedPet.width, "height": candidate.estimatedPet.height]
    ]
    if let label { value["label"] = label }
    if let origin = candidate.overlayOrigin {
        value["overlayAnchor"] = ["x": origin.x, "y": origin.y]
    }
    if let measurement {
        value["measuredPetLocal"] = ["x": measurement.localFrame.minX, "y": measurement.localFrame.minY,
                                     "width": measurement.localFrame.width, "height": measurement.localFrame.height]
        value["measuredPetTopOrigin"] = ["x": measurement.topOriginFrame.minX, "y": measurement.topOriginFrame.minY,
                                         "width": measurement.topOriginFrame.width, "height": measurement.topOriginFrame.height]
        value["measuredPetFlippedY"] = ["x": measurement.flippedYFrame.minX, "y": measurement.flippedYFrame.minY,
                                        "width": measurement.flippedYFrame.width, "height": measurement.flippedYFrame.height]
        value["measuredPetOffsetFromContainerCenter"] = [
            "x": measurement.topOriginFrame.midX - candidate.container.midX,
            "y": measurement.topOriginFrame.midY - candidate.container.midY
        ]
        value["measuredPetSizeRelativeToContainer"] = [
            "width": measurement.topOriginFrame.width / candidate.container.width,
            "height": measurement.topOriginFrame.height / candidate.container.height
        ]
    }
    if let capture { value["capture"] = capture }
    return value
}

func emit(_ value: [String: Any]) {
    guard let data = try? JSONSerialization.data(withJSONObject: value, options: [.sortedKeys]),
          let line = String(data: data, encoding: .utf8) else { return }
    print(line)
}

/// Measures the vertical pixel-art mascot from a transparent window capture.
/// Task cards form a separate, wide component and are excluded by both their
/// position relative to the expected pet anchor and their aspect ratio.
func measuredMascot(in image: CGImage, candidate: Candidate) -> PetMeasurement? {
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
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
    context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

    let step = 2
    let gridWidth = (width + step - 1) / step
    let gridHeight = (height + step - 1) / step
    var active = [Bool](repeating: false, count: gridWidth * gridHeight)
    for gridY in 0..<gridHeight {
        for gridX in 0..<gridWidth {
            let x = min(width - 1, gridX * step)
            let y = min(height - 1, gridY * step)
            active[gridY * gridWidth + gridX] = pixels[(y * width + x) * 4 + 3] > 24
        }
    }

    var visited = [Bool](repeating: false, count: active.count)
    var components: [(rect: CGRect, area: Int)] = []
    for start in 0..<active.count where active[start] && !visited[start] {
        var queue = [start]
        visited[start] = true
        var cursor = 0
        var minX = gridWidth, minY = gridHeight, maxX = 0, maxY = 0, area = 0
        while cursor < queue.count {
            let index = queue[cursor]
            cursor += 1
            let x = index % gridWidth
            let y = index / gridWidth
            minX = min(minX, x); minY = min(minY, y)
            maxX = max(maxX, x); maxY = max(maxY, y)
            area += 1
            for deltaY in -1...1 {
                for deltaX in -1...1 where deltaX != 0 || deltaY != 0 {
                    let nextX = x + deltaX
                    let nextY = y + deltaY
                    guard nextX >= 0, nextX < gridWidth, nextY >= 0, nextY < gridHeight else { continue }
                    let next = nextY * gridWidth + nextX
                    if active[next] && !visited[next] {
                        visited[next] = true
                        queue.append(next)
                    }
                }
            }
        }
        let rect = CGRect(x: CGFloat(minX * step), y: CGFloat(minY * step),
                          width: CGFloat((maxX - minX + 1) * step),
                          height: CGFloat((maxY - minY + 1) * step))
        let aspect = rect.height > 0 ? rect.width / rect.height : .infinity
        if area >= 20, rect.width >= 12, rect.height >= 16,
           rect.width < CGFloat(width) * 0.85, rect.height < CGFloat(height) * 0.85,
           (0.35...1.25).contains(aspect) {
            components.append((rect, area))
        }
    }

    let estimate = candidate.estimatedPet
    // CGWindowList and the screenshot use the same top-left origin. Keeping
    // this direct mapping alongside `flippedYFrame` makes an accidental second
    // Y flip visible in the resulting JSON instead of hiding it in scoring.
    let expected = CGPoint(x: (estimate.midX - candidate.container.minX) / candidate.container.width,
                           y: (estimate.midY - candidate.container.minY) / candidate.container.height)
    guard let anchor = components.min(by: { lhs, rhs in
        func score(_ component: (rect: CGRect, area: Int)) -> CGFloat {
            let center = CGPoint(x: component.rect.midX / CGFloat(width), y: component.rect.midY / CGFloat(height))
            return hypot(center.x - expected.x, center.y - expected.y) * 10 - min(CGFloat(component.area) / 3_000, 1)
        }
        return score(lhs) < score(rhs)
    }) else { return nil }

    let anchorCenter = CGPoint(x: anchor.rect.midX / CGFloat(width), y: anchor.rect.midY / CGFloat(height))
    let cluster = components.filter { component in
        let center = CGPoint(x: component.rect.midX / CGFloat(width), y: component.rect.midY / CGFloat(height))
        return abs(center.x - anchorCenter.x) < 0.25 && abs(center.y - anchorCenter.y) < 0.32
    }
    let mascot = cluster.reduce(anchor.rect) { $0.union($1.rect) }
    let local = CGRect(x: mascot.minX / CGFloat(width) * candidate.container.width,
                       y: mascot.minY / CGFloat(height) * candidate.container.height,
                       width: mascot.width / CGFloat(width) * candidate.container.width,
                       height: mascot.height / CGFloat(height) * candidate.container.height)
    let topOrigin = CGRect(x: candidate.container.minX + local.minX,
                           y: candidate.container.minY + local.minY,
                           width: local.width, height: local.height)
    let flippedY = CGRect(x: topOrigin.minX,
                          y: candidate.container.minY + candidate.container.height - local.maxY,
                          width: local.width, height: local.height)
    return PetMeasurement(localFrame: local, topOriginFrame: topOrigin, flippedYFrame: flippedY)
}

func capture(_ candidate: Candidate, outputDirectory: URL) async -> (PetMeasurement?, String) {
    guard CGPreflightScreenCaptureAccess() else { return (nil, "notAuthorized") }
    guard #available(macOS 14.0, *) else { return (nil, "unsupportedMacOS") }
    guard let window = (try? await SCShareableContent.excludingDesktopWindows(false,
                                                                                onScreenWindowsOnly: true))?.windows.first(where: { $0.windowID == candidate.windowID }) else {
        return (nil, "windowNotShareable")
    }
    let configuration = SCStreamConfiguration()
    configuration.width = max(160, min(700, Int(candidate.container.width)))
    configuration.height = max(160, min(700, Int(candidate.container.height)))
    configuration.showsCursor = false
    configuration.capturesAudio = false
    configuration.ignoreShadowsSingleWindow = true
    guard let image = try? await SCScreenshotManager.captureImage(
        contentFilter: SCContentFilter(desktopIndependentWindow: window),
        configuration: configuration
    ) else { return (nil, "captureFailed") }

    try? FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyyMMdd-HHmmss-SSS"
    let imageURL = outputDirectory.appendingPathComponent("pet-probe-\(formatter.string(from: Date())).png")
    if let data = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) {
        try? data.write(to: imageURL)
    }
    return (measuredMascot(in: image, candidate: candidate), imageURL.path)
}

let options = parseOptions()
announceProbeStart(options)
if options.capture {
    print("screenRecordingAuthorized=\(CGPreflightScreenCaptureAccess())")
}
let deadline = Date().addingTimeInterval(options.watchSeconds)
var lastCandidate: Candidate?

repeat {
    guard let candidate = currentCandidate() else {
        emit(["timestamp": ISO8601DateFormatter().string(from: Date()), "status": "petCandidateNotFound"])
        break
    }
    let changed = candidate != lastCandidate
    if changed || lastCandidate == nil {
        if options.capture {
            let semaphore = DispatchSemaphore(value: 0)
            var measurement: PetMeasurement?
            var captureStatus: String?
            Task {
                (measurement, captureStatus) = await capture(candidate, outputDirectory: options.outputDirectory)
                semaphore.signal()
            }
            semaphore.wait()
            emit(object(candidate, measurement: measurement, capture: captureStatus, label: options.label))
        } else {
            emit(object(candidate, measurement: nil, capture: nil, label: options.label))
        }
        lastCandidate = candidate
    }
    guard options.watchSeconds > 0, Date() < deadline else { break }
    RunLoop.current.run(until: Date().addingTimeInterval(0.25))
} while Date() < deadline
