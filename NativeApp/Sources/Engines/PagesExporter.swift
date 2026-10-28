import AppKit
import Foundation

/// Exports documents to the Pages format through the installed Pages app.
/// The first run triggers the standard macOS Automation consent prompt.
enum PagesExporter {
    static let appURL = URL(fileURLWithPath: "/Applications/Pages.app")

    static var isInstalled: Bool { FileManager.default.fileExists(atPath: appURL.path) }

    static func canExport(from format: FileFormat) -> Bool {
        isInstalled
    }

    static func export(_ source: URL, from format: FileFormat, to destination: URL) async throws {
        guard isInstalled else {
            throw OpenTangerineError.invalidInput("Exporting to PAGES needs Apple Pages installed in /Applications.")
        }
        let fm = FileManager.default
        var temporaryInput: URL?
        defer { if let temporaryInput { try? fm.removeItem(at: temporaryInput) } }

        let input: URL
        switch format {
        case .md, .html, .epub, .textClipping:
            let document = try await TextDocumentReader.read(source, format: format)
            let textURL = fm.temporaryDirectory.appendingPathComponent("opentangerine-pages-\(UUID().uuidString).txt")
            try document.lines.joined(separator: "\n").write(to: textURL, atomically: true, encoding: .utf8)
            temporaryInput = textURL
            input = textURL
        default:
            input = source
        }

        let script = """
        tell application "Pages"
            set theDocument to open POSIX file "\(input.path)"
            save theDocument in POSIX file "\(destination.path)"
            close theDocument saving no
        end tell
        """
        let result = try await Shell.run("/usr/bin/osascript", ["-e", script])
        guard result.succeeded, fm.fileExists(atPath: destination.path) else {
            let reason = result.stderr.trimmingCharacters(in: .whitespacesAndNewlines)
            throw OpenTangerineError.invalidInput("Pages export failed. Allow Automation for Open Tangerine when macOS asks, then retry. \(reason)")
        }
    }
}
