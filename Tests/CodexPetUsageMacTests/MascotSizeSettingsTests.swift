import XCTest
@testable import CodexPetUsageMac

final class MascotSizeSettingsTests: XCTestCase {
    func testSizeFormulaMatchesCodexRenderer() {
        // Mirrors the desktop renderer: height = ceil(width / (192/208)).
        XCTAssertEqual(MascotSizeSettings.size(widthSetting: 96),
                       CGSize(width: 96, height: 104))
        XCTAssertEqual(MascotSizeSettings.size(widthSetting: 112),
                       CGSize(width: 112, height: 122))
        XCTAssertEqual(MascotSizeSettings.size(widthSetting: 80),
                       CGSize(width: 80, height: 87))
        XCTAssertEqual(MascotSizeSettings.size(widthSetting: 224),
                       CGSize(width: 224, height: 243))
    }

    func testSizeFormulaClampsToRendererBoundsAndRounds() {
        XCTAssertEqual(MascotSizeSettings.size(widthSetting: 10),
                       CGSize(width: 80, height: 87))
        XCTAssertEqual(MascotSizeSettings.size(widthSetting: 999),
                       CGSize(width: 224, height: 243))
        XCTAssertEqual(MascotSizeSettings.size(widthSetting: 96.6),
                       CGSize(width: 97, height: 106))
    }

    func testSizeFormulaFallsBackToDefaultWidth() {
        XCTAssertEqual(MascotSizeSettings.size(widthSetting: nil),
                       CGSize(width: 112, height: 122))
    }

    func testConfigParserExtractsWidthSetting() {
        let config = """
        # pet size
        avatar-overlay-mascot-width-px = 96
        selected-avatar-id = "custom:frieren--lingxiaotian"
        """

        XCTAssertEqual(MascotSizeSettings.widthSetting(from: config), 96)
    }

    func testConfigParserIgnoresMissingCommentedAndMalformedValues() {
        XCTAssertNil(MascotSizeSettings.widthSetting(from: "# avatar-overlay-mascot-width-px = 96"))
        XCTAssertNil(MascotSizeSettings.widthSetting(from: "avatar-overlay-mascot-width-px = \"96\""))
        XCTAssertNil(MascotSizeSettings.widthSetting(from: "avatar-overlay-mascot-width-px = 96.5.2"))
        XCTAssertNil(MascotSizeSettings.widthSetting(from: "selected-avatar-id = \"x\""))
    }
}
