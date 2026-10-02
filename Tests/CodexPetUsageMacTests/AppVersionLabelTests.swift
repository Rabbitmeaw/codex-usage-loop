import XCTest
@testable import CodexPetUsageMac

final class AppVersionLabelTests: XCTestCase {
    func testExactReleaseTagShowsCleanVersion() {
        XCTAssertEqual(AppVersionLabel.format(sourceDescribe: "v0.1.5", bundleVersion: "0.1.5"),
                       "版本 v0.1.5")
    }

    func testSourceAheadOfTagShowsFullDescribeWithLeadCount() {
        XCTAssertEqual(AppVersionLabel.format(sourceDescribe: "v0.1.5-3-g7f64e42", bundleVersion: "0.1.5"),
                       "版本 v0.1.5-3-g7f64e42(源码,领先 3 个提交)")
    }

    func testDirtySourceAppendsUncommittedMarker() {
        XCTAssertEqual(AppVersionLabel.format(sourceDescribe: "v0.1.5-3-g7f64e42-dirty", bundleVersion: "0.1.5"),
                       "版本 v0.1.5-3-g7f64e42(源码,领先 3 个提交,含未提交修改)")
        XCTAssertEqual(AppVersionLabel.format(sourceDescribe: "v0.1.5-dirty", bundleVersion: "0.1.5"),
                       "版本 v0.1.5(源码,含未提交修改)")
    }

    func testMissingDescribeFallsBackToBundleVersion() {
        XCTAssertEqual(AppVersionLabel.format(sourceDescribe: nil, bundleVersion: "0.1.5"),
                       "版本 0.1.5")
        XCTAssertEqual(AppVersionLabel.format(sourceDescribe: "   ", bundleVersion: "0.1.5"),
                       "版本 0.1.5")
    }

    func testUndescribableOutputIsMarkedAsSource() {
        XCTAssertEqual(AppVersionLabel.format(sourceDescribe: "7f64e42", bundleVersion: "0.1.5"),
                       "版本 7f64e42(源码)")
    }
}
