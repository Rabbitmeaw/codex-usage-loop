import Foundation

enum AppServerOutputPolicy {
    static func shouldKeepMonitoring(after data: Data) -> Bool {
        !data.isEmpty
    }
}

enum RateLimitParser {
    static func snapshot(from limits: [String: Any],
                         observedAt: Date = Date(),
                         source: String = "codex app-server") -> UsageSnapshot? {
        let primary = window(from: limits["primary"] as? [String: Any])
        let secondary = window(from: limits["secondary"] as? [String: Any])
        guard primary != nil || secondary != nil else { return nil }
        return UsageSnapshot(primary: primary,
                             secondary: secondary,
                             observedAt: observedAt,
                             source: source)
    }

    static func window(from value: [String: Any]?) -> UsageWindow? {
        guard let value else { return nil }
        let used = number(value["usedPercent"])
        let remaining = number(value["remainingPercent"])
        guard let percent = remaining ?? used.map({ 100 - $0 }) else { return nil }
        let reset = number(value["resetsAt"]).map { Date(timeIntervalSince1970: $0) }
        let duration = number(value["windowDurationMins"])
        let label: String
        if let duration, duration >= 10_000 {
            label = "7 天"
        } else if let duration, duration <= 720 {
            label = "5 小时"
        } else {
            label = "当前窗口"
        }
        return UsageWindow(label: label,
                           remainingPercent: max(0, min(100, percent)),
                           resetsAt: reset)
    }

    private static func number(_ value: Any?) -> Double? {
        if let value = value as? NSNumber { return value.doubleValue }
        if let value = value as? Double { return value }
        if let value = value as? Int { return Double(value) }
        if let value = value as? String { return Double(value) }
        return nil
    }
}

final class CodexAppServerClient {
    var onSnapshot: ((UsageSnapshot) -> Void)?
    var onError: ((Error) -> Void)?

    private let queue = DispatchQueue(label: "com.codexusageloop.appserver")
    private var process: Process?
    private var input: FileHandle?
    private var buffer = Data()
    private var requestID = 10
    private var stopping = false

    func start() { queue.async { [weak self] in self?.startLocked() } }

    func refresh() {
        queue.async { [weak self] in
            guard let self else { return }
            if self.process?.isRunning != true { self.startLocked(); return }
            self.sendRequest("account/rateLimits/read")
        }
    }

    func stop() {
        queue.sync {
            stopping = true
            process?.terminationHandler = nil
            process?.terminate()
            process = nil
            input = nil
            buffer.removeAll()
        }
    }

    private func startLocked() {
        guard process?.isRunning != true else { return }
        stopping = false
        buffer.removeAll()
        guard let executable = locateCodexExecutable() else {
            dispatchError(NSError(domain: "CodexUsageLoop", code: 1, userInfo: [NSLocalizedDescriptionKey: "没有找到 Codex 可执行文件"]))
            return
        }

        let process = Process()
        let stdin = Pipe()
        let stdout = Pipe()
        let stderr = Pipe()
        process.executableURL = executable
        process.arguments = ["app-server", "--stdio"]
        process.standardInput = stdin
        process.standardOutput = stdout
        process.standardError = stderr
        input = stdin.fileHandleForWriting
        self.process = process

        stdout.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard AppServerOutputPolicy.shouldKeepMonitoring(after: data) else {
                // EOF remains readable forever. Leaving this handler installed
                // turns a closed app-server pipe into a CPU busy loop.
                handle.readabilityHandler = nil
                return
            }
            self?.queue.async { self?.consume(data) }
        }
        stderr.fileHandleForReading.readabilityHandler = { handle in
            // stderr is intentionally not surfaced in the compact overlay,
            // but it must still be drained and detached at EOF. An empty
            // pipe remains readable and otherwise spins the monitoring queue.
            let data = handle.availableData
            if !AppServerOutputPolicy.shouldKeepMonitoring(after: data) {
                handle.readabilityHandler = nil
            }
        }
        process.terminationHandler = { [weak self] terminated in
            guard let self else { return }
            self.queue.async {
                guard !self.stopping else { return }
                self.process = nil
                self.input = nil
                self.dispatchError(NSError(domain: "CodexUsageLoop", code: 2, userInfo: [NSLocalizedDescriptionKey: "Codex 用量服务已退出（\(terminated.terminationStatus)）"]))
            }
        }

        do {
            try process.run()
            send(["id": 1, "method": "initialize", "params": [
                "clientInfo": ["name": "codexusageloop-mac", "title": "CodexUsageLoop", "version": "0.1.2"],
                "capabilities": ["experimentalApi": true]
            ]])
        } catch {
            self.process = nil
            self.input = nil
            dispatchError(error)
        }
    }

    private func consume(_ data: Data) {
        buffer.append(data)
        while let newline = buffer.firstIndex(of: 0x0A) {
            let line = buffer.subdata(in: buffer.startIndex..<newline)
            buffer.removeSubrange(buffer.startIndex...newline)
            if !line.isEmpty { parse(line) }
        }
    }

    private func parse(_ data: Data) {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }
        if let id = object["id"] as? Int, id == 1, object["result"] != nil {
            send(["method": "initialized"])
            sendRequest("account/rateLimits/read")
            return
        }
        if let result = object["result"] as? [String: Any], let limits = result["rateLimits"] as? [String: Any] {
            publish(limits)
        }
        if object["method"] as? String == "account/rateLimits/updated",
           let params = object["params"] as? [String: Any],
           let limits = params["rateLimits"] as? [String: Any] {
            publish(limits)
        }
    }

    private func publish(_ limits: [String: Any]) {
        guard let snapshot = RateLimitParser.snapshot(from: limits) else { return }
        DispatchQueue.main.async { [weak self] in self?.onSnapshot?(snapshot) }
    }

    private func sendRequest(_ method: String) {
        requestID += 1
        send(["id": requestID, "method": method, "params": NSNull()])
    }

    private func send(_ object: [String: Any]) {
        guard let input, let data = try? JSONSerialization.data(withJSONObject: object) else { return }
        do { try input.write(contentsOf: data + Data([0x0A])) } catch { dispatchError(error) }
    }

    private func dispatchError(_ error: Error) {
        DispatchQueue.main.async { [weak self] in self?.onError?(error) }
    }

    private func locateCodexExecutable() -> URL? {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let paths = [
            "/Applications/Codex.app/Contents/Resources/codex",
            "/Applications/ChatGPT.app/Contents/Resources/codex",
            "/opt/homebrew/bin/codex", "/usr/local/bin/codex", "\(home)/.local/bin/codex"
        ]
        return paths.lazy.map(URL.init(fileURLWithPath:)).first { FileManager.default.isExecutableFile(atPath: $0.path) }
    }
}
