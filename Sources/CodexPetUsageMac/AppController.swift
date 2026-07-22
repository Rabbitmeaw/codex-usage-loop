import AppKit
import SwiftUI

final class AppController: NSObject, NSApplicationDelegate {
    private let store = UsageStore()
    private let client = CodexAppServerClient()
    private let locator = PetWindowLocator()
    private var panel: NSPanel!
    private var cardPanel: NSPanel!
    private var statusItem: NSStatusItem!
    private var locatorTimer: Timer?
    private var refreshTimer: Timer?
    private var lastRingCenter = NSPoint(x: 200, y: 200)
    private var activeRingColorTarget: RingColorTarget?

    private enum RingColorTarget {
        case outer
        case inner
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // This is an accessory app, so `open` can otherwise create several
        // independent overlay processes. Keep the first instance and exit any
        // later launch before it can create another ScreenCaptureKit client.
        let currentPID = ProcessInfo.processInfo.processIdentifier
        let duplicateExists = NSRunningApplication.runningApplications(
            withBundleIdentifier: Bundle.main.bundleIdentifier ?? ""
        ).contains { $0.processIdentifier != currentPID }
        if duplicateExists {
            NSApp.terminate(nil)
            return
        }

        NSApp.setActivationPolicy(.accessory)
        createPanel()
        createStatusItem()
        applyInteractionMode()

        client.onSnapshot = { [weak self] snapshot in
            guard let self else { return }
            self.store.snapshot = snapshot
            self.store.errorMessage = nil
            if self.store.hasRealDualRing { self.store.demoDualRing = false }
            self.rebuildMenu()
        }
        client.onError = { [weak self] error in self?.store.errorMessage = error.localizedDescription }
        client.start()

        refreshTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in self?.client.refresh() }
        // Pet geometry is persisted by Codex and does not need a high-rate
        // polling loop. Keep the overlay responsive while avoiding repeated
        // state reads and unnecessary fallback captures.
        locatorTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in self?.updateOverlay() }
        client.refresh()
    }

    func applicationWillTerminate(_ notification: Notification) {
        locatorTimer?.invalidate()
        refreshTimer?.invalidate()
        client.stop()
    }

    private func createPanel() {
        panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 250, height: 220),
                        styleMask: [.borderless, .nonactivatingPanel],
                        backing: .buffered, defer: true)
        panel.contentView = NSHostingView(rootView: OverlayView(store: store))
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.hidesOnDeactivate = false
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.isMovableByWindowBackground = true
        panel.orderOut(nil)

        cardPanel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 190, height: 54),
                            styleMask: [.borderless, .nonactivatingPanel],
                            backing: .buffered, defer: true)
        cardPanel.contentView = NSHostingView(rootView: UsageCardView(store: store))
        cardPanel.isFloatingPanel = true
        cardPanel.level = .floating
        cardPanel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        cardPanel.hidesOnDeactivate = false
        cardPanel.isOpaque = false
        cardPanel.backgroundColor = .clear
        cardPanel.hasShadow = false
        cardPanel.ignoresMouseEvents = true
        cardPanel.orderOut(nil)
    }

    private func createStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        updateStatusIcon()
        rebuildMenu()
    }

    private func updateStatusIcon() {
        if let button = statusItem.button {
            button.toolTip = "CodexUsageLoop"
            if let url = Bundle.main.url(forResource: "AppIcon", withExtension: "icns"),
               let image = NSImage(contentsOf: url) {
                image.isTemplate = store.statusIconMode == .monochrome
                image.size = NSSize(width: 18, height: 18)
                button.image = image
                button.imagePosition = .imageOnly
                button.imageScaling = .scaleProportionallyDown
                button.title = ""
            } else {
                button.title = "◉"
            }
        }
    }

    private func rebuildMenu() {
        statusItem.menu = makeMenu()
    }

    private func makeMenu() -> NSMenu {
        let menu = NSMenu()
        let always = NSMenuItem(title: "始终显示用量卡片", action: #selector(toggleAlwaysVisible), keyEquivalent: "")
        always.target = self
        always.state = store.alwaysVisible ? .on : .off
        menu.addItem(always)
        let manual = NSMenuItem(title: "自由拖动位置", action: #selector(toggleManualMove), keyEquivalent: "")
        manual.target = self
        manual.state = store.manualMove ? .on : .off
        menu.addItem(manual)
        let placement = NSMenuItem(title: "圆环固定位置", action: nil, keyEquivalent: "")
        let placementMenu = NSMenu()
        for option in RingPlacement.allCases {
            let item = NSMenuItem(title: option.title, action: #selector(selectRingPlacement), keyEquivalent: "")
            item.target = self
            item.representedObject = option.rawValue
            item.state = store.ringPlacement == option ? .on : .off
            placementMenu.addItem(item)
        }
        placement.submenu = placementMenu
        menu.addItem(placement)
        let colors = NSMenuItem(title: "圆环颜色", action: nil, keyEquivalent: "")
        let colorsMenu = NSMenu()
        let outerColor = NSMenuItem(title: "外环颜色…", action: #selector(selectOuterRingColor), keyEquivalent: "")
        outerColor.target = self
        colorsMenu.addItem(outerColor)
        let innerColor = NSMenuItem(title: "内环颜色…", action: #selector(selectInnerRingColor), keyEquivalent: "")
        innerColor.target = self
        colorsMenu.addItem(innerColor)
        colorsMenu.addItem(.separator())
        let restoreColors = NSMenuItem(title: "恢复默认蓝绿", action: #selector(restoreDefaultRingColors), keyEquivalent: "")
        restoreColors.target = self
        colorsMenu.addItem(restoreColors)
        colors.submenu = colorsMenu
        menu.addItem(colors)
        let iconMode = NSMenuItem(title: "菜单栏图标", action: nil, keyEquivalent: "")
        let iconModeMenu = NSMenu()
        for option in StatusIconMode.allCases {
            let item = NSMenuItem(title: option.title, action: #selector(selectStatusIconMode), keyEquivalent: "")
            item.target = self
            item.representedObject = option.rawValue
            item.state = store.statusIconMode == option ? .on : .off
            iconModeMenu.addItem(item)
        }
        iconMode.submenu = iconModeMenu
        menu.addItem(iconMode)
        let demo = NSMenuItem(title: "演示双环", action: #selector(toggleDualRingDemo), keyEquivalent: "")
        demo.target = self
        demo.isEnabled = store.isDualRingDemoAvailable
        demo.state = store.demoDualRing && store.isDualRingDemoAvailable ? .on : .off
        if !demo.isEnabled { demo.toolTip = "真实双环存在时不可用" }
        menu.addItem(demo)
        menu.addItem(.separator())
        let refresh = NSMenuItem(title: "立即刷新", action: #selector(refresh), keyEquivalent: "r")
        refresh.target = self
        menu.addItem(refresh)
        let recalibrate = NSMenuItem(title: "重新检测宠物位置/大小", action: #selector(recalibrate), keyEquivalent: "")
        recalibrate.target = self
        menu.addItem(recalibrate)
        menu.addItem(.separator())
        let quit = NSMenuItem(title: "退出", action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)
        return menu
    }

    @objc private func toggleAlwaysVisible(_ sender: NSMenuItem) {
        store.alwaysVisible.toggle()
        sender.state = store.alwaysVisible ? .on : .off
        updateOverlay()
    }

    @objc private func toggleManualMove(_ sender: NSMenuItem) {
        store.manualMove.toggle()
        sender.state = store.manualMove ? .on : .off
        applyInteractionMode()
        updateOverlay()
    }

    @objc private func selectRingPlacement(_ sender: NSMenuItem) {
        guard let rawValue = sender.representedObject as? String,
              let placement = RingPlacement(rawValue: rawValue) else { return }
        store.ringPlacement = placement
        rebuildMenu()
        updateOverlay()
    }

    @objc private func selectStatusIconMode(_ sender: NSMenuItem) {
        guard let rawValue = sender.representedObject as? String,
              let mode = StatusIconMode(rawValue: rawValue) else { return }
        store.statusIconMode = mode
        updateStatusIcon()
        rebuildMenu()
    }

    @objc private func selectOuterRingColor() {
        presentColorPanel(for: .outer)
    }

    @objc private func selectInnerRingColor() {
        presentColorPanel(for: .inner)
    }

    @objc private func restoreDefaultRingColors() {
        store.restoreDefaultRingColors()
        updateOverlay()
    }

    private func presentColorPanel(for target: RingColorTarget) {
        activeRingColorTarget = target
        let ringColor = target == .outer ? store.outerRingColor : store.innerRingColor
        let panel = NSColorPanel.shared
        panel.color = NSColor(srgbRed: ringColor.red,
                              green: ringColor.green,
                              blue: ringColor.blue,
                              alpha: 1)
        panel.setTarget(self)
        panel.setAction(#selector(changeRingColor(_:)))
        panel.orderFront(nil)
    }

    @objc private func changeRingColor(_ sender: NSColorPanel) {
        guard let target = activeRingColorTarget,
              let color = sender.color.usingColorSpace(.sRGB) else { return }
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        color.getRed(&red, green: &green, blue: &blue, alpha: nil)
        let value = RingColor(red: red, green: green, blue: blue)
        switch target {
        case .outer: store.outerRingColor = value
        case .inner: store.innerRingColor = value
        }
        updateOverlay()
    }

    @objc private func toggleDualRingDemo(_ sender: NSMenuItem) {
        guard store.isDualRingDemoAvailable else { return }
        store.demoDualRing.toggle()
        sender.state = store.demoDualRing ? .on : .off
        updateOverlay()
    }

    private func applyInteractionMode() {
        panel.ignoresMouseEvents = !store.manualMove
        panel.isMovableByWindowBackground = store.manualMove
    }

    @objc private func refresh() {
        client.refresh()
        recalibrate()
    }

    @objc private func recalibrate() {
        locator.reset()
        updateOverlay()
    }
    @objc private func quit() { NSApp.terminate(nil) }

    private func updateOverlay() {
        let pet = locator.locate()
        if let pet {
            let petFrame = appKitFrame(for: pet)
            let scale = max(1, screen(for: pet.displayID)?.backingScaleFactor ?? 1)
            let petRingSize = max(104, (max(petFrame.width, petFrame.height) / scale + 40) * 1.15)
            let baseRingSize = store.ringPlacement == .around
                ? petRingSize
                // Side placement keeps its established compact single-ring
                // diameter. Dual-ring space is added outside this baseline.
                : max(48, petRingSize * 0.30)
            let hasDualRing = (store.displaySnapshot?.windows.count ?? 0) > 1
            // Preserve the single-ring diameter as the dual-ring inner track.
            // Only the outer track receives additional canvas around it.
            let dualExpansion: CGFloat = store.ringPlacement == .around ? 22 : 14
            let ringSize = baseRingSize + (hasDualRing ? dualExpansion : 0)
            if store.ringSize != ringSize { store.ringSize = ringSize }
            let ringCenter = OverlayRingPlacement.center(for: petFrame,
                                                         ringSize: baseRingSize,
                                                         placement: store.ringPlacement,
                                                         codexPlacement: pet.placement)
            lastRingCenter = ringCenter

            let hovered = hypot(NSEvent.mouseLocation.x - ringCenter.x, NSEvent.mouseLocation.y - ringCenter.y) <= store.ringSize / 2 + 12
            let shouldShowCard = store.alwaysVisible || hovered
            if store.showCard != shouldShowCard { store.showCard = shouldShowCard }
            let canvasSize = ringSize + 16
            let canvasSizeValue = NSSize(width: canvasSize, height: canvasSize)
            if panel.contentView?.bounds.size != canvasSizeValue { panel.setContentSize(canvasSizeValue) }
            if !store.manualMove {
                let origin = NSPoint(x: ringCenter.x - canvasSize / 2,
                                     y: ringCenter.y - canvasSize / 2)
                if panel.frame.origin != origin { panel.setFrameOrigin(origin) }
            }
            if !panel.isVisible { panel.orderFrontRegardless() }
            if shouldShowCard {
                updateCardPanel(ringCenter: ringCenter, ringSize: ringSize)
            } else {
                cardPanel.orderOut(nil)
            }
        } else if store.alwaysVisible {
            if !store.showCard { store.showCard = true }
            if !panel.isVisible {
                store.ringSize = 210
                panel.setContentSize(NSSize(width: 210, height: 210))
                panel.setFrameOrigin(NSPoint(x: 24, y: 24))
                lastRingCenter = NSPoint(x: 24 + 105, y: 24 + 105)
            }
            if !panel.isVisible { panel.orderFrontRegardless() }
            updateCardPanel(ringCenter: lastRingCenter, ringSize: store.ringSize)
        } else {
            if store.showCard { store.showCard = false }
            cardPanel.orderOut(nil)
            panel.orderOut(nil)
        }
    }

    private func updateCardPanel(ringCenter: NSPoint, ringSize: CGFloat) {
        let cardHeight: CGFloat = (store.displaySnapshot?.windows.count ?? 0) > 1 ? 70 : 54
        let cardWidth: CGFloat = 190
        let screen = NSScreen.screens.first(where: { $0.frame.contains(ringCenter) }) ?? NSScreen.main
        let bounds = screen?.visibleFrame ?? .zero
        let origin = UsageCardLayout.origin(
            ringCenter: ringCenter,
            ringSize: ringSize,
            placement: store.ringPlacement,
            cardSize: NSSize(width: cardWidth, height: cardHeight),
            visibleFrame: bounds
        )
        let size = NSSize(width: cardWidth, height: cardHeight)
        if cardPanel.contentView?.bounds.size != size { cardPanel.setContentSize(size) }
        if cardPanel.frame.origin != origin { cardPanel.setFrameOrigin(origin) }
        if !cardPanel.isVisible { cardPanel.orderFrontRegardless() }
    }

    private func screen(for displayID: CGDirectDisplayID) -> NSScreen? {
        if let exact = NSScreen.screens.first(where: {
            guard let number = $0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else {
                return false
            }
            return number.uint32Value == displayID
        }) {
            return exact
        }

        // Codex's Electron displayId is not guaranteed to equal NSScreenNumber.
        // Match the physical display geometry instead of falling back to main.
        let cgBounds = CGDisplayBounds(displayID)
        return NSScreen.screens.min {
            screenDistance($0, to: cgBounds) < screenDistance($1, to: cgBounds)
        }
    }

    private func screenDistance(_ screen: NSScreen, to cgBounds: CGRect) -> CGFloat {
        let scale = max(1, screen.backingScaleFactor)
        return abs(screen.frame.width * scale - cgBounds.width)
            + abs(screen.frame.height * scale - cgBounds.height)
    }

    private func appKitFrame(for pet: PetWindow) -> NSRect {
        let cgScreen = CGDisplayBounds(pet.displayID)
        let nsScreen = screen(for: pet.displayID) ?? NSScreen.main!
        return PetGeometry.appKitFrame(cgFrame: pet.frame,
                                       displayBounds: cgScreen,
                                       screenFrame: nsScreen.frame)
    }
}

@main
struct CodexPetUsageMacApp: App {
    @NSApplicationDelegateAdaptor(AppController.self) private var appController

    var body: some Scene { Settings { EmptyView() } }
}
