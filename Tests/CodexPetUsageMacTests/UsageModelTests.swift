import XCTest
@testable import CodexPetUsageMac

final class UsageModelTests: XCTestCase {
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

    func testStorePersistsDisplayPreferences() {
        let defaults = UserDefaults.standard
        let keys = ["alwaysVisible", "manualMoveV2", "ringPlacementV2", "statusIconModeV1"]
        keys.forEach(defaults.removeObject(forKey:))
        defer { keys.forEach(defaults.removeObject(forKey:)) }

        let store = UsageStore()
        store.alwaysVisible = true
        store.manualMove = true
        store.ringPlacement = .right
        store.statusIconMode = .monochrome

        XCTAssertTrue(defaults.bool(forKey: "alwaysVisible"))
        XCTAssertTrue(defaults.bool(forKey: "manualMoveV2"))
        XCTAssertEqual(defaults.string(forKey: "ringPlacementV2"), RingPlacement.right.rawValue)
        XCTAssertEqual(defaults.string(forKey: "statusIconModeV1"), StatusIconMode.monochrome.rawValue)
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
