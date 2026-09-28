import Foundation

enum MascotSizeSettings {
    // Mirrors the Codex desktop renderer: width is clamped to 80...224 and the
    // height follows the mascot aspect ratio 192:208.
    static func size(widthSetting: Double?,
                     defaultWidth: Double = 112,
                     minWidth: Double = 80,
                     maxWidth: Double = 224) -> CGSize {
        let raw = widthSetting ?? defaultWidth
        let width = CGFloat(round(min(maxWidth, max(minWidth, raw))))
        let height = ceil(width / (192.0 / 208.0))
        return CGSize(width: width, height: height)
    }

    static func widthSetting(from config: String) -> Double? {
        for line in config.split(separator: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.hasPrefix("#") else { continue }
            let parts = trimmed.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
            guard parts.count == 2,
                  parts[0].trimmingCharacters(in: .whitespaces) == "avatar-overlay-mascot-width-px"
            else { continue }
            let raw = parts[1].trimmingCharacters(in: .whitespaces)
            guard let value = Double(raw), raw.rangeOfCharacter(from: CharacterSet.letters) == nil else {
                continue
            }
            return value
        }
        return nil
    }

    static func size(configAt path: String = NSHomeDirectory() + "/.codex/config.toml") -> CGSize {
        guard let config = try? String(contentsOfFile: path, encoding: .utf8) else {
            return size(widthSetting: nil)
        }
        return size(widthSetting: widthSetting(from: config))
    }
}
