import CoreGraphics
import Foundation
import AppKit
import ScreenCaptureKit

struct PetWindow {
    let windowID: CGWindowID
    let frame: CGRect
    let geometrySource: PetGeometrySource
    let mascotSize: CGSize?
    let displayID: CGDirectDisplayID
    let placement: String?
    let owner: String
    let title: String
}

final class PetWindowLocator {
    private struct PersistedOverlay {
        let state: [String: Any]
        let isOpen: Bool
    }
    private struct Candidate {
        let score: Int
        let window: PetWindow
        let container: CGRect
        let estimatedFrame: CGRect
    }

    private let contentLocator = ScreenCaptureMascotLocator()
    private var lastMeasuredPet: PetWindow?

    func reset() {
        contentLocator.reset()
    }

    func requestScreenRecordingAuthorization() {
        contentLocator.requestScreenRecordingAuthorization()
    }

    func locate() -> PetWindow? {
        let windows = (CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]]) ?? []
        let persistedOverlay = persistedOverlayState()
        let persistedState = persistedOverlay?.state
        if persistedOverlay?.isOpen == false {
            lastMeasuredPet = nil
            return nil
        }
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
            let mascotSize = PersistedPetGeometry.mascotSize(from: persistedState ?? [:], displayID: displayID)
            let centeredEstimate = PetGeometry.estimatedMascotFrame(in: container,
                                                                      displayBounds: CGDisplayBounds(displayID),
                                                                      placement: placement)
            // The persisted anchor follows the pet itself, including the
            // intentional in-container shift Codex applies at a screen edge.
            // It is only an expectation: ScreenCaptureKit replaces its size
            // and final boundary when permission is available.
            let estimatedFrame = PetGeometry.anchoredMascotFrame(anchor: overlayOrigin,
                                                                   fallback: centeredEstimate)
            let score = PetWindowCandidateScoring.score(owner: owner,
                                                        title: title,
                                                        container: container,
                                                        overlayOrigin: overlayOrigin)
            return Candidate(score: score,
                             window: PetWindow(windowID: windowID,
                                               frame: estimatedFrame,
                                               geometrySource: .anchoredFallback,
                                               mascotSize: mascotSize,
                                               displayID: displayID,
                                               placement: placement,
                                               owner: owner,
                                               title: title),
                             container: container,
                             estimatedFrame: estimatedFrame)
        }
        guard let candidate = candidates.max(by: { $0.score < $1.score }) else {
            // A live window can disappear for a frame while Codex rebuilds a
            // task card. Do not replace an already measured pet with a less
            // accurate persisted estimate during that transient.
            return lastMeasuredPet ?? fallbackPet(from: persistedState, isOpen: persistedOverlay?.isOpen ?? false)
        }
        let resolution = contentLocator.frame(for: candidate.window.windowID,
                                              container: candidate.container,
                                              estimatedFrame: candidate.estimatedFrame,
                                              layoutSignature: layoutSignature(
                                            overlayOrigin: overlayOrigin,
                                            placement: placement
                                              ))
        let resolvedPet = PetWindow(windowID: candidate.window.windowID,
                                    frame: resolution.frame,
                                    geometrySource: resolution.source,
                                    mascotSize: candidate.window.mascotSize,
                                    displayID: candidate.window.displayID,
                                    placement: candidate.window.placement,
                                    owner: candidate.window.owner,
                                    title: candidate.window.title)
        if resolution.source == .measured {
            lastMeasuredPet = resolvedPet
            return resolvedPet
        }
        if let lastMeasuredPet, lastMeasuredPet.windowID == candidate.window.windowID {
            return lastMeasuredPet
        }
        return resolvedPet
    }

    private func fallbackPet(from state: [String: Any]?, isOpen: Bool) -> PetWindow? {
        guard isOpen, let state,
              let geometry = PersistedPetGeometry.geometry(from: state),
              let displayBounds = persistedDisplayBounds(from: state),
              !geometry.container.intersection(displayBounds).isNull,
              let displayID = activeDisplayID(overlapping: geometry.container),
              !geometry.mascot.intersection(CGDisplayBounds(displayID)).isNull else { return nil }
        return PetWindow(windowID: 0,
                         frame: geometry.mascot,
                         geometrySource: .persistedFallback,
                         mascotSize: geometry.mascot.size,
                         displayID: displayID,
                         placement: geometry.placement,
                         owner: "Codex persisted state",
                         title: "Pet state fallback")
    }

    private func persistedOverlayState() -> PersistedOverlay? {
        let path = NSHomeDirectory() + "/.codex/.codex-global-state.json"
        guard let data = FileManager.default.contents(atPath: path),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let state = root["electron-avatar-overlay-bounds"] as? [String: Any] else { return nil }
        return PersistedOverlay(state: state,
                                isOpen: PetOverlayVisibility.isOpen(root["electron-avatar-overlay-open"]))
    }

    private func codexPlacement(from state: [String: Any]?) -> String? {
        state?["placement"] as? String
    }

    private func codexOverlayOrigin(from state: [String: Any]?) -> CGPoint? {
        guard let state, let x = number(state["x"]), let y = number(state["y"]) else { return nil }
        return CGPoint(x: x, y: y)
    }

    private func layoutSignature(overlayOrigin: CGPoint?, placement: String?) -> String {
        let anchor: String
        if let overlayOrigin {
            anchor = "\(Int(overlayOrigin.x.rounded())):\(Int(overlayOrigin.y.rounded()))"
        } else {
            anchor = "missing"
        }
        let resolvedPlacement = placement ?? "unknown"
        return "\(resolvedPlacement)|\(anchor)"
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
