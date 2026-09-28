import Foundation

struct CodexExecutableLocator {
    struct Outcome {
        var executable: URL?
        var searchedPaths: [String]
    }

    private let homeDirectory: String
    private let isExecutable: (String) -> Bool
    private let directoryNames: (String) -> [String]
    private let shellLookup: () -> String?

    init(homeDirectory: String = FileManager.default.homeDirectoryForCurrentUser.path,
         isExecutable: @escaping (String) -> Bool = { FileManager.default.isExecutableFile(atPath: $0) },
         directoryNames: @escaping (String) -> [String] = { path in
             (try? FileManager.default.contentsOfDirectory(atPath: path)) ?? []
         },
         shellLookup: @escaping () -> String? = CodexExecutableLocator.defaultShellLookup) {
        self.homeDirectory = homeDirectory
        self.isExecutable = isExecutable
        self.directoryNames = directoryNames
        self.shellLookup = shellLookup
    }

    func locate() -> Outcome {
        var searched: [String] = []
        for candidate in staticCandidates() {
            searched.append(candidate)
            if isExecutable(candidate) {
                return Outcome(executable: URL(fileURLWithPath: candidate), searchedPaths: searched)
            }
        }

        if let shellPath = shellLookup() {
            searched.append(shellPath)
            if isExecutable(shellPath) {
                return Outcome(executable: URL(fileURLWithPath: shellPath), searchedPaths: searched)
            }
        }
        return Outcome(executable: nil, searchedPaths: searched)
    }

    private func staticCandidates() -> [String] {
        var candidates = [
            "/Applications/ChatGPT.app/Contents/Resources/codex-cli/bin/codex",
            "/Applications/Codex.app/Contents/Resources/codex-cli/bin/codex",
            "/Applications/ChatGPT.app/Contents/Resources/codex",
            "/Applications/Codex.app/Contents/Resources/codex",
            "/opt/homebrew/bin/codex",
            "/usr/local/bin/codex",
            "\(homeDirectory)/.local/bin/codex",
            "\(homeDirectory)/.volta/bin/codex",
            "\(homeDirectory)/.asdf/shims/codex",
            "\(homeDirectory)/.mise/shims/codex",
            "\(homeDirectory)/Library/pnpm/codex"
        ]
        let nvmVersions = "\(homeDirectory)/.nvm/versions/node"
        for version in directoryNames(nvmVersions).sorted(by: >) {
            candidates.append("\(nvmVersions)/\(version)/bin/codex")
        }
        return candidates
    }

    private static func defaultShellLookup() -> String? {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-l", "-c", "command -v codex"]
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
        } catch {
            return nil
        }
        let deadline = Date().addingTimeInterval(2)
        while process.isRunning && Date() < deadline {
            usleep(20_000)
        }
        if process.isRunning {
            process.terminate()
            return nil
        }
        guard let line = String(data: pipe.fileHandleForReading.readDataToEndOfFile(),
                                encoding: .utf8)?
            .split(separator: "\n")
            .first else {
            return nil
        }
        let path = line.trimmingCharacters(in: .whitespaces)
        return path.isEmpty ? nil : path
    }
}
