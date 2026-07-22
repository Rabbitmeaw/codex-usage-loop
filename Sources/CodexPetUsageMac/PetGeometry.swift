import CoreGraphics

enum PetWindowCandidateScoring {
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

enum PetGeometry {
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
}

enum OverlayRingPlacement {
    static func center(for petFrame: CGRect,
                       ringSize: CGFloat,
                       placement: RingPlacement,
                       codexPlacement: String?) -> CGPoint {
        let taskCardAbove = codexPlacement?.localizedCaseInsensitiveContains("top") == true
        switch placement {
        case .around:
            let offset = ringSize * 0.07
            let verticalCorrection = taskCardAbove ? ringSize * 0.27 : 0
            return CGPoint(x: petFrame.midX + offset,
                           y: petFrame.midY + offset - verticalCorrection)
        case .left:
            return CGPoint(x: petFrame.minX - ringSize * 0.56,
                           y: petFrame.midY - (taskCardAbove ? ringSize * 0.45 : 0))
        case .right:
            return CGPoint(x: petFrame.maxX + ringSize * 0.56,
                           y: petFrame.midY - (taskCardAbove ? ringSize * 0.45 : 0))
        }
    }
}
