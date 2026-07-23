import AppKit

enum CodexDesktopProcessMatching {
    static func matches(bundleIdentifier: String?, localizedName: String?) -> Bool {
        if bundleIdentifier == "com.openai.codex" { return true }
        return localizedName?.localizedCaseInsensitiveCompare("Codex") == .orderedSame
            || localizedName?.localizedCaseInsensitiveCompare("ChatGPT") == .orderedSame
    }
}

final class CodexDesktopPresenceMonitor {
    var onPresenceChanged: ((Bool) -> Void)?

    private let workspace: NSWorkspace
    private var observers: [NSObjectProtocol] = []

    init(workspace: NSWorkspace = .shared) {
        self.workspace = workspace
    }

    func start() {
        guard observers.isEmpty else { return }
        let center = workspace.notificationCenter
        let refresh: (Notification) -> Void = { [weak self] _ in self?.publishPresence() }
        observers = [
            center.addObserver(forName: NSWorkspace.didLaunchApplicationNotification, object: nil, queue: .main, using: refresh),
            center.addObserver(forName: NSWorkspace.didTerminateApplicationNotification, object: nil, queue: .main, using: refresh)
        ]
        publishPresence()
    }

    func stop() {
        let center = workspace.notificationCenter
        observers.forEach(center.removeObserver)
        observers.removeAll()
    }

    private func publishPresence() {
        let isRunning = workspace.runningApplications.contains {
            CodexDesktopProcessMatching.matches(bundleIdentifier: $0.bundleIdentifier,
                                                 localizedName: $0.localizedName)
        }
        onPresenceChanged?(isRunning)
    }
}
