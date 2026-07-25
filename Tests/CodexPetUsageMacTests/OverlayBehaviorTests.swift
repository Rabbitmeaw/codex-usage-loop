import XCTest
@testable import CodexPetUsageMac

final class OverlayBehaviorTests: XCTestCase {
    func testHiddenPetAlwaysKeepsRingButCardFollowsPreference() {
        XCTAssertTrue(PetHiddenOverlayPolicy.shouldShowRing(clientIsRunning: true))
        XCTAssertFalse(PetHiddenOverlayPolicy.shouldShowRing(clientIsRunning: false))
        XCTAssertFalse(PetHiddenOverlayPolicy.shouldShowCard(alwaysVisible: false))
        XCTAssertTrue(PetHiddenOverlayPolicy.shouldShowCard(alwaysVisible: true))
    }

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

    func testMacOS13DoesNotSupportPixelMascotLocation() {
        let macOS13 = OperatingSystemVersion(majorVersion: 13, minorVersion: 6, patchVersion: 9)

        XCTAssertFalse(PixelMascotLocationCapability.isSupported(on: macOS13))
        XCTAssertFalse(PixelMascotLocationCapability.shouldRequestAuthorization(
            on: macOS13,
            hasPermission: false
        ))
        XCTAssertEqual(
            ScreenRecordingAuthorizationStatus.menuTitle(
                on: macOS13,
                hasPermission: true
            ),
            "定位精度：使用估算（像素级定位需要 macOS 14+）"
        )
    }

    func testMacOS14KeepsPixelMascotLocationAuthorizationFlow() {
        let macOS14 = OperatingSystemVersion(majorVersion: 14, minorVersion: 0, patchVersion: 0)

        XCTAssertTrue(PixelMascotLocationCapability.isSupported(on: macOS14))
        XCTAssertTrue(PixelMascotLocationCapability.shouldRequestAuthorization(
            on: macOS14,
            hasPermission: false
        ))
        XCTAssertFalse(PixelMascotLocationCapability.shouldRequestAuthorization(
            on: macOS14,
            hasPermission: true
        ))
    }

    func testScreenRecordingMenuStatusReportsTheActualAuthorizationState() {
        let macOS14 = OperatingSystemVersion(majorVersion: 14, minorVersion: 0, patchVersion: 0)

        XCTAssertEqual(
            ScreenRecordingAuthorizationStatus.menuTitle(on: macOS14, hasPermission: true),
            "屏幕录制：已授权（像素级定位）"
        )
        XCTAssertEqual(
            ScreenRecordingAuthorizationStatus.menuTitle(on: macOS14, hasPermission: false),
            "屏幕录制：未授权（使用估算）"
        )
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

    func testMascotCaptureInputChangesWhenPetMovesInsideSameContainer() {
        let container = CGRect(x: 100, y: 200, width: 408, height: 400)
        let estimate = CGRect(x: 236, y: 439, width: 136, height: 161)

        XCTAssertFalse(ScreenCaptureMascotLocator.inputChanged(
            previousContainer: container,
            previousEstimate: estimate,
            previousLayoutSignature: "top-end|700:400",
            container: container,
            estimate: estimate,
            layoutSignature: "top-end|700:400"
        ))
        XCTAssertTrue(ScreenCaptureMascotLocator.inputChanged(
            previousContainer: container,
            previousEstimate: estimate,
            previousLayoutSignature: "top-end|700:400",
            container: container,
            estimate: estimate,
            layoutSignature: "top-end|8:400"
        ))
    }

    func testCachedMascotNeverRecapturesWithoutAnInputChange() {
        XCTAssertFalse(MascotCaptureRefreshPolicy.shouldCapture(
            hasCachedResult: true,
            inputChanged: false,
            lastAttempt: 100,
            now: 10_000
        ))
    }

    func testEventMeasurementUsesMedianFrameAcrossAnimationSamples() {
        let stabilized = ScreenCaptureMascotLocator.stabilizedFrame(from: [
            CGRect(x: 100, y: 200, width: 96, height: 110),
            CGRect(x: 102, y: 198, width: 102, height: 98),
            CGRect(x: 101, y: 199, width: 100, height: 104)
        ])

        XCTAssertEqual(stabilized, CGRect(x: 101, y: 199, width: 100, height: 104))
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
        XCTAssertTrue(MascotCaptureResultValidation.isPlausible(
            CGRect(x: 180, y: 100, width: 220, height: 300),
            estimatedFrame: estimate,
            container: container
        ))
        XCTAssertFalse(MascotCaptureResultValidation.isPlausible(
            // A task card is wide even if it is near the expected anchor.
            CGRect(x: 150, y: 100, width: 250, height: 160),
            estimatedFrame: estimate,
            container: container
        ))
        XCTAssertFalse(MascotCaptureResultValidation.isPlausible(
            // A nearly full transparent window is not a pet bounding box.
            CGRect(x: 120, y: 120, width: 350, height: 340),
            estimatedFrame: estimate,
            container: container
        ))
        XCTAssertFalse(MascotCaptureResultValidation.isPlausible(
            // A transparent 259pt subwindow was being accepted as a 250pt
            // mascot. It must remain rejected even though its center matches.
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
