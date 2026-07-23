import Foundation
import Combine
import CoreGraphics

enum RingPlacement: String, CaseIterable {
    case around
    case left
    case right

    var title: String {
        switch self {
        case .around: return "围绕 pet"
        case .left: return "左侧（垂直居中）"
        case .right: return "右侧（垂直居中）"
        }
    }
}

enum StatusIconMode: String, CaseIterable {
    case color
    case monochrome

    var title: String {
        switch self {
        case .color: return "原色（蓝绿）"
        case .monochrome: return "单色（跟随系统）"
        }
    }
}

struct RingColor: Equatable {
    let red: Double
    let green: Double
    let blue: Double

    init(red: Double, green: Double, blue: Double) {
        self.red = min(1, max(0, red))
        self.green = min(1, max(0, green))
        self.blue = min(1, max(0, blue))
    }

    static let defaultOuter = RingColor(red: 0.0, green: 0.78, blue: 0.69)
    static let defaultInner = RingColor(red: 0.0, green: 0.48, blue: 1.0)

    static func load(from defaults: UserDefaults, key: String, fallback: RingColor) -> RingColor {
        guard let values = defaults.array(forKey: key), values.count == 3,
              let red = values[0] as? NSNumber,
              let green = values[1] as? NSNumber,
              let blue = values[2] as? NSNumber else {
            return fallback
        }
        return RingColor(red: red.doubleValue, green: green.doubleValue, blue: blue.doubleValue)
    }

    func save(to defaults: UserDefaults, key: String) {
        defaults.set([red, green, blue], forKey: key)
    }
}

enum SnapshotOverlayRefreshPolicy {
    static func shouldRefresh(lastRefresh: TimeInterval, now: TimeInterval) -> Bool {
        now - lastRefresh >= 1
    }
}

enum UsageCardLayout {
    static func origin(ringCenter: CGPoint,
                       ringSize: CGFloat,
                       placement: RingPlacement,
                       cardSize: CGSize,
                       visibleFrame: CGRect) -> CGPoint {
        let gap: CGFloat = 12
        let proposed: CGPoint
        switch placement {
        case .around:
            proposed = CGPoint(x: ringCenter.x + ringSize / 2 + gap,
                               y: ringCenter.y - cardSize.height / 2)
        case .left, .right:
            proposed = CGPoint(x: ringCenter.x - cardSize.width / 2,
                               y: ringCenter.y - ringSize / 2 - cardSize.height - gap)
        }

        let horizontal = max(visibleFrame.minX + 8,
                             min(proposed.x, visibleFrame.maxX - cardSize.width - 8))
        let vertical = max(visibleFrame.minY + 8,
                           min(proposed.y, visibleFrame.maxY - cardSize.height - 8))
        return CGPoint(x: horizontal, y: vertical)
    }
}

struct UsageWindow: Equatable {
    let label: String
    let remainingPercent: Double
    let resetsAt: Date?

    var isWeekly: Bool { label == "7 天" }
}

struct UsageSnapshot: Equatable {
    let primary: UsageWindow?
    let secondary: UsageWindow?
    let observedAt: Date
    let source: String

    var windows: [UsageWindow] { [primary, secondary].compactMap { $0 } }
}

final class UsageStore: ObservableObject {
    @Published var snapshot: UsageSnapshot?
    @Published var demoDualRing = false
    @Published var errorMessage: String?
    @Published var alwaysVisible: Bool {
        didSet { UserDefaults.standard.set(alwaysVisible, forKey: "alwaysVisible") }
    }
    @Published var manualMove: Bool {
        didSet { UserDefaults.standard.set(manualMove, forKey: "manualMoveV2") }
    }
    @Published var ringPlacement: RingPlacement {
        didSet { UserDefaults.standard.set(ringPlacement.rawValue, forKey: "ringPlacementV2") }
    }
    @Published var statusIconMode: StatusIconMode {
        didSet { UserDefaults.standard.set(statusIconMode.rawValue, forKey: "statusIconModeV1") }
    }
    @Published var outerRingColor: RingColor {
        didSet { outerRingColor.save(to: .standard, key: "outerRingColorV1") }
    }
    @Published var innerRingColor: RingColor {
        didSet { innerRingColor.save(to: .standard, key: "innerRingColorV1") }
    }
    @Published var ringSize: CGFloat = 220
    @Published var showCard = false

    var hasRealDualRing: Bool { (snapshot?.windows.count ?? 0) > 1 }
    var isDualRingDemoAvailable: Bool { !hasRealDualRing }

    var displaySnapshot: UsageSnapshot? {
        guard demoDualRing, isDualRingDemoAvailable else { return snapshot }
        return UsageSnapshot(
            primary: UsageWindow(label: "5 小时", remainingPercent: 63, resetsAt: Date().addingTimeInterval(2 * 60 * 60)),
            secondary: UsageWindow(label: "7 天", remainingPercent: 84, resetsAt: Date().addingTimeInterval(4 * 86_400)),
            observedAt: Date(),
            source: "demo"
        )
    }

    init() {
        alwaysVisible = UserDefaults.standard.bool(forKey: "alwaysVisible")
        // The earlier builds persisted manual dragging under another key. Start
        // this geometry version in follow-pet mode; the user can enable dragging
        // again from the menu and that choice will persist under V2.
        manualMove = UserDefaults.standard.bool(forKey: "manualMoveV2")
        ringPlacement = RingPlacement(rawValue: UserDefaults.standard.string(forKey: "ringPlacementV2") ?? "") ?? .around
        statusIconMode = StatusIconMode(rawValue: UserDefaults.standard.string(forKey: "statusIconModeV1") ?? "") ?? .color
        outerRingColor = RingColor.load(from: .standard, key: "outerRingColorV1", fallback: .defaultOuter)
        innerRingColor = RingColor.load(from: .standard, key: "innerRingColorV1", fallback: .defaultInner)
    }

    func restoreDefaultRingColors() {
        outerRingColor = .defaultOuter
        innerRingColor = .defaultInner
    }
}
