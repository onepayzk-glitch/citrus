import AppKit
import Foundation

/// Use-time dependency prompt. The app never downloads or installs silently: it explains
/// what is missing and offers assisted installation (Terminal command or official page).
@MainActor
enum DependencyPrompt {
    enum Decision {
        case install
        case fallback
        case cancel
    }

    /// Dependencies the user chose to skip for the rest of this session.
    private static var sessionFallbacks: Set<ExternalDependency> = []

    static func alreadyAcceptedFallback(_ dependency: ExternalDependency) -> Bool {
        sessionFallbacks.contains(dependency)
    }

    static func acceptFallback(_ dependency: ExternalDependency) {
        sessionFallbacks.insert(dependency)
    }

    static func ask(_ dependency: ExternalDependency, allowFallback: Bool, context: String) -> Decision {
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = L10n.format("%@ is needed", dependency.title)
        alert.informativeText = context + "\n\n" + dependency.summary
        alert.addButton(withTitle: L10n.t("Help me install"))
        if allowFallback, let fallback = dependency.fallbackDescription {
            alert.addButton(withTitle: fallback)
            alert.addButton(withTitle: L10n.t("Cancel"))
        } else {
            alert.addButton(withTitle: L10n.t("Cancel"))
        }
        let response = alert.runModal()
        switch response {
        case .alertFirstButtonReturn:
            return .install
        case .alertSecondButtonReturn:
            if allowFallback, dependency.fallbackDescription != nil {
                acceptFallback(dependency)
                return .fallback
            }
            return .cancel
        default:
            return .cancel
        }
    }

    /// Assists installation without downloading anything in-app:
    /// - Homebrew present: copy the command, open Terminal for the user to paste and run.
    /// - Otherwise: open the official download page or the Mac App Store listing.
    static func helpInstall(_ dependency: ExternalDependency) {
        switch dependency {
        case .ffmpeg:
            if let brew = Shell.which("brew") {
                offerTerminalCommand("\(brew) install ffmpeg")
            } else {
                open("https://ffmpeg.org/download.html")
            }
        case .libreOffice:
            if let brew = Shell.which("brew") {
                offerTerminalCommand("\(brew) install --cask libreoffice")
            } else {
                open("https://www.libreoffice.org/download/download-libreoffice/")
            }
        case .pages:
            if !open("macappstore://apps.apple.com/cn/app/pages/id409201541?mt=12") {
                _ = open("https://apps.apple.com/cn/app/pages/id409201541?mt=12")
            }
        }
    }

    private static func offerTerminalCommand(_ command: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(command, forType: .string)
        let terminal = URL(fileURLWithPath: "/System/Applications/Utilities/Terminal.app")
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        NSWorkspace.shared.openApplication(at: terminal, configuration: configuration) { _, error in
            Task { @MainActor in
                let alert = NSAlert()
                alert.alertStyle = .informational
                alert.messageText = L10n.t("Install command copied")
                alert.informativeText = L10n.format("%@ has been copied to the clipboard. Paste it into Terminal and press Return. When the installation finishes, drag the files again.", command)
                alert.addButton(withTitle: L10n.t("OK"))
                alert.runModal()
                if error != nil {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(command, forType: .string)
                }
            }
        }
    }

    @discardableResult
    private static func open(_ string: String) -> Bool {
        guard let url = URL(string: string) else { return false }
        return NSWorkspace.shared.open(url)
    }
}
