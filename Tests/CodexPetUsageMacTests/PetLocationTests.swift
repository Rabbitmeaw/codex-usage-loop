import AppKit
import XCTest
@testable import CodexPetUsageMac

final class PetLocationTests: XCTestCase {
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

    func testEstimatedMascotFrameFollowsPersistedPlacement() {
        let container = CGRect(x: 100, y: 200, width: 356, height: 320)
        let display = CGRect(x: 0, y: 0, width: 1_440, height: 900)

        let top = PetGeometry.estimatedMascotFrame(in: container, displayBounds: display, placement: "top-end")
        let bottom = PetGeometry.estimatedMascotFrame(in: container, displayBounds: display, placement: "bottom-start")

        XCTAssertEqual(top, CGRect(x: 218.5, y: 391, width: 119, height: 129))
        XCTAssertEqual(bottom, CGRect(x: 218.5, y: 200, width: 119, height: 129))
    }

    func testCGFrameConvertsToAppKitScreenCoordinates() {
        let converted = PetGeometry.appKitFrame(
            cgFrame: CGRect(x: 120, y: 100, width: 80, height: 60),
            displayBounds: CGRect(x: 0, y: 0, width: 1_440, height: 900),
            screenFrame: CGRect(x: 0, y: 0, width: 1_440, height: 900)
        )

        XCTAssertEqual(converted, CGRect(x: 120, y: 740, width: 80, height: 60))
    }

    func testRingPlacementCenterUsesTopTaskCardCorrection() {
        let pet = CGRect(x: 400, y: 300, width: 100, height: 120)

        let around = OverlayRingPlacement.center(
            for: pet,
            ringSize: 200,
            placement: .around,
            codexPlacement: "top-end"
        )
        let right = OverlayRingPlacement.center(
            for: pet,
            ringSize: 200,
            placement: .right,
            codexPlacement: "top-end"
        )

        XCTAssertEqual(around, CGPoint(x: 464, y: 320))
        XCTAssertEqual(right, CGPoint(x: 612, y: 270))
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
        XCTAssertEqual(detected.origin.y, 296, accuracy: 3)
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
