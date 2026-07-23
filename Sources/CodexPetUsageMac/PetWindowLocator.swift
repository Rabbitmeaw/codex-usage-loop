import CoreGraphics
import Foundation
import AppKit
import ScreenCaptureKit

struct PetWindow {
    let windowID: CGWindowID
    let frame: CGRect
    let displayID: CGDirectDisplayID
    let placement: String?
    let owner: String
    let title: String
}

final class PetWindowLocator {
    private struct Candidate {
        let score: Int
        let window: PetWindow
        let container: CGRect
        let estimatedFrame: CGRect
    }

    private let contentLocator = ScreenCaptureMascotLocator()

    func reset() {
        contentLocator.reset()
    }

    func locate() -> PetWindow? {
        let windows = (CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]]) ?? []
        let persistedState = persistedOverlayState()
        let overlayOrigin = codexOverlayOrigin(from: persistedState)
        let placement = codexPlacement(from: persistedState)
        let candidates: [Candidate] = windows.compactMap { info in
            guard let owner = info[kCGWindowOwnerName as String] as? String,
                  owner != "CodexUsageLoop",
                  owner.localizedCaseInsensitiveContains("codex") || owner.localizedCaseInsensitiveContains("chatgpt"),
                  let bounds = info[kCGWindowBounds as String] as? [String: Any],
                  let x = number(bounds["X"]), let y = number(bounds["Y"]),
                  let width = number(bounds["Width"]), let height = number(bounds["Height"]),
                  width > 40, height > 40, width < 700, height < 700 else { return nil }
            let windowID = (info[kCGWindowNumber as String] as? NSNumber)?.uint32Value ?? 0
            let title = info[kCGWindowName as String] as? String ?? ""
            let container = CGRect(x: x, y: y, width: width, height: height)
            let displayID = displayID(for: container)
            let estimatedFrame = PetGeometry.estimatedMascotFrame(in: container,
                                                                   displayBounds: CGDisplayBounds(displayID),
                                                                   placement: placement)
            let score = PetWindowCandidateScoring.score(owner: owner,
                                                        title: title,
                                                        container: container,
                                                        overlayOrigin: overlayOrigin)
            return Candidate(score: score,
                             window: PetWindow(windowID: windowID,
                                               frame: estimatedFrame,
                                               displayID: displayID,
                                               placement: placement,
                                               owner: owner,
                                               title: title),
                             container: container,
                             estimatedFrame: estimatedFrame)
        }
        guard let candidate = candidates.max(by: { $0.score < $1.score }) else {
            return fallbackPet(from: persistedState)
        }
        let frame = contentLocator.frame(for: candidate.window.windowID,
                                         container: candidate.container,
                                         estimatedFrame: candidate.estimatedFrame)
        return PetWindow(windowID: candidate.window.windowID,
                         frame: frame,
                         displayID: candidate.window.displayID,
                         placement: candidate.window.placement,
                         owner: candidate.window.owner,
                         title: candidate.window.title)
    }

    private func fallbackPet(from state: [String: Any]?) -> PetWindow? {
        guard let state,
              let geometry = PersistedPetGeometry.geometry(from: state),
              let displayBounds = persistedDisplayBounds(from: state),
              !geometry.container.intersection(displayBounds).isNull,
              let displayID = activeDisplayID(overlapping: geometry.container),
              !geometry.mascot.intersection(CGDisplayBounds(displayID)).isNull else { return nil }
        return PetWindow(windowID: 0,
                         frame: geometry.mascot,
                         displayID: displayID,
                         placement: geometry.placement,
                         owner: "Codex persisted state",
                         title: "Pet state fallback")
    }

    private func persistedOverlayState() -> [String: Any]? {
        let path = NSHomeDirectory() + "/.codex/.codex-global-state.json"
        guard let data = FileManager.default.contents(atPath: path),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let state = root["electron-avatar-overlay-bounds"] as? [String: Any] else { return nil }
        return state
    }

    private func codexPlacement(from state: [String: Any]?) -> String? {
        state?["placement"] as? String
    }

    private func codexOverlayOrigin(from state: [String: Any]?) -> CGPoint? {
        guard let state, let x = number(state["x"]), let y = number(state["y"]) else { return nil }
        return CGPoint(x: x, y: y)
    }

    private func persistedDisplayBounds(from state: [String: Any]) -> CGRect? {
        guard let bounds = state["displayBounds"] as? [String: Any],
              let x = number(bounds["x"]), let y = number(bounds["y"]),
              let width = number(bounds["width"]), let height = number(bounds["height"]),
              width > 0, height > 0 else { return nil }
        return CGRect(x: x, y: y, width: width, height: height)
    }

    private func displayID(for rect: CGRect) -> CGDirectDisplayID {
        var displayCount: UInt32 = 0
        var displays = [CGDirectDisplayID](repeating: 0, count: 32)
        CGGetActiveDisplayList(UInt32(displays.count), &displays, &displayCount)

        return displays.prefix(Int(displayCount)).max { lhs, rhs in
            intersectionArea(CGDisplayBounds(lhs), rect) < intersectionArea(CGDisplayBounds(rhs), rect)
        } ?? CGMainDisplayID()
    }

    private func activeDisplayID(overlapping rect: CGRect) -> CGDirectDisplayID? {
        var displayCount: UInt32 = 0
        var displays = [CGDirectDisplayID](repeating: 0, count: 32)
        CGGetActiveDisplayList(UInt32(displays.count), &displays, &displayCount)

        guard let displayID = displays.prefix(Int(displayCount)).max(by: {
            intersectionArea(CGDisplayBounds($0), rect) < intersectionArea(CGDisplayBounds($1), rect)
        }), intersectionArea(CGDisplayBounds(displayID), rect) > 0 else { return nil }
        return displayID
    }

    private func intersectionArea(_ lhs: CGRect, _ rhs: CGRect) -> CGFloat {
        let intersection = lhs.intersection(rhs)
        return intersection.isNull ? 0 : intersection.width * intersection.height
    }

    private func number(_ value: Any?) -> CGFloat? {
        if let value = value as? NSNumber { return CGFloat(truncating: value) }
        if let value = value as? CGFloat { return value }
        if let value = value as? Double { return CGFloat(value) }
        return nil
    }
}
