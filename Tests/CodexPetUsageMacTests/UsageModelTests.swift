import XCTest
@testable import CodexPetUsageMac

final class UsageModelTests: XCTestCase {
    func testOuterRingHasNoUsageArcBeforeTheFirstSnapshot() {
        XCTAssertNil(RingPresentation.outerPercent(snapshot: nil))
    }

    func testUsageWindowKeepsRemainingPercentageAndResetDate() {
        let reset = Date(timeIntervalSince1970: 1_800_000_000)
        let window = UsageWindow(label: "5 小时", remainingPercent: 63, resetsAt: reset)
        XCTAssertEqual(window.remainingPercent, 63)
        XCTAssertEqual(window.resetsAt, reset)
    }

    func testStoreDefaultsToFollowPetMode() {
        let key = "alwaysVisible"
        UserDefaults.standard.removeObject(forKey: key)
        XCTAssertFalse(UsageStore().alwaysVisible)
    }

    func testStoreDefaultsToColorStatusIcon() {
        let key = "statusIconModeV1"
        UserDefaults.standard.removeObject(forKey: key)
        XCTAssertEqual(UsageStore().statusIconMode, .color)
    }

    func testSnapshotOverlayRefreshIsLimitedToOncePerSecond() {
        XCTAssertTrue(SnapshotOverlayRefreshPolicy.shouldRefresh(lastRefresh: 0, now: 1))
        XCTAssertFalse(SnapshotOverlayRefreshPolicy.shouldRefresh(lastRefresh: 1, now: 1.9))
        XCTAssertTrue(SnapshotOverlayRefreshPolicy.shouldRefresh(lastRefresh: 1, now: 2))
    }

    func testStartupOverlayRetriesAreShortAndBounded() {
        XCTAssertEqual(StartupOverlayRetryPolicy.delays, [0.1, 0.5, 1, 2])
    }

    func testCodexLaunchModeOnlyRunsClientWhileCodexIsRunning() {
        XCTAssertFalse(PetVisibilityLaunchPolicy.shouldRunClient(enabled: true, codexIsRunning: false))
        XCTAssertTrue(PetVisibilityLaunchPolicy.shouldRunClient(enabled: true, codexIsRunning: true))
        XCTAssertTrue(PetVisibilityLaunchPolicy.shouldRunClient(enabled: false, codexIsRunning: false))
    }

    func testAroundRingScaleStaysWithinSupportedRange() {
        XCTAssertEqual(AroundRingScale.clamped(0.2), AroundRingScale.minimum)
        XCTAssertEqual(AroundRingScale.clamped(2), AroundRingScale.maximum)
        XCTAssertEqual(AroundRingScale.clamped(1.25), 1.25)
    }

    func testAroundRingScaleKeepsDualRingGapProportional() {
        XCTAssertEqual(RingSizing.dualExpansion(hasDualRing: true, placement: .around, baseDiameter: 145.7625), 16.5, accuracy: 0.001)
        XCTAssertEqual(RingSizing.dualExpansion(hasDualRing: true, placement: .around, baseDiameter: 291.525), 33, accuracy: 0.001)
        XCTAssertEqual(RingSizing.dualExpansion(hasDualRing: true, placement: .left, baseDiameter: 291.525), 14)
        XCTAssertEqual(RingSizing.dualExpansion(forCanvasDiameter: 216.35, hasDualRing: true, placement: .around), 22, accuracy: 0.001)
    }

    func testCodexDesktopProcessMatchingPrefersKnownBundleIdentifier() {
        XCTAssertTrue(CodexDesktopProcessMatching.matches(bundleIdentifier: "com.openai.codex", localizedName: nil))
        XCTAssertTrue(CodexDesktopProcessMatching.matches(bundleIdentifier: nil, localizedName: "Codex"))
        XCTAssertFalse(CodexDesktopProcessMatching.matches(bundleIdentifier: nil, localizedName: "ChatGPT"))
        XCTAssertFalse(CodexDesktopProcessMatching.matches(bundleIdentifier: "com.example.other", localizedName: "Other"))
    }

    func testStorePersistsDisplayPreferences() {
        let defaults = UserDefaults.standard
        let keys = ["alwaysVisible", "manualMoveV2", "ringPlacementV2", "statusIconModeV1", "launchWithCodexPetV1", "aroundRingScaleV1"]
        keys.forEach(defaults.removeObject(forKey:))
        defer { keys.forEach(defaults.removeObject(forKey:)) }

        let store = UsageStore()
        store.alwaysVisible = true
        store.manualMove = true
        store.ringPlacement = .right
        store.statusIconMode = .monochrome
        store.launchWithCodexPet = true
        store.aroundRingScale = 1.25

        XCTAssertTrue(defaults.bool(forKey: "alwaysVisible"))
        XCTAssertTrue(defaults.bool(forKey: "manualMoveV2"))
        XCTAssertEqual(defaults.string(forKey: "ringPlacementV2"), RingPlacement.right.rawValue)
        XCTAssertEqual(defaults.string(forKey: "statusIconModeV1"), StatusIconMode.monochrome.rawValue)
        XCTAssertTrue(defaults.bool(forKey: "launchWithCodexPetV1"))
        XCTAssertEqual(defaults.double(forKey: "aroundRingScaleV1"), 1.25)
    }

    func testStorePersistsCustomRingColorsAndRestoresDefaults() {
        let defaults = UserDefaults.standard
        let keys = ["outerRingColorV1", "innerRingColorV1"]
        keys.forEach(defaults.removeObject(forKey:))
        defer { keys.forEach(defaults.removeObject(forKey:)) }

        let store = UsageStore()
        XCTAssertEqual(store.outerRingColor, .defaultOuter)
        XCTAssertEqual(store.innerRingColor, .defaultInner)

        let outer = RingColor(red: 0.1, green: 0.2, blue: 0.3)
        let inner = RingColor(red: 0.8, green: 0.7, blue: 0.6)
        store.outerRingColor = outer
        store.innerRingColor = inner

        XCTAssertEqual(UsageStore().outerRingColor, outer)
        XCTAssertEqual(UsageStore().innerRingColor, inner)

        store.restoreDefaultRingColors()
        XCTAssertEqual(store.outerRingColor, .defaultOuter)
        XCTAssertEqual(store.innerRingColor, .defaultInner)
    }
}
