import AppKit
import Foundation
import Combine
import ServiceManagement

enum CompressionPreset: String, CaseIterable, Identifiable {
    case balanced
    case strong

    var id: String { rawValue }

    var title: String { L10n.t(rawValue.capitalized) }

    var imageQuality: Double { self == .balanced ? 0.72 : 0.5 }
    var videoScale: Double { self == .balanced ? 1.0 : 0.75 }
    var videoBitrateFactor: Double { self == .balanced ? 0.6 : 0.35 }
    var audioBitrate: Int { self == .balanced ? 128_000 : 64_000 }
}

enum OutputLocation: String, CaseIterable, Identifiable {
    case besideOriginal
    case downloads
    case desktop

    var id: String { rawValue }

    var title: String {
        switch self {
        case .besideOriginal: return L10n.t("Next to the original")
        case .downloads: return L10n.t("Downloads")
        case .desktop: return L10n.t("Desktop")
        }
    }

    func directory(for source: URL) -> URL {
        switch self {
        case .besideOriginal: return source.deletingLastPathComponent()
        case .downloads: return FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask)[0]
        case .desktop: return FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask)[0]
        }
    }
}

enum AppearanceMode: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: return L10n.t("System")
        case .light: return L10n.t("Light")
        case .dark: return L10n.t("Dark")
        }
    }

    var appearance: NSAppearance? {
        switch self {
        case .system: return nil
        case .light: return NSAppearance(named: .aqua)
        case .dark: return NSAppearance(named: .darkAqua)
        }
    }
}

enum ProgressStyle: String, CaseIterable, Identifiable {
    case card
    case pill

    var id: String { rawValue }

    var title: String {
        switch self {
        case .card: return L10n.t("Card")
        case .pill: return L10n.t("Notch pill")
        }
    }
}

enum NotchSurface: String, CaseIterable, Identifiable {
    case black, glass
    var id: String { rawValue }
    var title: String { self == .black ? L10n.t("Pure black") : L10n.t("Glass") }
}

enum DragModifier: String, CaseIterable, Identifiable {
    case shift, command, control, option

    var id: String { rawValue }

    var title: String {
        switch self {
        case .shift: return "Shift (⇧)"
        case .command: return "Command (⌘)"
        case .control: return "Control (⌃)"
        case .option: return "Option (⌥)"
        }
    }

    var flag: NSEvent.ModifierFlags {
        switch self {
        case .shift: return .shift
        case .command: return .command
        case .control: return .control
        case .option: return .option
        }
    }
}

enum WheelKind {
    case conversions, tools, actions
}

enum FloatBehaviour: String, CaseIterable, Identifiable {
    case newShelf, addToExisting

    var id: String { rawValue }

    var title: String {
        switch self {
        case .newShelf: return L10n.t("Create a new Float")
        case .addToExisting: return L10n.t("Add to the current Float")
        }
    }
}

enum TerminalApplication: String, CaseIterable, Identifiable {
    case terminal, iTerm2, systemDefault

    var id: String { rawValue }

    var title: String {
        switch self {
        case .terminal: return L10n.t("Terminal")
        case .iTerm2: return "iTerm2"
        case .systemDefault: return L10n.t("System default")
        }
    }

    var applicationURL: URL? {
        switch self {
        case .terminal: return URL(fileURLWithPath: "/System/Applications/Utilities/Terminal.app")
        case .iTerm2: return URL(fileURLWithPath: "/Applications/iTerm.app")
        case .systemDefault: return nil
        }
    }
}

final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    private let defaults = UserDefaults.standard

    @Published var excludedApplications: [String: String] {
        didSet { defaults.set(excludedApplications, forKey: "excludedApplications") }
    }

    @Published var compressionPreset: CompressionPreset {
        didSet { defaults.set(compressionPreset.rawValue, forKey: "compressionPreset") }
    }

    @Published var compressionResizeLongEdge: Int {
        didSet { defaults.set(compressionResizeLongEdge, forKey: "compressionResizeLongEdge") }
    }

    @Published var outputLocation: OutputLocation {
        didSet { defaults.set(outputLocation.rawValue, forKey: "outputLocation") }
    }

    @Published var revealInFinder: Bool {
        didSet { defaults.set(revealInFinder, forKey: "revealInFinder") }
    }

    @Published var notchSurface: NotchSurface {
        didSet { defaults.set(notchSurface.rawValue, forKey: "notchSurface") }
    }

    @Published var progressStyle: ProgressStyle {
        didSet { defaults.set(progressStyle.rawValue, forKey: "progressStyle") }
    }

    @Published var ffmpegPath: String {
        didSet { defaults.set(ffmpegPath, forKey: "ffmpegPath") }
    }

    @Published var officeEnginePath: String {
        didSet { defaults.set(officeEnginePath, forKey: "officeEnginePath") }
    }

    @Published var launchAtLogin: Bool {
        didSet { if !refreshingLoginStatus { applyLaunchAtLogin() } }
    }

    @Published var loginMessage: String?
    private var refreshingLoginStatus = false

    @Published var jpegQuality: Double {
        didSet { defaults.set(jpegQuality, forKey: "jpegQuality") }
    }

    @Published var appearanceMode: AppearanceMode {
        didSet {
            defaults.set(appearanceMode.rawValue, forKey: "appearanceMode")
            applyAppearance()
        }
    }

    @Published var convertModifier: DragModifier {
        didSet { defaults.set(convertModifier.rawValue, forKey: "convertModifier") }
    }

    @Published var toolsModifier: DragModifier {
        didSet { defaults.set(toolsModifier.rawValue, forKey: "toolsModifier") }
    }

    @Published var actionsModifier: DragModifier {
        didSet { defaults.set(actionsModifier.rawValue, forKey: "actionsModifier") }
    }

    @Published var terminalApplication: TerminalApplication {
        didSet { defaults.set(terminalApplication.rawValue, forKey: "terminalApplication") }
    }

    @Published var preserveMetadata: Bool {
        didSet { defaults.set(preserveMetadata, forKey: "preserveMetadata") }
    }

    @Published var soundAndHaptics: Bool {
        didSet { defaults.set(soundAndHaptics, forKey: "soundAndHaptics") }
    }

    @Published var floatBehaviour: FloatBehaviour {
        didSet { defaults.set(floatBehaviour.rawValue, forKey: "floatBehaviour") }
    }

    @Published var language: AppLanguage {
        didSet { defaults.set(language.rawValue, forKey: "appLanguage") }
    }

    private init() {
        excludedApplications = defaults.dictionary(forKey: "excludedApplications") as? [String: String] ?? [:]
        compressionPreset = CompressionPreset(rawValue: defaults.string(forKey: "compressionPreset") ?? "") ?? .balanced
        compressionResizeLongEdge = defaults.integer(forKey: "compressionResizeLongEdge")
        outputLocation = OutputLocation(rawValue: defaults.string(forKey: "outputLocation") ?? "") ?? .besideOriginal
        revealInFinder = defaults.object(forKey: "revealInFinder") as? Bool ?? true
        notchSurface = NotchSurface(rawValue: defaults.string(forKey: "notchSurface") ?? "") ?? .black
        progressStyle = ProgressStyle(rawValue: defaults.string(forKey: "progressStyle") ?? "") ?? .pill
        // One-time migration requested for existing trial installs; future user choices persist.
        if !defaults.bool(forKey: "notchDefaultV012") {
            progressStyle = .pill
            defaults.set("pill", forKey: "progressStyle")
            defaults.set(true, forKey: "notchDefaultV012")
        }
        ffmpegPath = defaults.string(forKey: "ffmpegPath") ?? ""
        officeEnginePath = defaults.string(forKey: "officeEnginePath") ?? ""
        jpegQuality = defaults.object(forKey: "jpegQuality") as? Double ?? 0.9
        appearanceMode = AppearanceMode(rawValue: defaults.string(forKey: "appearanceMode") ?? "") ?? .system
        convertModifier = DragModifier(rawValue: defaults.string(forKey: "convertModifier") ?? "") ?? .shift
        toolsModifier = DragModifier(rawValue: defaults.string(forKey: "toolsModifier") ?? "") ?? .command
        actionsModifier = DragModifier(rawValue: defaults.string(forKey: "actionsModifier") ?? "") ?? .control
        terminalApplication = TerminalApplication(rawValue: defaults.string(forKey: "terminalApplication") ?? "") ?? .terminal
        preserveMetadata = defaults.object(forKey: "preserveMetadata") as? Bool ?? true
        soundAndHaptics = defaults.object(forKey: "soundAndHaptics") as? Bool ?? true
        floatBehaviour = FloatBehaviour(rawValue: defaults.string(forKey: "floatBehaviour") ?? "") ?? .newShelf
        language = AppLanguage(rawValue: defaults.string(forKey: "appLanguage") ?? "") ?? .system
        if #available(macOS 13.0, *) {
            launchAtLogin = SMAppService.mainApp.status == .enabled
        } else {
            launchAtLogin = false
        }
    }

    func applyAppearance() {
        NSApp.appearance = appearanceMode.appearance
    }

    func refreshLoginStatus(preserveError: Bool = false) {
        refreshingLoginStatus = true
        defer { refreshingLoginStatus = false }
        let status = SMAppService.mainApp.status
        launchAtLogin = status == .enabled || status == .requiresApproval
        if !preserveError {
            loginMessage = status == .requiresApproval
                ? "Allow Citrus in System Settings → General → Login Items."
                : nil
        }
    }

    func openLoginSettings() { SMAppService.openSystemSettingsLoginItems() }

    private func applyLaunchAtLogin() {
        guard #available(macOS 13.0, *) else { return }
        do {
            if launchAtLogin {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            refreshLoginStatus()
        } catch {
            loginMessage = "Could not update automatic startup: \(error.localizedDescription)"
            refreshLoginStatus(preserveError: true)
        }
    }
}

