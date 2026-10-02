import XCTest
@testable import CodexPetUsageMac

final class AppServerProxyEnvironmentTests: XCTestCase {
    func testDisabledProxiesProduceNoEnvironment() {
        XCTAssertEqual(AppServerProxyEnvironment.map(proxies: [:]), [:])
        XCTAssertEqual(AppServerProxyEnvironment.map(proxies: [
            "HTTPEnable": 0, "HTTPProxy": "127.0.0.1", "HTTPPort": 7890,
            "HTTPSEnable": false, "HTTPSProxy": "127.0.0.1", "HTTPSPort": 7890,
            "SOCKSEnable": 0, "SOCKSProxy": "127.0.0.1", "SOCKSPort": 7890,
        ]), [:])
    }

    func testEnabledHttpProxyMapsToUpperAndLowerCaseVariables() {
        let mapped = AppServerProxyEnvironment.map(proxies: [
            "HTTPEnable": 1, "HTTPProxy": "127.0.0.1", "HTTPPort": 7890,
        ])

        XCTAssertEqual(mapped["HTTP_PROXY"], "http://127.0.0.1:7890")
        XCTAssertNil(mapped["http_proxy"])
        XCTAssertNil(mapped["HTTPS_PROXY"])
        XCTAssertNil(mapped["ALL_PROXY"])
    }

    func testEnabledHttpsAndSocksProxiesMapTogether() {
        let mapped = AppServerProxyEnvironment.map(proxies: [
            "HTTPEnable": 1, "HTTPProxy": "127.0.0.1", "HTTPPort": 7890,
            "HTTPSEnable": 1, "HTTPSProxy": "127.0.0.1", "HTTPSPort": 7890,
            "SOCKSEnable": 1, "SOCKSProxy": "10.0.0.2", "SOCKSPort": 1080,
        ])

        XCTAssertEqual(mapped["HTTPS_PROXY"], "http://127.0.0.1:7890")
        XCTAssertEqual(mapped["ALL_PROXY"], "socks5h://10.0.0.2:1080")
    }

    func testMergeNeverOverridesExistingEnvironmentValues() {
        let merged = AppServerProxyEnvironment.mergedWithSystemProxies(current: [
            "HTTPS_PROXY": "http://192.168.1.1:8888",
        ], proxies: [
            "HTTPSEnable": 1, "HTTPSProxy": "127.0.0.1", "HTTPSPort": 7890,
        ])

        XCTAssertEqual(merged["HTTPS_PROXY"], "http://192.168.1.1:8888")
    }

    func testMergeFillsMissingVariablesFromSystemProxies() {
        let merged = AppServerProxyEnvironment.mergedWithSystemProxies(current: [:], proxies: [
            "HTTPSEnable": 1, "HTTPSProxy": "127.0.0.1", "HTTPSPort": 7890,
        ])

        XCTAssertEqual(merged["HTTPS_PROXY"], "http://127.0.0.1:7890")
        XCTAssertEqual(merged["https_proxy"], "http://127.0.0.1:7890")
    }
}
