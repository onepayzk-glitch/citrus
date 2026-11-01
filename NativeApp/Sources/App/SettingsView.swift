import AppKit
import SwiftUI
import UniformTypeIdentifiers

enum SettingsTab: String, CaseIterable, Identifiable {
    case general
    case appearance
    case conversion
    case compatibility
    case about

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: return L10n.t("General")
        case .appearance: return L10n.t("Appearance")
        case .conversion: return L10n.t("Formats")
        case .compatibility: return L10n.t("Compatibility")
        case .about: return L10n.t("About")
        }
    }

    var symbol: String {
        switch self {
        case .general: return "gearshape"
        case .appearance: return "paintbrush"
        case .conversion: return "arrow.triangle.2.circlepath"
        case .compatibility: return "tablecells"
        case .about: return "info.circle"
        }
    }
}

@MainActor
final class SettingsTabModel: ObservableObject {
    @Published var tab: SettingsTab = .general
}

struct SettingsView: View {
    @EnvironmentObject private var settings: AppSettings
    @ObservedObject var model: SettingsTabModel
    @State private var ffmpegHealth: FFmpeg.Health = .missing
    @State private var officeHealth: OfficeEngine.Health = .missing
    @State private var formatSelection: FileFormat = .jpg

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Namespace private var selection

    static let width: CGFloat = 820
    static let height: CGFloat = 620

    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 26) {
                HStack(spacing: 10) {
                    Image(nsImage: BrandArtwork.image(size: 40)).resizable().frame(width: 40, height: 40)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Open").font(.system(size: 15, weight: .medium))
                        Text("Tangerine").font(.system(size: 18, weight: .bold))
                    }
                }
                .padding(.top, 20)
                VStack(spacing: 6) {
                    ForEach(SettingsTab.allCases) { tab in
                        Button {
                            withAnimation(reduceMotion ? .easeOut(duration: 0.15) : .spring(response: 0.38, dampingFraction: 0.85)) {
                                model.tab = tab
                            }
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: tab.symbol).font(.system(size: 16, weight: .medium)).frame(width: 22)
                                Text(tab.title).font(.system(size: 14, weight: model.tab == tab ? .semibold : .medium))
                                Spacer()
                            }
                            .padding(.horizontal, 14).padding(.vertical, 13)
                            .foregroundStyle(model.tab == tab ? Color.white : Color.primary)
                            .background {
                                if model.tab == tab {
                                    RoundedRectangle(cornerRadius: 13)
                                        .fill(Theme.accent.gradient)
                                        .matchedGeometryEffect(id: "sidebar", in: selection)
                                }
                            }
                            .contentShape(RoundedRectangle(cornerRadius: 13))
                        }
                        .buttonStyle(SettingsPressStyle())
                        .accessibilityAddTraits(model.tab == tab ? .isSelected : [])
                    }
                }
                Spacer()
                VStack(alignment: .leading, spacing: 8) {
                    Label(L10n.t("On your Mac"), systemImage: "lock.shield")
                        .font(.system(size: 12, weight: .semibold))
                    Text(L10n.t("Your files. Your workflow."))
                        .font(.caption).foregroundStyle(.secondary)
                    Text("OPEN SOURCE  /  \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Development")")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .tracking(1.2).foregroundStyle(.tertiary)
                }
                .padding(.bottom, 12)
            }
            .padding(20).frame(width: 205)
            .background(reduceTransparency ? Color(nsColor: .windowBackgroundColor) : Color(nsColor: .controlBackgroundColor).opacity(0.65))
            Divider()
            VStack(spacing: 0) {
                HStack(alignment: .center, spacing: 12) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(L10n.t("MAKE ROOM FOR FLOW"))
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .tracking(2).foregroundStyle(Theme.accent)
                        Text(model.tab.title)
                            .font(.system(size: 34, weight: .bold, design: .rounded))
                            .contentTransition(.numericText())
                        Text(tabDescription)
                            .font(.system(size: 13)).foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                    FileOrbitGraphic(tab: model.tab)
                        .frame(width: 155, height: 145)
                        .accessibilityHidden(true)
                }
                .padding(.horizontal, 30).padding(.top, 12).padding(.bottom, 4)
                ZStack {
                    Form {
                        switch model.tab {
                        case .general: general
                        case .appearance: appearance
                        case .conversion: conversion
                        case .compatibility: compatibility
                        case .about: about
                        }
                    }
                    .formStyle(.grouped)
                    .scrollContentBackground(.hidden)
                    .id(model.tab)
                    .transition(reduceMotion ? .opacity : .opacity.combined(with: .offset(y: 9)))
                }
                .animation(reduceMotion ? .easeOut(duration: 0.15) : .smooth(duration: 0.28), value: model.tab)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background {
                LinearGradient(colors: [Theme.accent.opacity(0.06), Color(nsColor: .windowBackgroundColor), Color(nsColor: .windowBackgroundColor)], startPoint: .topTrailing, endPoint: .bottomLeading)
            }
        }
        .frame(width: Self.width, height: Self.height)
        .tint(Theme.accent)
        .onReceive(NotificationCenter.default.publisher(for: .init("OpenTangerineShowAbout"))) { _ in model.tab = .about }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in settings.refreshLoginStatus() }
        .task(id: settings.ffmpegPath) { ffmpegHealth = await FFmpeg.checkHealth() }
        .task(id: settings.officeEnginePath) { officeHealth = await OfficeEngine.checkHealth() }
    }

    private var tabDescription: String {
        switch model.tab {
        case .general: return L10n.t("A few thoughtful defaults. A smoother day.")
        case .appearance: return L10n.t("Make your workspace feel like yours.")
        case .conversion: return L10n.t("Find the balance between detail and size.")
        case .compatibility: return L10n.t("Every source. Every output. At a glance.")
        case .about: return L10n.t("Small utility. Open possibilities.")
        }
    }

    @ViewBuilder private var general: some View {
        Section(L10n.t("Output")) {
            Picker(L10n.t("Save converted files"), selection: $settings.outputLocation) {
                ForEach(OutputLocation.allCases) { Text($0.title).tag($0) }
            }
            Toggle(L10n.t("Reveal results in Finder"), isOn: $settings.revealInFinder)
        }
        Section(L10n.t("General")) {
            Toggle(L10n.t("Start automatically at login"), isOn: $settings.launchAtLogin)
            Toggle(L10n.t("Sound and haptic feedback"), isOn: $settings.soundAndHaptics)
            Picker(L10n.t("Float behaviour"), selection: $settings.floatBehaviour) {
                ForEach(FloatBehaviour.allCases) { Text($0.title).tag($0) }
            }
            Picker(L10n.t("Language"), selection: $settings.language) {
                ForEach(AppLanguage.allCases) { Text($0.title).tag($0) }
            }
            Text(L10n.t("Restart the app to apply menu and guide language changes."))
                .font(.caption).foregroundStyle(.secondary)
            Text(L10n.t("Keep Open Tangerine ready in the menu bar after you restart and sign in. Move the app to Applications before enabling."))
                .font(.caption).foregroundStyle(.secondary)
            if let message = settings.loginMessage {
                Text(message).font(.caption).foregroundStyle(.orange)
                Button(L10n.t("Open Login Items…")) { settings.openLoginSettings() }
            }
        }
        Section {
            Picker(L10n.t("Conversion wheel"), selection: modifierBinding(.conversions)) {
                ForEach(DragModifier.allCases) { Text($0.title).tag($0) }
            }
            Picker(L10n.t("Tools wheel"), selection: modifierBinding(.tools)) {
                ForEach(DragModifier.allCases) { Text($0.title).tag($0) }
            }
            Picker(L10n.t("File actions"), selection: modifierBinding(.actions)) {
                ForEach(DragModifier.allCases) { Text($0.title).tag($0) }
            }
            Picker(L10n.t("Terminal app"), selection: $settings.terminalApplication) {
                ForEach(TerminalApplication.allCases) { Text($0.title).tag($0) }
            }
        } header: {
            Text(L10n.t("Drag Modifiers"))
        } footer: {
            Text(L10n.t("Hold the chosen modifier while dragging files in Finder. Tangerine's defaults are ⇧ Shift, ⌘ Command and ⌃ Control. Picking a key that another wheel already uses swaps the two."))
        }
        Section(L10n.t("Excluded applications")) {
            Text(L10n.t("Drag shortcuts stay off when a drag starts in these apps. Add CorelDRAW or other design tools here. You can still use Convert Files from the menu bar."))
                .font(.caption).foregroundStyle(.secondary)
            ForEach(settings.excludedApplications.keys.sorted(), id: \.self) { identifier in
                HStack {
                    Text(settings.excludedApplications[identifier] ?? identifier)
                    Spacer()
                    Button(L10n.t("Remove"), systemImage: "minus.circle") {
                        settings.excludedApplications.removeValue(forKey: identifier)
                    }.help("Enable drag shortcuts in this application")
                }
            }
            Button(L10n.t("Add Application…"), systemImage: "plus.circle", action: addExcludedApplication)
        }
    }

    private func addExcludedApplication() {
        let panel = NSOpenPanel()
        panel.title = "Disable drag shortcuts in applications"
        panel.allowedContentTypes = [.applicationBundle]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.begin { response in
            guard response == .OK else { return }
            for url in panel.urls {
                guard let bundle = Bundle(url: url), let identifier = bundle.bundleIdentifier else { continue }
                settings.excludedApplications[identifier] =
                    (bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
                    ?? (bundle.object(forInfoDictionaryKey: "CFBundleName") as? String)
                    ?? url.deletingPathExtension().lastPathComponent
            }
        }
    }

    @ViewBuilder private var appearance: some View {
        Section(L10n.t("Theme")) {
            Picker(L10n.t("Theme"), selection: $settings.appearanceMode) {
                ForEach(AppearanceMode.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
        }
        Section {
            Picker(L10n.t("Progress"), selection: $settings.progressStyle) {
                ForEach(ProgressStyle.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            if settings.progressStyle == .pill {
                Picker(L10n.t("Notch surface"), selection: $settings.notchSurface) {
                    ForEach(NotchSurface.allCases) { Text($0.title).tag($0) }
                }.pickerStyle(.segmented)
            }
        } header: {
            Text(L10n.t("Progress"))
        } footer: {
            Text(settings.progressStyle == .card
                 ? "A floating card in the top right corner with the file name and percentage."
                 : "An animated citrus companion below the notch, with file progress and results.")
        }
    }

    @ViewBuilder private var conversion: some View {
        formatSettingsSection
        Section(L10n.t("Images")) {
            HStack {
                Text(L10n.t("JPEG / HEIC / WebP quality"))
                Slider(value: $settings.jpegQuality, in: 0.3...1.0)
                Text("\(Int(settings.jpegQuality * 100))%").contentTransition(.numericText()).monospacedDigit().frame(width: 44, alignment: .trailing)
            }
        }
        Section {
            Picker(L10n.t("Preset"), selection: $settings.compressionPreset) {
                ForEach(CompressionPreset.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            HStack {
                Text(L10n.t("Resize long edge to"))
                TextField(L10n.t("Off"), value: $settings.compressionResizeLongEdge, format: .number)
                    .labelsHidden()
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 80)
                Text(L10n.t("px (0 = keep size)")).foregroundStyle(.secondary)
            }
        } header: {
            Text(L10n.t("Compression"))
        } footer: {
            Text(settings.compressionPreset == .balanced
                 ? "Balanced keeps detail while trimming size noticeably."
                 : "Strong prioritizes the smallest file, with visible quality loss.")
        }
        Section {
            Toggle(L10n.t("Preserve metadata in conversions"), isOn: $settings.preserveMetadata)
        } header: {
            Text(L10n.t("Metadata"))
        } footer: {
            Text(settings.preserveMetadata
                 ? "Image conversions keep the original camera, GPS and processing tags."
                 : "Image conversions write clean files without camera, GPS or processing tags.")
        }
        officeEngineSection
        Section {
            HStack {
                TextField(L10n.t("Auto-detect (Homebrew, MacPorts, /usr/local/bin)"), text: $settings.ffmpegPath)
                    .textFieldStyle(.roundedBorder)
                Button(L10n.t("Choose…")) { chooseFFmpeg() }
            }
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Image(systemName: ffmpegHealthSymbol)
                    .foregroundStyle(ffmpegHealthColor)
                Text(ffmpegHealthText)
                    .font(.caption)
                    .textSelection(.enabled)
            }
        } header: {
            Text(L10n.t("FFmpeg (optional)"))
        } footer: {
            Text(L10n.t("Open Tangerine uses Apple frameworks for most work. FFmpeg fills the gaps: MP3, FLAC, OGG, Opus, WMA, MKV, WebM, AVI, WMV, GIF and AVIF/WebP encoding on older systems."))
        }
    }

    @ViewBuilder private var officeEngineSection: some View {
        Section {
            HStack {
                TextField(L10n.t("Auto-detect (LibreOffice.app, Homebrew soffice)"), text: $settings.officeEnginePath)
                    .textFieldStyle(.roundedBorder)
                Button(L10n.t("Choose…")) { chooseOfficeEngine() }
            }
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Image(systemName: officeHealthSymbol)
                    .foregroundStyle(officeHealthColor)
                Text(officeHealthText)
                    .font(.caption)
                    .textSelection(.enabled)
            }
        } header: {
            Text(L10n.t("Office engine (optional)"))
        } footer: {
            Text(L10n.t("Detects an installed LibreOffice for high-fidelity DOCX/PPTX/XLSX/ODS → PDF, PNG and JPG. Nothing is downloaded or bundled; when it is missing, Office conversions fall back to the built-in text engine."))
        }
    }

    private var formatInputs: [FileFormat] {
        FileFormat.allCases.filter { !ConversionMatrix.targets(for: $0).isEmpty }
    }

    private var formatTargets: [FileFormat] {
        ConversionMatrix.targets(for: formatSelection)
    }

    @ViewBuilder private var formatSettingsSection: some View {
        Section {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 62), spacing: 6)], alignment: .leading, spacing: 6) {
                ForEach(formatInputs) { format in
                    Button {
                        formatSelection = format
                    } label: {
                        Text(format.displayName)
                            .font(.system(size: 10, weight: formatSelection == format ? .semibold : .regular, design: .monospaced))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 5)
                            .padding(.horizontal, 4)
                            .foregroundStyle(formatSelection == format ? Color.white : Color.primary)
                            .background(Capsule().fill(formatSelection == format ? Theme.accent : Color.secondary.opacity(0.14)))
                    }
                    .buttonStyle(.plain)
                    .help("\(format.displayName): \(ConversionMatrix.targets(for: format).count) outputs")
                }
            }
            .padding(.vertical, 4)

            VStack(alignment: .leading, spacing: 4) {
                Text(L10n.format("%@ → %d outputs", formatSelection.displayName, formatTargets.count))
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                Text(formatTargets.map(\.displayName).joined(separator: "  ·  "))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if formatSelection.category == .image {
                HStack {
                    Text(L10n.t("Image quality"))
                    Slider(value: $settings.jpegQuality, in: 0.3...1.0)
                    Text("\(Int(settings.jpegQuality * 100))%")
                        .font(.caption.monospacedDigit())
                        .frame(width: 40, alignment: .trailing)
                }
                Toggle(L10n.t("Preserve metadata when converting"), isOn: $settings.preserveMetadata)
            } else if formatSelection.category == .video || formatSelection.category == .audio {
                Picker(L10n.t("Compression preset"), selection: $settings.compressionPreset) {
                    ForEach(CompressionPreset.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
            } else if formatSelection.category == .document {
                HStack(spacing: 6) {
                    Image(systemName: OfficeEngine.isAvailable ? "checkmark.circle.fill" : "info.circle")
                        .foregroundStyle(OfficeEngine.isAvailable ? .green : .secondary)
                    Text(OfficeEngine.binary.map { "Office fidelity via detected \((($0 as NSString).lastPathComponent))" }
                         ?? "No LibreOffice detected — documents use the built-in text engine")
                        .font(.caption)
                }
            }

            HStack {
                Button(L10n.t("Restore Defaults")) { restoreFormatDefaults() }
                Button(L10n.t("Restore Compression Defaults")) {
                    settings.compressionPreset = .balanced
                    settings.compressionResizeLongEdge = 0
                }
            }
        } header: {
            Text(L10n.t("Format settings"))
        } footer: {
            Text(L10n.t("Pick a source format to see every output and the settings that affect it. The conversion wheel uses this same matrix."))
        }
    }

    private func restoreFormatDefaults() {
        settings.jpegQuality = 0.9
        settings.compressionPreset = .balanced
        settings.compressionResizeLongEdge = 0
        settings.preserveMetadata = true
    }

    @ViewBuilder private var compatibility: some View {
        Section {
            Text("Every supported source format and the outputs the conversion wheel offers. \(ConversionMatrix.totalConversions) routes in total.")
                .font(.caption).foregroundStyle(.secondary)
            ForEach(FileFormat.allCases) { source in
                let targets = ConversionMatrix.targets(for: source)
                if !targets.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Text(source.displayName)
                                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                            Spacer()
                            Text("\(targets.count)")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                        Text(targets.map(\.displayName).joined(separator: "  ·  "))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.vertical, 2)
                }
            }
        } header: {
            Text(L10n.t("Conversion compatibility"))
        }
    }

    private func modifierBinding(_ wheel: WheelKind) -> Binding<DragModifier> {
        Binding(
            get: {
                switch wheel {
                case .conversions: return settings.convertModifier
                case .tools: return settings.toolsModifier
                case .actions: return settings.actionsModifier
                }
            },
            set: { newValue in
                let old: DragModifier
                switch wheel {
                case .conversions: old = settings.convertModifier
                case .tools: old = settings.toolsModifier
                case .actions: old = settings.actionsModifier
                }
                guard newValue != old else { return }
                switch wheel {
                case .conversions: break
                case .tools: if settings.convertModifier == newValue { settings.convertModifier = old }
                case .actions: break
                }
                if wheel != .conversions, settings.convertModifier == newValue { settings.convertModifier = old }
                if wheel != .tools, settings.toolsModifier == newValue { settings.toolsModifier = old }
                if wheel != .actions, settings.actionsModifier == newValue { settings.actionsModifier = old }
                switch wheel {
                case .conversions: settings.convertModifier = newValue
                case .tools: settings.toolsModifier = newValue
                case .actions: settings.actionsModifier = newValue
                }
            }
        )
    }

    @ViewBuilder private var about: some View {
        Section {
            VStack(spacing: 16) {
                Image(nsImage: BrandArtwork.image(size: 100))
                    .resizable().frame(width: 84, height: 84)
                    .shadow(color: Theme.accent.opacity(0.18), radius: 12, y: 6)
                    .accessibilityLabel("Open Tangerine icon")
                VStack(spacing: 6) {
                    Text(L10n.t("Open Tangerine")).font(.system(size: 25, weight: .bold, design: .rounded))
                    Text(L10n.t("A little less friction. A little more flow."))
                        .font(.system(size: 13)).foregroundStyle(.secondary)
                }
                Text("VERSION \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Development")  ·  DEVELOPER TRIAL")
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .tracking(1.1).foregroundStyle(.secondary)
                Divider().padding(.horizontal, 30)
                VStack(spacing: 7) {
                    Text(L10n.t("Sintax Error Private Limited")).font(.system(size: 13, weight: .semibold))
                    Text(L10n.t("Free to use. Open to make better."))
                        .font(.caption).foregroundStyle(.secondary)
                }
                HStack(spacing: 5) {
                    Text(L10n.t("Made with"))
                    Image(systemName: "heart.fill").foregroundStyle(Theme.accent).accessibilityLabel("love")
                    Text(L10n.t("by"))
                    Link("Hemaangg", destination: URL(string: "https://www.instagram.com/hemaangg/")!)
                        .fontWeight(.semibold)
                        .help("Visit Hemaangg on Instagram")
                }
                .font(.system(size: 13))
                .padding(.top, 2)
                Text(L10n.t("GPL-3.0-only · Based on Satsuma by plyght (MIT).\nIndependent of Tangerine. Some features remain experimental."))
                    .font(.system(size: 10)).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center).lineSpacing(3)
            }
            .frame(maxWidth: .infinity).padding(.vertical, 20)
        }
    }

    private var ffmpegHealthSymbol: String {
        switch ffmpegHealth {
        case .ready: return "checkmark.circle.fill"
        case .broken: return "xmark.octagon.fill"
        case .missing: return "exclamationmark.triangle.fill"
        }
    }

    private var ffmpegHealthColor: Color {
        switch ffmpegHealth {
        case .ready: return .green
        case .broken: return .red
        case .missing: return .orange
        }
    }

    private var ffmpegHealthText: String {
        switch ffmpegHealth {
        case let .ready(path, version): return "Using ffmpeg \(version) at \(path)"
        case let .broken(path, reason): return "ffmpeg at \(path) cannot run: \(reason)"
        case .missing: return "FFmpeg not found. Install with `brew install ffmpeg` or pick the binary."
        }
    }

    private func chooseFFmpeg() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.showsHiddenFiles = true
        panel.directoryURL = URL(fileURLWithPath: "/opt/homebrew/bin")
        if panel.runModal() == .OK, let url = panel.url {
            settings.ffmpegPath = url.path
        }
    }

    private var officeHealthSymbol: String {
        switch officeHealth {
        case .ready: return "checkmark.circle.fill"
        case .broken: return "xmark.octagon.fill"
        case .missing: return "info.circle"
        }
    }

    private var officeHealthColor: Color {
        switch officeHealth {
        case .ready: return .green
        case .broken: return .orange
        case .missing: return .secondary
        }
    }

    private var officeHealthText: String { officeHealth.summary }

    private func chooseOfficeEngine() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.showsHiddenFiles = true
        panel.directoryURL = URL(fileURLWithPath: "/Applications/LibreOffice.app/Contents/MacOS")
        if panel.runModal() == .OK, let url = panel.url {
            settings.officeEnginePath = url.path
        }
    }
}

struct SettingsTabBar: View {
    @ObservedObject var model: SettingsTabModel
    @Namespace private var namespace

    var body: some View {
        GlassGroup {
            HStack(spacing: 2) {
                ForEach(SettingsTab.allCases) { tab in
                    Button {
                        model.tab = tab
                    } label: {
                        Label(tab.title, systemImage: tab.symbol)
                            .labelStyle(.titleOnly)
                            .font(.system(size: 13, weight: model.tab == tab ? .semibold : .regular))
                            .foregroundStyle(model.tab == tab ? Color.white : Color.primary)
                            .lineLimit(1)
                            .fixedSize()
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .background {
                        if model.tab == tab {
                            Color.clear
                                .glassSurface(tint: Theme.accent, interactive: true, in: Capsule())
                                .matchedGeometryEffect(id: "selection", in: namespace)
                        }
                    }
                }
            }
            .padding(3)
            .glassSurface(in: Capsule())
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.85), value: model.tab)
    }
}

final class SettingsWindow: NSWindow {
    var toolbarDelegate: SettingsToolbarDelegate?
}

@MainActor
final class SettingsToolbarDelegate: NSObject, NSToolbarDelegate {
    static let tabsItem = NSToolbarItem.Identifier("opentangerine.settings.tabs")
    let model: SettingsTabModel

    init(model: SettingsTabModel) {
        self.model = model
    }

    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [.flexibleSpace, Self.tabsItem, .flexibleSpace]
    }

    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        toolbarDefaultItemIdentifiers(toolbar)
    }

    func toolbar(
        _ toolbar: NSToolbar,
        itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier,
        willBeInsertedIntoToolbar flag: Bool
    ) -> NSToolbarItem? {
        guard itemIdentifier == Self.tabsItem else { return nil }
        let item = NSToolbarItem(itemIdentifier: itemIdentifier)
        let hosting = NSHostingView(rootView: SettingsTabBar(model: model))
        hosting.sizingOptions = [.intrinsicContentSize]
        item.view = hosting
        item.isBordered = false
        return item
    }
}

