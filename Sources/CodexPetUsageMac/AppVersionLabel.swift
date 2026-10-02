import Foundation

enum AppVersionLabel {
    // Display rules: an exact tag is a release build; anything ahead of a tag,
    // dirty, or not a describe output is a source deployment and is labeled
    // with the nearest release it is based on.
    static func format(sourceDescribe: String?, bundleVersion: String) -> String {
        guard let raw = sourceDescribe?.trimmingCharacters(in: .whitespacesAndNewlines),
              !raw.isEmpty else {
            return "版本 \(bundleVersion)"
        }
        var text = raw
        var dirty = false
        if text.hasSuffix("-dirty") {
            dirty = true
            text.removeLast("-dirty".count)
        }
        let pattern = #"^v(.+?)(?:-(\d+)-g([0-9a-f]+))?$"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) else {
            return "版本 \(raw)(源码)"
        }
        let distanceRange = match.range(at: 2)
        guard distanceRange.location != NSNotFound,
              let distance = Int(text[Range(distanceRange, in: text)!]), distance > 0 else {
            return dirty ? "版本 \(text)(源码,含未提交修改)" : "版本 \(text)"
        }
        var label = "版本 \(text)(源码,领先 \(distance) 个提交"
        if dirty {
            label += ",含未提交修改"
        }
        return label + ")"
    }

    static func current(bundle: Bundle = .main) -> String {
        let describe = bundle.url(forResource: "SourceVersion", withExtension: "txt")
            .flatMap { try? String(contentsOf: $0, encoding: .utf8) }
        let version = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "未知"
        return format(sourceDescribe: describe, bundleVersion: version)
    }
}
