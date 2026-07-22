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
}
