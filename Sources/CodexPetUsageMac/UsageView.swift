import SwiftUI

struct UsageCardView: View {
    @ObservedObject var store: UsageStore

    var body: some View {
        card
    }

    private var card: some View {
        HStack(spacing: 8) { details }
            .padding(10)
            .frame(width: 190, height: visibleWindows.count > 1 ? 70 : 54)
            .background(Color.black.opacity(0.56), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(cardBorder)
            .shadow(color: .black.opacity(0.28), radius: 12, y: 5)
            .preferredColorScheme(.dark)
    }

    private var cardBorder: some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .stroke(.white.opacity(0.18), lineWidth: 1)
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: 5) {
            ForEach(visibleWindows, id: \.label) { window in
                usageLine(window: window, color: ringColor(for: window))
            }
            Text(statusText)
                .font(.system(size: 9, design: .rounded))
                .foregroundStyle(.white.opacity(0.55))
        }
    }

    private var statusText: String {
        if store.demoDualRing { return "双环演示（本地模拟）" }
        if let snapshot = store.displaySnapshot { return "更新于 \(snapshot.observedAt.formatted(date: .omitted, time: .shortened))" }
        return store.errorMessage ?? "等待 Codex 用量"
    }

    private var visibleWindows: [UsageWindow] {
        store.displaySnapshot?.windows ?? []
    }

    private func ringColor(for window: UsageWindow) -> Color {
        let hasShortWindow = visibleWindows.contains { !$0.isWeekly }
        return Color(ringColor: window.isWeekly && hasShortWindow ? store.innerRingColor : store.outerRingColor)
    }

}

struct UsageRingsView: View {
    @ObservedObject var store: UsageStore

    var body: some View {
        let shortWindow = store.displaySnapshot?.windows.first(where: { !$0.isWeekly })
        let weeklyWindow = store.displaySnapshot?.windows.first(where: { $0.isWeekly })
        let outerWindow = shortWindow ?? weeklyWindow
        let compactRing = store.ringPlacement != .around
        let hasDualRing = shortWindow != nil && weeklyWindow != nil
        let outerInset: CGFloat = 9
        let dualExpansion: CGFloat = hasDualRing
            ? (compactRing ? 14 : 22)
            : 0
        GeometryReader { geometry in
            ZStack {
                if let outerWindow {
                    ring(percent: outerWindow.remainingPercent,
                         color: Color(ringColor: store.outerRingColor),
                         inset: outerInset,
                         size: geometry.size,
                         sideStroke: compactRing)
                }
                if let weeklyWindow, shortWindow != nil {
                    ring(percent: weeklyWindow.remainingPercent,
                         color: Color(ringColor: store.innerRingColor),
                         // The canvas is expanded for the outer ring. This
                         // inset keeps the inner weekly ring exactly equal to
                         // the single-ring diameter.
                         inset: outerInset + dualExpansion / 2,
                         size: geometry.size,
                         sideStroke: compactRing)
                }
            }
        }
        .background(Color.clear)
        .allowsHitTesting(false)
    }

    private func ring(percent: Double?, color: Color, inset: CGFloat, size: CGSize, sideStroke: Bool) -> some View {
        let diameter = max(0, min(size.width, size.height) - inset * 2)
        let lineWidth = max(2, min(sideStroke ? 6 : 5, diameter * (sideStroke ? 0.055 : 0.045)))
        return ZStack {
            Circle()
                .stroke(color.opacity(0.24), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: CGFloat((percent ?? 0) / 100))
                .stroke(color.opacity(0.95), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
            .frame(width: diameter, height: diameter)
    }
}

private extension Color {
    init(ringColor: RingColor) {
        self.init(red: ringColor.red, green: ringColor.green, blue: ringColor.blue)
    }
}

struct OverlayView: View {
    @ObservedObject var store: UsageStore

    var body: some View {
        VStack(spacing: 14) {
            UsageRingsView(store: store)
                .frame(width: store.ringSize, height: store.ringSize)
                .padding(8)
        }
        .frame(width: max(104, store.ringSize + 16), height: store.ringSize + 16)
    }
}

extension UsageCardView {
    private func usageLine(window: UsageWindow, color: Color) -> some View {
        HStack(spacing: 5) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text("\(window.label)  \(String(format: "%.0f%% 剩余", window.remainingPercent))")
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.85))
            if let reset = window.resetsAt { Text("· \(countdown(to: reset))") }
        }
        .font(.system(size: 10, design: .rounded))
        .foregroundStyle(.white.opacity(0.55))
    }

    private func countdown(to date: Date) -> String {
        let seconds = max(0, Int(date.timeIntervalSinceNow))
        if seconds >= 86_400 { return "\(seconds / 86_400)天后" }
        if seconds >= 3_600 { return "\(seconds / 3_600)小时后" }
        return "\(max(1, seconds / 60))分钟后"
    }
}
