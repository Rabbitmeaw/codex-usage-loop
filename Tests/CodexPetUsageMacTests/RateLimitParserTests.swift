import XCTest
@testable import CodexPetUsageMac

final class RateLimitParserTests: XCTestCase {
    func testParserMapsUsedAndRemainingPercentIntoTwoWindows() {
        let observedAt = Date(timeIntervalSince1970: 1_800_000_000)
        let snapshot = RateLimitParser.snapshot(
            from: [
                "primary": [
                    "usedPercent": "37.5",
                    "resetsAt": 1_800_000_100,
                    "windowDurationMins": 300
                ],
                "secondary": [
                    "remainingPercent": 140,
                    "windowDurationMins": 10_080
                ]
            ],
            observedAt: observedAt
        )

        XCTAssertEqual(snapshot?.primary?.label, "5 小时")
        XCTAssertEqual(snapshot?.primary?.remainingPercent, 62.5)
        XCTAssertEqual(snapshot?.primary?.resetsAt, Date(timeIntervalSince1970: 1_800_000_100))
        XCTAssertEqual(snapshot?.secondary?.label, "7 天")
        XCTAssertEqual(snapshot?.secondary?.remainingPercent, 100)
        XCTAssertEqual(snapshot?.observedAt, observedAt)
    }

    func testParserUsesCurrentWindowForOtherDurationsAndClampsNegativeValues() {
        let snapshot = RateLimitParser.snapshot(from: [
            "primary": [
                "remainingPercent": -10,
                "windowDurationMins": 1_440
            ]
        ])

        XCTAssertEqual(snapshot?.primary?.label, "当前窗口")
        XCTAssertEqual(snapshot?.primary?.remainingPercent, 0)
        XCTAssertNil(snapshot?.secondary)
    }

    func testParserRejectsLimitPayloadWithoutUsablePercentages() {
        XCTAssertNil(RateLimitParser.snapshot(from: [
            "primary": ["remainingPercent": "not-a-number"],
            "secondary": [:]
        ]))
    }
}
