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

enum AccentChoice: String, CaseIterable, Identifiable {
    case citrus, blue, green, purple, pink, graphite, system

    var id: String { rawValue }

    var title: String {
        switch self {
        case .citrus: return L10n.t("Citrus Orange")
        case .blue: return L10n.t("Blue")
        case .green: return L10n.t("Green")
        case .purple: return L10n.t("Purple")
        case .pink: return L10n.t("Pink")
        case .graphite: return L10n.t("Graphite")
        case .system: return L10n.t("System accent")
        }
    }

    var color: NSColor? {
        switch self {
        case .citrus: return NSColor(srgbRed: 1.0, green: 0.36, blue: 0.0, alpha: 1)
        case .blue: return NSColor(srgbRed: 0.24, green: 0.53, blue: 0.96, alpha: 1)
        case .green: return NSColor(srgbRed: 0.20, green: 0.68, blue: 0.40, alpha: 1)
        case .purple: return NSColor(srgbRed: 0.58, green: 0.39, blue: 0.94, alpha: 1)
        case .pink: return NSColor(srgbRed: 0.94, green: 0.36, blue: 0.58, alpha: 1)
        case .graphite: return NSColor(srgbRed: 0.42, green: 0.45, blue: 0.50, alpha: 1)
        case .system: return nil
        }
    }
}

enum SoundChoice: String, CaseIterable, Identifiable {
    case glass, pop, tink, none

    var id: String { rawValue }

    var title: String {
        switch self {
        case .glass: return L10n.t("Glass")
        case .pop: return L10n.t("Pop")
        case .tink: return L10n.t("Tink")
        case .none: return L10n.t("None")
        }
    }

    var soundName: String? {
        switch self {
        case .glass: return "Glass"
        case .pop: return "Pop"
        case .tink: return "Tink"
        case .none: return nil
        }
    }
}

enum WheelSize: String, CaseIterable, Identifiable {
    case compact, standard, large

    var id: String { rawValue }

    var title: String {
        switch self {
        case .compact: return L10n.t("Compact")
        case .standard: return L10n.t("Standard")
        case .large: return L10n.t("Large")
        }
    }

    var scale: CGFloat {
        switch self {
        case .compact: return 0.85
        case .standard: return 1.0
        case .large: return 1.15
        }
    }
}

enum WheelSurface: String, CaseIterable, Identifiable {
    case glass, solid

    var id: String { rawValue }

    var title: String {
        switch self {
        case .glass: return L10n.t("Glass")
        case .solid: return L10n.t("Solid")
        }
    }
}

enum MotionChoice: String, CaseIterable, Identifiable {
    case system, reduced, full

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: return L10n.t("Follow system")
        case .reduced: return L10n.t("Reduced")
        case .full: return L10n.t("Full")
        }
    }
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

    @Published var accentChoice: AccentChoice {
        didSet { defaults.set(accentChoice.rawValue, forKey: "accentChoice") }
    }

    @Published var menuBarIconStyle: MenuBarIconStyle {
        didSet { defaults.set(menuBarIconStyle.rawValue, forKey: "menuBarIconStyle") }
    }

    @Published var soundChoice: SoundChoice {
        didSet { defaults.set(soundChoice.rawValue, forKey: "soundChoice") }
    }

    @Published var outputNameTemplate: String {
        didSet { defaults.set(outputNameTemplate, forKey: "outputNameTemplate") }
    }

    @Published var imageQualityOverrides: [String: Double] {
        didSet { defaults.set(imageQualityOverrides, forKey: "imageQualityOverrides") }
    }

    @Published var wheelSize: WheelSize {
        didSet { defaults.set(wheelSize.rawValue, forKey: "wheelSize") }
    }

    @Published var wheelSurface: WheelSurface {
        didSet { defaults.set(wheelSurface.rawValue, forKey: "wheelSurface") }
    }

    @Published var wheelOpacity: Double {
        didSet { defaults.set(wheelOpacity, forKey: "wheelOpacity") }
    }

    @Published var motionChoice: MotionChoice {
        didSet { defaults.set(motionChoice.rawValue, forKey: "motionChoice") }
    }

    @Published var toolOrder: [String] {
        didSet { defaults.set(toolOrder, forKey: "toolOrder") }
    }

    @Published var hiddenTools: [String] {
        didSet { defaults.set(hiddenTools, forKey: "hiddenTools") }
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
        accentChoice = AccentChoice(rawValue: defaults.string(forKey: "accentChoice") ?? "") ?? .citrus
        menuBarIconStyle = MenuBarIconStyle(rawValue: defaults.string(forKey: "menuBarIconStyle") ?? "") ?? .citrus
        soundChoice = SoundChoice(rawValue: defaults.string(forKey: "soundChoice") ?? "") ?? .glass
        outputNameTemplate = defaults.string(forKey: "outputNameTemplate") ?? "{name} {tool}"
        if let raw = defaults.dictionary(forKey: "imageQualityOverrides") {
            imageQualityOverrides = raw.compactMapValues { ($0 as? NSNumber)?.doubleValue }
        } else {
            imageQualityOverrides = [:]
        }
        wheelSize = WheelSize(rawValue: defaults.string(forKey: "wheelSize") ?? "") ?? .standard
        wheelSurface = WheelSurface(rawValue: defaults.string(forKey: "wheelSurface") ?? "") ?? .glass
        wheelOpacity = defaults.object(forKey: "wheelOpacity") as? Double ?? 1.0
        motionChoice = MotionChoice(rawValue: defaults.string(forKey: "motionChoice") ?? "") ?? .system
        toolOrder = defaults.stringArray(forKey: "toolOrder") ?? []
        hiddenTools = defaults.stringArray(forKey: "hiddenTools") ?? []
        if #available(macOS 13.0, *) {
            launchAtLogin = SMAppService.mainApp.status == .enabled
        } else {
            launchAtLogin = false
        }
    }

    /// Effective accent colour; `system` follows the macOS accent.
    var accentNSColor: NSColor { accentChoice.color ?? NSColor.controlAccentColor }

    /// Quality for a target format: per-format override, otherwise the global quality.
    func quality(for format: FileFormat) -> Double {
        imageQualityOverrides[format.rawValue] ?? jpegQuality
    }

    func setQuality(_ value: Double?, for format: FileFormat) {
        var copy = imageQualityOverrides
        copy[format.rawValue] = value
        imageQualityOverrides = copy
    }

    func resetOutputNameTemplate() {
        outputNameTemplate = "{name} {tool}"
    }

    // MARK: Tool order and visibility

    /// All tools in the user's order, including hidden ones.
    var allToolsInOrder: [ToolID] {
        let rank = Dictionary(uniqueKeysWithValues: toolOrder.enumerated().map { ($1, $0) })
        return ToolID.allCases.sorted {
            (rank[$0.rawValue] ?? Int.max) < (rank[$1.rawValue] ?? Int.max)
        }
    }

    /// Tools to show on the wheel: hidden ones removed, then user order applied.
    func orderedTools(_ tools: [ToolID]) -> [ToolID] {
        let visible = Set(tools.map(\.rawValue)).subtracting(hiddenTools)
        let rank = Dictionary(uniqueKeysWithValues: toolOrder.enumerated().map { ($1, $0) })
        return tools.filter { visible.contains($0.rawValue) }.sorted {
            (rank[$0.rawValue] ?? Int.max) < (rank[$1.rawValue] ?? Int.max)
        }
    }

    func isToolHidden(_ tool: ToolID) -> Bool {
        hiddenTools.contains(tool.rawValue)
    }

    func toggleToolHidden(_ tool: ToolID) {
        if isToolHidden(tool) {
            hiddenTools.removeAll { $0 == tool.rawValue }
        } else {
            hiddenTools.append(tool.rawValue)
        }
    }

    func moveTool(_ tool: ToolID, offset: Int) {
        var order = allToolsInOrder.map(\.rawValue)
        guard let index = order.firstIndex(of: tool.rawValue) else { return }
        let target = index + offset
        guard order.indices.contains(target) else { return }
        order.swapAt(index, target)
        toolOrder = order
    }

    func resetToolLayout() {
        toolOrder = []
        hiddenTools = []
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

