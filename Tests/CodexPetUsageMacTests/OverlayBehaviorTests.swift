import XCTest
@testable import CodexPetUsageMac

final class OverlayBehaviorTests: XCTestCase {
    func testAroundPlacementPinsCardToTheRightOfRing() {
        let origin = UsageCardLayout.origin(
            ringCenter: CGPoint(x: 500, y: 400),
            ringSize: 200,
            placement: .around,
            cardSize: CGSize(width: 190, height: 54),
            visibleFrame: CGRect(x: 0, y: 0, width: 1_000, height: 800)
        )

        XCTAssertEqual(origin.x, 612, accuracy: 0.001)
        XCTAssertEqual(origin.y, 373, accuracy: 0.001)
    }

    func testSidePlacementPinsCardBelowRing() {
        let origin = UsageCardLayout.origin(
            ringCenter: CGPoint(x: 500, y: 400),
            ringSize: 200,
            placement: .left,
            cardSize: CGSize(width: 190, height: 54),
            visibleFrame: CGRect(x: 0, y: 0, width: 1_000, height: 800)
        )

        XCTAssertEqual(origin.x, 405, accuracy: 0.001)
        XCTAssertEqual(origin.y, 234, accuracy: 0.001)
    }

    func testRealDualRingSuppressesDemoSnapshot() {
        let store = UsageStore()
        store.demoDualRing = true
        let reset = Date(timeIntervalSince1970: 1_800_000_000)
        let realSnapshot = UsageSnapshot(
            primary: UsageWindow(label: "5 小时", remainingPercent: 25, resetsAt: reset),
            secondary: UsageWindow(label: "7 天", remainingPercent: 70, resetsAt: reset),
            observedAt: reset,
            source: "test"
        )
        store.snapshot = realSnapshot

        XCTAssertFalse(store.isDualRingDemoAvailable)
        XCTAssertEqual(store.displaySnapshot, realSnapshot)
    }

    func testMissingMascotCaptureUsesRetryBackoff() {
        XCTAssertFalse(MascotCaptureRefreshPolicy.shouldCapture(
            hasCachedResult: false,
            inputChanged: true,
            lastAttempt: 100,
            now: 104.9
        ))
        XCTAssertTrue(MascotCaptureRefreshPolicy.shouldCapture(
            hasCachedResult: false,
            inputChanged: true,
            lastAttempt: 100,
            now: 105
        ))
    }

    func testCachedMascotOnlyRecapturesAfterGeometryChanges() {
        XCTAssertFalse(MascotCaptureRefreshPolicy.shouldCapture(
            hasCachedResult: true,
            inputChanged: false,
            lastAttempt: 100,
            now: 200
        ))
        XCTAssertTrue(MascotCaptureRefreshPolicy.shouldCapture(
            hasCachedResult: true,
            inputChanged: true,
            lastAttempt: 100,
            now: 101
        ))
    }

    func testPixelResultMustStayNearExpectedMascotAndSize() {
        let container = CGRect(x: 100, y: 100, width: 400, height: 400)
        let estimate = CGRect(x: 235, y: 100, width: 130, height: 160)

        XCTAssertTrue(MascotCaptureResultValidation.isPlausible(
            CGRect(x: 242, y: 108, width: 126, height: 154),
            estimatedFrame: estimate,
            container: container
        ))
        XCTAssertFalse(MascotCaptureResultValidation.isPlausible(
            CGRect(x: 120, y: 320, width: 130, height: 160),
            estimatedFrame: estimate,
            container: container
        ))
        XCTAssertFalse(MascotCaptureResultValidation.isPlausible(
            CGRect(x: 210, y: 100, width: 250, height: 160),
            estimatedFrame: estimate,
            container: container
        ))
    }

    func testCachedMascotFrameProjectsWithContainerMovement() {
        let projected = ScreenCaptureMascotLocator.projectedFrame(
            CGRect(x: 140, y: 160, width: 100, height: 80),
            from: CGRect(x: 100, y: 100, width: 400, height: 300),
            to: CGRect(x: 500, y: 200, width: 800, height: 600)
        )

        XCTAssertEqual(projected, CGRect(x: 580, y: 320, width: 200, height: 160))
    }

    func testResetGenerationRejectsStaleCaptureCompletion() {
        XCTAssertTrue(ScreenCaptureMascotLocator.accepts(completionGeneration: 3, currentGeneration: 3))
        XCTAssertFalse(ScreenCaptureMascotLocator.accepts(completionGeneration: 3, currentGeneration: 4))
    }
}
