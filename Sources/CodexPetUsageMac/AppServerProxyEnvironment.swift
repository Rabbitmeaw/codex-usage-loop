import Foundation
import SystemConfiguration

enum AppServerProxyEnvironment {
    // The codex app-server only honors proxy environment variables; it does not
    // read macOS system proxy settings. GUI-launched children inherit this
    // app's environment, so mirror the user's system proxy configuration into
    // the child environment without overriding values that are already set.
    static func mergedWithSystemProxies(
        current: [String: String] = ProcessInfo.processInfo.environment,
        proxies: [String: Any]? = nil
    ) -> [String: String] {
        let system = proxies ?? readSystemProxies()
        var merged = current
        for (key, value) in map(proxies: system)
        where merged[key] == nil && merged[key.lowercased()] == nil {
            merged[key] = value
            merged[key.lowercased()] = value
        }
        return merged
    }

    static func map(proxies: [String: Any]) -> [String: String] {
        var result: [String: String] = [:]
        func enabled(_ key: String) -> Bool {
            (proxies[key] as? NSNumber)?.boolValue == true
        }
        func endpoint(_ hostKey: String, _ portKey: String) -> String? {
            guard let host = proxies[hostKey] as? String, !host.isEmpty,
                  let port = (proxies[portKey] as? NSNumber)?.intValue, port > 0
            else { return nil }
            return "\(host):\(port)"
        }
        if enabled("HTTPEnable"), let endpoint = endpoint("HTTPProxy", "HTTPPort") {
            result["HTTP_PROXY"] = "http://\(endpoint)"
        }
        if enabled("HTTPSEnable"), let endpoint = endpoint("HTTPSProxy", "HTTPSPort") {
            result["HTTPS_PROXY"] = "http://\(endpoint)"
        }
        if enabled("SOCKSEnable"), let endpoint = endpoint("SOCKSProxy", "SOCKSPort") {
            result["ALL_PROXY"] = "socks5h://\(endpoint)"
        }
        return result
    }

    private static func readSystemProxies() -> [String: Any] {
        guard let proxies = SCDynamicStoreCopyProxies(nil) as? [String: Any] else {
            return [:]
        }
        return proxies
    }
}
