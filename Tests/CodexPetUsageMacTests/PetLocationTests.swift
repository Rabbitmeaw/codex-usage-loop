import AppKit
import XCTest
@testable import CodexPetUsageMac

final class PetLocationTests: XCTestCase {
    func testCandidateAdmissionAllowsOnlyMainCodexOwners() {
        XCTAssertTrue(PetWindowCandidateScoring.accepts(owner: "Codex"))
        XCTAssertTrue(PetWindowCandidateScoring.accepts(owner: "ChatGPT"))
        XCTAssertTrue(PetWindowCandidateScoring.accepts(owner: "ChatGPT", title: "Codex"))
    }

    func testCandidateAdmissionRejectsComputerUseSoftwareCursorAndSimilarAuxiliaryOwners() {
        let softwareCursor = (owner: "ChatGPT Computer Use", title: "Software Cursor")

        XCTAssertFalse(PetWindowCandidateScoring.accepts(owner: softwareCursor.owner), softwareCursor.title)
        XCTAssertFalse(PetWindowCandidateScoring.accepts(owner: "Codex Helper"))
        XCTAssertFalse(PetWindowCandidateScoring.accepts(owner: "ChatGPT", title: "Computer Use"))
        XCTAssertFalse(PetWindowCandidateScoring.accepts(owner: "ChatGPT", title: "Computer Use Controls"))
        XCTAssertFalse(PetWindowCandidateScoring.accepts(owner: "ChatGPT", title: "Software Cursor"))
    }

    func testComputerUseSessionDetectionRecognizesOnlyTheLiveSessionWindows() {
        XCTAssertTrue(ComputerUseSessionWindow.isActive(owner: "ChatGPT", title: "Computer Use"))
        XCTAssertTrue(ComputerUseSessionWindow.isActive(owner: "ChatGPT", title: "Computer Use Controls"))
        XCTAssertFalse(ComputerUseSessionWindow.isActive(owner: "ChatGPT", title: "Codex"))
        XCTAssertFalse(ComputerUseSessionWindow.isActive(owner: "Codex", title: "Computer Use"))
    }

    func testCandidateScorePrefersPetTitleOverPlainCodexWindow() {
        let container = CGRect(x: 120, y: 80, width: 356, height: 320)
        let origin = CGPoint(x: 120, y: 80)

        let petScore = PetWindowCandidateScoring.score(
            owner: "Codex",
            title: "Pet overlay",
            container: container,
            overlayOrigin: origin
        )
        let plainScore = PetWindowCandidateScoring.score(
            owner: "Codex",
            title: "Codex",
            container: container,
            overlayOrigin: origin
        )

        XCTAssertGreaterThan(petScore, plainScore)
    }

    func testPersistedOverlayVisibilityDefaultsToOpenForOlderCodexState() {
        XCTAssertTrue(PetOverlayVisibility.isOpen(nil))
        XCTAssertTrue(PetOverlayVisibility.isOpen(true))
        XCTAssertFalse(PetOverlayVisibility.isOpen(false))
    }

    func testComputerUseFreezesExistingTrustedPetGeometryOnlyWhileActive() {
        XCTAssertTrue(
            ComputerUseGeometryFreezePolicy.shouldFreeze(
                isComputerUseActive: true,
                hasTrustedGeometry: true
            )
        )
        XCTAssertFalse(
            ComputerUseGeometryFreezePolicy.shouldFreeze(
                isComputerUseActive: false,
                hasTrustedGeometry: true
            )
        )
        XCTAssertFalse(
            ComputerUseGeometryFreezePolicy.shouldFreeze(
                isComputerUseActive: true,
                hasTrustedGeometry: false
            )
        )
    }

    func testComputerUsePausesManualPetGeometryRecalibration() {
        let activeLocator = PetWindowLocator(computerUseIsActive: { _ in true })
        let inactiveLocator = PetWindowLocator(computerUseIsActive: { _ in false })

        XCTAssertFalse(activeLocator.reset())
        XCTAssertTrue(inactiveLocator.reset())
    }

    func testManualRecalibrationUsesTheCurrentWindowSnapshotForSessionDetection() {
        let activeWindow: [String: Any] = [
            kCGWindowOwnerName as String: "ChatGPT",
            kCGWindowName as String: "Computer Use"
        ]
        let petWindow: [String: Any] = [
            kCGWindowOwnerName as String: "ChatGPT",
            kCGWindowName as String: "Codex"
        ]

        XCTAssertFalse(PetWindowLocator(windowInfoProvider: { [activeWindow, petWindow] }).reset())
        XCTAssertTrue(PetWindowLocator(windowInfoProvider: { [petWindow] }).reset())
    }

    func testComputerUseTransitionInvalidationRunsOncePerActivePeriodAcrossLocateAndReset() {
        var active = false
        var invalidationCount = 0
        let locator = PetWindowLocator(
            windowInfoProvider: { [] },
            computerUseIsActive: { _ in active },
            computerUseTransitionObserver: { invalidationCount += 1 }
        )

        _ = locator.locate()
        active = true
        _ = locator.locate()
        XCTAssertFalse(locator.reset())
        _ = locator.locate()
        XCTAssertEqual(invalidationCount, 1)

        active = false
        XCTAssertTrue(locator.reset())
        active = true
        XCTAssertFalse(locator.reset())
        XCTAssertEqual(invalidationCount, 2)
    }

    func testEstimatedMascotFrameFollowsPersistedPlacement() {
        let container = CGRect(x: 100, y: 200, width: 356, height: 320)
        let display = CGRect(x: 0, y: 0, width: 1_440, height: 900)

        let top = PetGeometry.estimatedMascotFrame(in: container, displayBounds: display, placement: "top-end")
        let bottom = PetGeometry.estimatedMascotFrame(in: container, displayBounds: display, placement: "bottom-start")

        XCTAssertEqual(top, CGRect(x: 218.5, y: 391, width: 119, height: 129))
        XCTAssertEqual(bottom, CGRect(x: 218.5, y: 200, width: 119, height: 129))
    }

    func testPersistedPetAnchorOverridesOnlyTheExpectedFrameOrigin() {
        let fallback = CGRect(x: 300, y: 600, width: 119, height: 129)
        let anchored = PetGeometry.anchoredMascotFrame(
            anchor: CGPoint(x: 12, y: 640),
            fallback: fallback
        )

        XCTAssertEqual(anchored, CGRect(x: 12, y: 640, width: 119, height: 129))
        XCTAssertEqual(PetGeometry.anchoredMascotFrame(anchor: nil, fallback: fallback), fallback)
    }

    func testPersistedOverlayFallbackEstimatesMascotWithoutLiveWindow() {
        let state: [String: Any] = [
            "x": 1_142,
            "y": 636,
            "placement": "top-end"
        ]

        let geometry = PersistedPetGeometry.geometry(from: state)

        XCTAssertEqual(geometry?.container, CGRect(x: 1_142, y: 636, width: 119, height: 129))
        XCTAssertEqual(geometry?.mascot, CGRect(x: 1_142, y: 636, width: 119, height: 129))
    }

    func testPersistedOverlayFallbackUsesExactStoredMascot() {
        let state: [String: Any] = [
            "x": 1_142,
            "y": 636,
            "width": 356,
            "height": 320,
            "placement": "top-end",
            "mascot": ["left": 209, "top": 183, "width": 119, "height": 129]
        ]

        let geometry = PersistedPetGeometry.geometry(from: state)

        XCTAssertEqual(geometry?.mascot, CGRect(x: 1_351, y: 819, width: 119, height: 129))
    }

    func testPersistedOverlayFallbackRejectsMascotOutsideContainer() {
        let state: [String: Any] = [
            "x": 100,
            "y": 200,
            "width": 356,
            "height": 320,
            "mascot": ["left": 300, "top": 183, "width": 119, "height": 129]
        ]

        XCTAssertNil(PersistedPetGeometry.geometry(from: state))
    }

    func testPersistedMascotSizeUsesTheCurrentDisplayRecord() {
        let state: [String: Any] = [
            "displayId": 79,
            "byDisplayId": [
                "78": ["mascot": ["width": 119, "height": 129]],
                "79": ["mascot": ["width": 168, "height": 182]]
            ]
        ]

        XCTAssertEqual(PersistedPetGeometry.mascotSize(from: state, displayID: 79),
                       CGSize(width: 168, height: 182))
    }

    func testPersistedMascotSizeDoesNotUseAnotherDisplayHistory() {
        let state: [String: Any] = [
            "displayId": 2,
            "byDisplayId": [
                "79": ["mascot": ["width": 168, "height": 182]]
            ]
        ]

        XCTAssertNil(PersistedPetGeometry.mascotSize(from: state, displayID: 2))
    }

    func testPersistedMascotSizeChangesRingReferenceFrameWithoutMovingItsOrigin() {
        let resized = PetGeometry.applyingMascotSize(
            CGSize(width: 168, height: 182),
            to: CGRect(x: 500, y: 300, width: 119, height: 129)
        )

        XCTAssertEqual(resized, CGRect(x: 500, y: 300, width: 168, height: 182))
    }

    func testCGFrameConvertsToAppKitScreenCoordinates() {
        let converted = PetGeometry.appKitFrame(
            cgFrame: CGRect(x: 120, y: 100, width: 80, height: 60),
            displayBounds: CGRect(x: 0, y: 0, width: 1_440, height: 900),
            screenFrame: CGRect(x: 0, y: 0, width: 1_440, height: 900)
        )

        XCTAssertEqual(converted, CGRect(x: 120, y: 740, width: 80, height: 60))
    }

    func testAroundRingCenterUsesMeasuredPetCenterRegardlessOfTaskCard() {
        let pet = CGRect(x: 400, y: 300, width: 100, height: 120)

        let around = OverlayRingPlacement.center(
            for: pet,
            ringSize: 180,
            placement: .around,
            codexPlacement: "top-end"
        )
        let right = OverlayRingPlacement.center(
            for: pet,
            ringSize: 200,
            placement: .right,
            codexPlacement: "top-end"
        )

        XCTAssertEqual(around, CGPoint(x: 450, y: 360))
        XCTAssertEqual(right, CGPoint(x: 612, y: 270))
    }

    func testAnchoredFallbackAroundRingUsesTaskCardHorizontalCenter() {
        let pet = CGRect(x: 1_271, y: 154, width: 136.382022, height: 161.25)
        let taskCard = CGRect(x: 1_074, y: 146, width: 408, height: 400)

        let center = OverlayRingPlacement.center(
            for: pet,
            ringSize: 235,
            placement: .around,
            codexPlacement: "bottom-end",
            fallbackContainerFrame: taskCard,
            geometrySource: .anchoredFallback
        )

        XCTAssertEqual(center.x, taskCard.midX, accuracy: 0.001)
        XCTAssertEqual(center.y, pet.maxY + 16 - 235 / 2, accuracy: 0.001)
    }

    func testAnchoredFallbackUsesConvertedSecondaryDisplayTaskCardCenter() {
        let container = PetGeometry.appKitFrame(
            cgFrame: CGRect(x: 1_800, y: -50, width: 408, height: 400),
            displayBounds: CGRect(x: 1_470, y: -124, width: 1_920, height: 1_080),
            screenFrame: CGRect(x: 1_470, y: 0, width: 1_920, height: 1_080)
        )
        let pet = CGRect(x: 1_900, y: 300, width: 136, height: 161)

        let center = OverlayRingPlacement.center(
            for: pet,
            ringSize: 235,
            placement: .around,
            codexPlacement: "bottom-end",
            fallbackContainerFrame: container,
            geometrySource: .anchoredFallback
        )

        XCTAssertEqual(container.midX, 2_004, accuracy: 0.001)
        XCTAssertEqual(center.x, container.midX, accuracy: 0.001)
    }

    func testAnchoredFallbackUsesPetCenterWhenTaskCardContainerTouchesScreenEdges() {
        let visibleFrame = CGRect(x: 0, y: 0, width: 1_470, height: 956)
        let leftPet = CGRect(x: 0, y: 300, width: 136, height: 161)
        let rightPet = CGRect(x: 1_334, y: 300, width: 136, height: 161)

        let leftCenter = OverlayRingPlacement.center(
            for: leftPet,
            ringSize: 157,
            placement: .around,
            codexPlacement: "bottom-start",
            fallbackContainerFrame: CGRect(x: -12, y: 250, width: 408, height: 400),
            fallbackVisibleFrame: visibleFrame,
            geometrySource: .anchoredFallback
        )
        let rightCenter = OverlayRingPlacement.center(
            for: rightPet,
            ringSize: 157,
            placement: .around,
            codexPlacement: "bottom-end",
            fallbackContainerFrame: CGRect(x: 1_074, y: 250, width: 408, height: 400),
            fallbackVisibleFrame: visibleFrame,
            geometrySource: .anchoredFallback
        )

        XCTAssertEqual(leftCenter.x, leftPet.midX, accuracy: 0.001)
        XCTAssertEqual(rightCenter.x, rightPet.midX, accuracy: 0.001)
        XCTAssertEqual(leftCenter.y, leftPet.maxY + 16 - 157 / 2, accuracy: 0.001)
        XCTAssertEqual(rightCenter.y, rightPet.maxY + 16 - 157 / 2, accuracy: 0.001)
    }

    func testAnchoredFallbackUsesPetCenterAtSecondaryDisplayEdge() {
        let visibleFrame = CGRect(x: 1_470, y: -124, width: 1_920, height: 1_080)
        let pet = CGRect(x: 1_470, y: 300, width: 136, height: 161)

        let center = OverlayRingPlacement.center(
            for: pet,
            ringSize: 157,
            placement: .around,
            codexPlacement: "bottom-start",
            fallbackContainerFrame: CGRect(x: 1_458, y: 250, width: 408, height: 400),
            fallbackVisibleFrame: visibleFrame,
            geometrySource: .anchoredFallback
        )

        XCTAssertEqual(center.x, pet.midX, accuracy: 0.001)
        XCTAssertEqual(center.y, pet.maxY + 16 - 157 / 2, accuracy: 0.001)
    }

    func testAnchoredFallbackAroundRingUsesTwoThirdsEstimatedDiameter() {
        XCTAssertEqual(
            FallbackRingSizing.aroundDiameter(235.212898, source: .anchoredFallback),
            156.808598,
            accuracy: 0.001
        )
        XCTAssertEqual(
            FallbackRingSizing.aroundDiameter(235.212898, source: .measured),
            235.212898,
            accuracy: 0.001
        )
    }

    func testMeasuredAroundRingIgnoresFallbackTaskCardCenter() {
        let pet = CGRect(x: 900, y: 300, width: 136, height: 161)
        let taskCard = CGRect(x: 1_074, y: 146, width: 408, height: 400)

        let center = OverlayRingPlacement.center(
            for: pet,
            ringSize: 235,
            placement: .around,
            codexPlacement: "bottom-end",
            fallbackContainerFrame: taskCard,
            geometrySource: .measured
        )

        XCTAssertEqual(center.x, pet.midX, accuracy: 0.001)
        XCTAssertEqual(center.y, pet.midY, accuracy: 0.001)
    }

    func testPersistedFallbackAroundRingDoesNotApplyAnchoredVisualCorrection() {
        let pet = CGRect(x: 900, y: 300, width: 136, height: 161)
        let container = CGRect(x: 700, y: 250, width: 408, height: 400)

        let center = OverlayRingPlacement.center(
            for: pet,
            ringSize: 157,
            placement: .around,
            codexPlacement: "bottom-end",
            fallbackContainerFrame: container,
            geometrySource: .persistedFallback
        )

        XCTAssertEqual(center.x, pet.midX, accuracy: 0.001)
        XCTAssertEqual(center.y, pet.midY, accuracy: 0.001)
        XCTAssertEqual(FallbackRingSizing.aroundDiameter(235, source: .persistedFallback), 235, accuracy: 0.001)
    }

    func testAnchoredFallbackSidePlacementDoesNotApplyVisualCorrection() {
        let pet = CGRect(x: 900, y: 300, width: 136, height: 161)

        let center = OverlayRingPlacement.center(
            for: pet,
            ringSize: 120,
            placement: .left,
            codexPlacement: "bottom-end",
            fallbackContainerFrame: CGRect(x: 700, y: 250, width: 408, height: 400),
            geometrySource: .anchoredFallback
        )

        XCTAssertEqual(center.x, pet.minX - 120 * 0.56, accuracy: 0.001)
        XCTAssertEqual(center.y, pet.midY, accuracy: 0.001)
    }

    func testAroundRingLayoutScalesDiameterAndCenterWithPetSize() {
        let smallPet = CGRect(x: 400, y: 300, width: 100, height: 120)
        let largePet = CGRect(x: 800, y: 600, width: 200, height: 240)

        let smallDiameter = AroundPetRingLayout.diameter(for: smallPet, scale: 1)
        let largeDiameter = AroundPetRingLayout.diameter(for: largePet, scale: 1)
        XCTAssertEqual(smallDiameter, 180.790697674, accuracy: 0.001)
        XCTAssertEqual(largeDiameter, 361.581395349, accuracy: 0.001)
        let largeCenter = AroundPetRingLayout.center(for: largePet,
                                                     ringDiameter: largeDiameter,
                                                     taskCardAbove: true)
        XCTAssertEqual(largeCenter.x, 900, accuracy: 0.001)
        XCTAssertEqual(largeCenter.y, 720, accuracy: 0.001)
    }

    func testPixelLocatorFindsOpaqueMascotOnTransparentBackground() {
        let image = makeMascotImage()
        let detected = ScreenCaptureMascotLocator.detectMascot(
            in: image,
            container: CGRect(x: 100, y: 200, width: 200, height: 200),
            estimatedFrame: CGRect(x: 150, y: 200, width: 80, height: 100)
        )

        guard let detected else {
            return XCTFail("Expected a mascot rectangle")
        }
        XCTAssertEqual(detected.origin.x, 164, accuracy: 3)
        XCTAssertEqual(detected.origin.y, 204, accuracy: 3)
        XCTAssertEqual(detected.width, 80, accuracy: 3)
        XCTAssertEqual(detected.height, 100, accuracy: 3)
    }

    private func makeMascotImage() -> CGImage {
        let width = 100
        let height = 100
        let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        context.clear(CGRect(x: 0, y: 0, width: width, height: height))
        context.setFillColor(NSColor.systemTeal.cgColor)
        context.fill(CGRect(x: 32, y: 48, width: 40, height: 50))
        return context.makeImage()!
    }
}
