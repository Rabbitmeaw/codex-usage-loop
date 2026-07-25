import CoreGraphics
import Foundation

enum PetGeometrySource: String, Equatable {
    case measured
    case anchoredFallback
    case persistedFallback
}

enum PetWindowCandidateScoring {
    static func accepts(owner: String) -> Bool {
        owner.caseInsensitiveCompare("Codex") == .orderedSame
            || owner.caseInsensitiveCompare("ChatGPT") == .orderedSame
    }

    static func score(owner: String,
                      title: String,
                      container: CGRect,
                      overlayOrigin: CGPoint?) -> Int {
        let titleHint = title.localizedCaseInsensitiveContains("pet")
            || title.localizedCaseInsensitiveContains("avatar")
        let ownerHint = owner.localizedCaseInsensitiveContains("chatgpt") ? 100_000 : 0
        let originPenalty: Int
        if let overlayOrigin {
            let distance = hypot(container.minX - overlayOrigin.x, container.minY - overlayOrigin.y)
            originPenalty = Int(distance * 100)
        } else {
            originPenalty = 0
        }
        return ownerHint + (titleHint ? 10_000 : 0) - Int(container.width * container.height) - originPenalty
    }
}

enum PetOverlayVisibility {
    static func isOpen(_ value: Any?) -> Bool {
        value as? Bool ?? true
    }
}

enum PetGeometry {
    /// Recent Codex Desktop builds persist the visible pet's top-left anchor.
    /// Use it as the screenshot detector's expected location and as a
    /// permission-denied fallback; the screenshot result still supplies the
    /// final visible frame and size when available.
    static func anchoredMascotFrame(anchor: CGPoint?, fallback: CGRect) -> CGRect {
        guard let anchor, anchor.x.isFinite, anchor.y.isFinite else { return fallback }
        return CGRect(origin: anchor, size: fallback.size)
    }

    static func estimatedMascotFrame(in container: CGRect,
                                     displayBounds: CGRect,
                                     placement: String?) -> CGRect {
        // The Windows companion reads the mascot rect from Codex state. When the
        // current Codex build omits that rect, use the same proportions as its
        // transparent overlay: 119x129 inside a 356x320 window.
        let width = container.width * (119.0 / 356.0)
        let height = container.height * (129.0 / 320.0)
        let y: CGFloat
        if let placement, placement.localizedCaseInsensitiveContains("top") {
            y = container.maxY - height
        } else if let placement, placement.localizedCaseInsensitiveContains("bottom") {
            y = container.minY
        } else {
            y = container.minY <= displayBounds.minY + displayBounds.height * 0.6
                ? container.minY
                : container.maxY - height
        }
        return CGRect(x: container.midX - width / 2, y: y, width: width, height: height)
    }

    static func appKitFrame(cgFrame: CGRect,
                            displayBounds: CGRect,
                            screenFrame: CGRect) -> CGRect {
        let localX = cgFrame.minX - displayBounds.minX
        let localY = cgFrame.minY - displayBounds.minY
        return CGRect(
            x: screenFrame.minX + localX,
            y: screenFrame.maxY - localY - cgFrame.height,
            width: cgFrame.width,
            height: cgFrame.height
        )
    }

    static func applyingMascotSize(_ size: CGSize, to frame: CGRect) -> CGRect {
        guard size.width > 0, size.height > 0 else { return frame }
        return CGRect(origin: frame.origin, size: size)
    }
}

enum PersistedPetGeometry {
    struct Geometry: Equatable {
        let container: CGRect
        let mascot: CGRect
        let placement: String?
    }

    static func geometry(from state: [String: Any]) -> Geometry? {
        guard let x = number(state["x"]), let y = number(state["y"]) else { return nil }
        guard x.isFinite, y.isFinite else { return nil }
        let placement = state["placement"] as? String
        let storedMascot = state["mascot"] as? [String: Any]
        let width = number(state["width"])
        let height = number(state["height"])
        if width == nil || height == nil {
            // Recent Codex builds persist a direct top-left mascot anchor here,
            // not the old transparent 356x320 overlay container.
            let mascot = CGRect(x: x, y: y, width: 119, height: 129)
            return Geometry(container: mascot, mascot: mascot, placement: placement)
        }
        guard let width, let height,
              width.isFinite, height.isFinite,
              width >= 40, height >= 40, width <= 700, height <= 700 else { return nil }

        let container = CGRect(x: x, y: y, width: width, height: height)
        let mascot: CGRect
        if let stored = storedMascot,
           let left = number(stored["left"]), let top = number(stored["top"]),
           let mascotWidth = number(stored["width"]), let mascotHeight = number(stored["height"]),
           left.isFinite, top.isFinite, mascotWidth.isFinite, mascotHeight.isFinite,
           mascotWidth > 0, mascotHeight > 0 {
            mascot = CGRect(x: container.minX + left,
                             y: container.minY + top,
                             width: mascotWidth,
                             height: mascotHeight)
        } else {
            mascot = PetGeometry.estimatedMascotFrame(in: container,
                                                       displayBounds: container,
                                                       placement: placement)
        }
        guard mascot.minX >= container.minX, mascot.minY >= container.minY,
              mascot.maxX <= container.maxX, mascot.maxY <= container.maxY else { return nil }
        return Geometry(container: container, mascot: mascot, placement: placement)
    }

    static func mascotSize(from state: [String: Any], displayID: CGDirectDisplayID) -> CGSize? {
        let displayRecord = (state["byDisplayId"] as? [String: Any])?[String(displayID)] as? [String: Any]
        if let size = mascotSize(from: displayRecord) { return size }

        guard let stateDisplayID = number(state["displayId"]),
              CGDirectDisplayID(stateDisplayID) == displayID else { return nil }
        return mascotSize(from: state)
    }

    private static func mascotSize(from record: [String: Any]?) -> CGSize? {
        guard let record else { return nil }
        let mascot = record["mascot"] as? [String: Any]
        let anchor = record["anchor"] as? [String: Any]
        for source in [mascot, anchor] {
            guard let source,
                  let width = number(source["width"]), let height = number(source["height"]),
                  width.isFinite, height.isFinite,
                  width >= 16, height >= 16, width <= 700, height <= 700 else { continue }
            return CGSize(width: width, height: height)
        }
        return nil
    }

    private static func number(_ value: Any?) -> CGFloat? {
        if let value = value as? NSNumber { return CGFloat(truncating: value) }
        if let value = value as? CGFloat { return value }
        if let value = value as? Double { return CGFloat(value) }
        return nil
    }
}

enum OverlayRingPlacement {
    static func center(for petFrame: CGRect,
                       ringSize: CGFloat,
                       placement: RingPlacement,
                       codexPlacement: String?) -> CGPoint {
        let taskCardAbove = codexPlacement?.localizedCaseInsensitiveContains("top") == true
        switch placement {
        case .around:
            return AroundPetRingLayout.center(for: petFrame,
                                              ringDiameter: ringSize,
                                              taskCardAbove: taskCardAbove)
        case .left:
            return CGPoint(x: petFrame.minX - ringSize * 0.56,
                           y: petFrame.midY - (taskCardAbove ? ringSize * 0.45 : 0))
        case .right:
            return CGPoint(x: petFrame.maxX + ringSize * 0.56,
                           y: petFrame.midY - (taskCardAbove ? ringSize * 0.45 : 0))
        }
    }
}

/// The accepted visual relationship between the ring and the visible mascot.
/// Every value is a ratio so changing the mascot's size preserves the layout.
enum AroundPetRingLayout {
    /// Exact ratio derived from the accepted standard 129pt mascot and its
    /// established 194.35pt around-ring diameter.
    static let diameterToPetPrimaryDimension: CGFloat = 194.35 / 129
    static func diameter(for petFrame: CGRect, scale: CGFloat) -> CGFloat {
        max(petFrame.width, petFrame.height)
            * diameterToPetPrimaryDimension
            * AroundRingScale.clamped(scale)
    }

    static func center(for petFrame: CGRect,
                       ringDiameter: CGFloat,
                       taskCardAbove: Bool) -> CGPoint {
        // The task card has its own layout. It must never shift an around-pet
        // ring away from the measured visible mascot.
        CGPoint(x: petFrame.midX, y: petFrame.midY)
    }
}
