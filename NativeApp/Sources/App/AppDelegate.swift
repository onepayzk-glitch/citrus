import AppKit
import Combine
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var updateMenuItem: NSMenuItem?
    private var statusItem: NSStatusItem?
    private var iconCancellable: AnyCancellable?
    private let dragMonitor = DragMonitor()
    private let radial = RadialController()
    private var settingsWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        DiagnosticLog.start()
        NSApp.setActivationPolicy(.accessory)
        AppSettings.shared.applyAppearance()
        NSApp.applicationIconImage = BrandArtwork.image(size: 256)
        installStatusItem()
        UpdateChecker.shared.onAvailable = { [weak self] version in
            self?.updateMenuItem?.title = "Download update \(version) from website…"
            self?.statusItem?.button?.toolTip = "Citrus — update \(version) available"
            self?.statusItem?.button?.image = NSImage(systemSymbolName: "arrow.down.circle.fill", accessibilityDescription: "Update available")
        }
        UpdateChecker.shared.start()
        if ScreenshotDriver.isEnabled {
            ScreenshotDriver.run(radial: radial)
            return
        }
        dragMonitor.delegate = radial
        dragMonitor.start()
        // Login-item launches stay quietly in the menu bar; show the welcome guide once.
        if !UserDefaults.standard.bool(forKey: "hasCompletedWelcome") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                OnboardingWindowController.shared.show()
            }
        } else if !UserDefaults.standard.bool(forKey: "hasOpenedSettings") {
            UserDefaults.standard.set(true, forKey: "hasOpenedSettings")
            openSettings()
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    func application(_ application: NSApplication, open urls: [URL]) {
        radial.presentPicker(for: urls)
    }

    private func installStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: 32)
        if let button = item.button {
            button.image = BrandArtwork.menuBarImage(style: AppSettings.shared.menuBarIconStyle)
            button.imageScaling = .scaleProportionallyDown
            button.toolTip = L10n.t("Citrus: hold Shift while dragging a file")
        }
        let menu = NSMenu()
        menu.addItem(withTitle: "Convert Files…", action: #selector(convertFiles), keyEquivalent: "o").target = self
        menu.addItem(withTitle: "Open Tool for Files…", action: #selector(openTool), keyEquivalent: "t").target = self
        menu.addItem(withTitle: "File Actions…", action: #selector(fileActions), keyEquivalent: "a").target = self
        menu.addItem(withTitle: "Getting Started…", action: #selector(showOnboarding), keyEquivalent: "").target = self
        menu.addItem(withTitle: "Feedback…", action: #selector(openFeedback), keyEquivalent: "").target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "Settings…", action: #selector(openSettings), keyEquivalent: ",").target = self
        menu.addItem(withTitle: "About Citrus", action: #selector(about), keyEquivalent: "").target = self
        let update = menu.addItem(withTitle: "Check for Updates on Website…", action: #selector(checkForUpdates), keyEquivalent: "")
        update.target = self
        update.image = NSImage(systemSymbolName: "arrow.clockwise", accessibilityDescription: "Check for updates")
        updateMenuItem = update
        menu.addItem(withTitle: "Show Logs", action: #selector(showLogs), keyEquivalent: "").target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit Citrus", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        let symbols = ["Convert Files…": "arrow.triangle.2.circlepath", "Open Tool for Files…": "wrench.and.screwdriver",
                       "File Actions…": "doc.on.doc", "Getting Started…": "sparkles", "Feedback…": "bubble.left.and.text.bubble.right", "Settings…": "gearshape", "About Citrus": "info.circle",
                       "Check for Updates on Website…": "arrow.clockwise", "Show Logs": "doc.text.magnifyingglass",
                       "Quit Citrus": "power"]
        for entry in menu.items {
            if let symbol = symbols[entry.title] {
                entry.image = NSImage(systemSymbolName: symbol, accessibilityDescription: entry.title)
            }
        }
        for entry in menu.items where !entry.isSeparatorItem {
            entry.title = L10n.t(entry.title)
        }
        item.menu = menu
        statusItem = item
        iconCancellable = AppSettings.shared.$menuBarIconStyle.sink { [weak self] style in
            self?.statusItem?.button?.image = BrandArtwork.menuBarImage(style: style)
        }
    }

    @MainActor
    @objc private func checkForUpdates() { Task { await UpdateChecker.shared.check(interactive: true) } }

    @objc private func convertFiles() {
        pickFiles { [weak self] urls in self?.radial.presentPicker(for: urls, advanced: false) }
    }

    @MainActor
    @objc private func showOnboarding() { OnboardingWindowController.shared.show() }

    @MainActor
    @objc private func openFeedback() {
        openSettings()
        NotificationCenter.default.post(name: .init("OpenTangerineShowAbout"), object: nil)
    }

    @objc private func fileActions() {
        pickFiles { [weak self] urls in self?.radial.presentPicker(for: urls, actions: true) }
    }

    @objc private func openTool() {
        pickFiles { [weak self] urls in self?.radial.presentPicker(for: urls, advanced: true) }
    }

    private func pickFiles(_ completion: @escaping ([URL]) -> Void) {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        NSApp.activate(ignoringOtherApps: true)
        panel.begin { response in
            guard response == .OK, !panel.urls.isEmpty else { return }
            completion(panel.urls)
        }
    }

    @MainActor
    static func makeSettingsWindow() -> NSWindow {
        let model = SettingsTabModel()
        let view = SettingsView(model: model).environmentObject(AppSettings.shared)
        let controller = NSHostingController(rootView: view)
        controller.sizingOptions = []
        let window = SettingsWindow(contentViewController: controller)
        window.title = "Citrus Settings"
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true
        window.isReleasedWhenClosed = false
        window.setContentSize(NSSize(width: SettingsView.width, height: SettingsView.height))
        window.center()
        return window
    }

    @MainActor
    @objc private func openSettings() {
        if settingsWindow == nil {
            settingsWindow = Self.makeSettingsWindow()
        }
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }

    @objc private func showLogs() {
        DiagnosticLog.flush()
        NSWorkspace.shared.activateFileViewerSelecting([DiagnosticLog.logFile])
    }

    @MainActor
    @objc private func about() {
        openSettings()
        // The About tab includes attribution and the creator link.
        NotificationCenter.default.post(name: .init("OpenTangerineShowAbout"), object: nil)
    }
}
