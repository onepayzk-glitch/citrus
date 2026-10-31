import AppKit
import CryptoKit

enum FileAction: String, CaseIterable, Hashable {
    case airDrop = "AirDrop"
    case float = "Float"
    case copy = "Copy"
    case move = "Move"
    case paths = "Copy Path"
    case openTerminal = "Terminal"
    // Extra actions kept from the community baseline.
    case reveal = "Reveal"
    case duplicate = "Duplicate"
    case hash = "SHA-256"

    /// The six actions Tangerine offers in its Control wheel.
    static let official: [FileAction] = [.airDrop, .float, .copy, .move, .paths, .openTerminal]

    var symbol: String {
        switch self {
        case .airDrop: return "airplayaudio"
        case .float: return "pin.fill"
        case .copy: return "doc.on.doc"
        case .move: return "folder"
        case .paths: return "doc.text"
        case .openTerminal: return "terminal"
        case .reveal: return "folder"
        case .duplicate: return "plus.square.on.square"
        case .hash: return "number"
        }
    }

    var localizedTitle: String { L10n.t(rawValue) }

    var detail: String {
        switch self {
        case .airDrop: return "Share files and folders through the macOS recipient picker."
        case .float: return "Keep files in a floating shelf you can drag into another app."
        case .copy: return "Copy files to the clipboard, ready to paste in Finder."
        case .move: return "Choose a destination folder and move the originals there."
        case .paths: return "Copy full file paths as text, one path per line."
        case .openTerminal: return "Open the containing folder in Terminal."
        case .reveal: return "Reveal the files in Finder."
        case .duplicate: return "Create a copy next to each original."
        case .hash: return "Copy a SHA-256 checksum for each file."
        }
    }

    static func duplicateFiles(_ urls: [URL]) throws -> [URL] {
        try urls.map { source in
            let destination = ConversionMatrix.uniqueURL(directory: source.deletingLastPathComponent(), baseName: source.deletingPathExtension().lastPathComponent, suffix: "copy", ext: source.pathExtension)
            try FileManager.default.copyItem(at: source, to: destination)
            return destination
        }
    }

    static func moveFiles(_ urls: [URL], into directory: URL) throws -> [URL] {
        var moved: [URL] = []
        for source in urls {
            let destination = ConversionMatrix.uniqueURL(directory: directory, baseName: source.deletingPathExtension().lastPathComponent, suffix: "", ext: source.pathExtension)
            try FileManager.default.moveItem(at: source, to: destination)
            moved.append(destination)
        }
        return moved
    }

    static func hashReport(_ urls: [URL]) throws -> String {
        try urls.map { url in
            let values = try url.resourceValues(forKeys: [.isRegularFileKey])
            guard values.isRegularFile == true else { throw OpenTangerineError.unreadable(url) }
            let file = try FileHandle(forReadingFrom: url)
            defer { try? file.close() }
            var hash = SHA256()
            while let data = try file.read(upToCount: 1_048_576), !data.isEmpty {
                try Task.checkCancellation()
                hash.update(data: data)
            }
            return hash.finalize().map { String(format: "%02x", $0) }.joined() + "  " + url.lastPathComponent
        }.joined(separator: "\n")
    }

    @MainActor func run(_ urls: [URL]) {
        switch self {
        case .airDrop:
            let items = urls as [NSURL]
            if let service = NSSharingService(named: .sendViaAirDrop) {
                service.perform(withItems: items)
            } else {
                let picker = NSSharingServicePicker(items: items)
                if let view = NSApp.keyWindow?.contentView {
                    picker.show(relativeTo: .zero, of: view, preferredEdge: .minY)
                } else {
                    Self.alert("AirDrop is not available on this Mac.")
                }
            }
        case .float:
            FloatingShelfManager.shared.present(urls: urls)
        case .copy:
            NSPasteboard.general.clearContents()
            NSPasteboard.general.writeObjects(urls as [NSURL])
        case .move:
            let panel = NSOpenPanel()
            panel.canChooseDirectories = true
            panel.canChooseFiles = false
            panel.allowsMultipleSelection = false
            panel.prompt = "Move Here"
            panel.message = "Choose a destination folder for \(urls.count) item\(urls.count == 1 ? "" : "s")."
            NSApp.activate(ignoringOtherApps: true)
            panel.begin { response in
                guard response == .OK, let directory = panel.url else { return }
                JobRunner.shared.run(title: "Moving", detail: "\(urls.count) item\(urls.count == 1 ? "" : "s")") { _ in
                    let moved = try Self.moveFiles(urls, into: directory)
                    NSWorkspace.shared.activateFileViewerSelecting(moved)
                    return moved
                }
            }
        case .paths:
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(urls.map(\.path).joined(separator: "\n"), forType: .string)
        case .openTerminal:
            let folder = urls[0].hasDirectoryPath ? urls[0] : urls[0].deletingLastPathComponent()
            let preferred = AppSettings.shared.terminalApplication.applicationURL
            if let preferred, FileManager.default.fileExists(atPath: preferred.path) {
                NSWorkspace.shared.open([folder], withApplicationAt: preferred, configuration: NSWorkspace.OpenConfiguration()) { _, error in
                    if error != nil { NSWorkspace.shared.open(folder) }
                }
            } else {
                NSWorkspace.shared.open(folder)
            }
        case .reveal:
            NSWorkspace.shared.activateFileViewerSelecting(urls)
        case .duplicate:
            JobRunner.shared.run(title: "Duplicate", detail: "\(urls.count) files") { _ in
                try Self.duplicateFiles(urls)
            }
        case .hash:
            Task {
                do {
                    let report = try await Task.detached(priority: .userInitiated) {
                        try Self.hashReport(urls)
                    }.value
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(report, forType: .string)
                    let alert = NSAlert()
                    alert.messageText = "SHA-256 copied"
                    alert.informativeText = report
                    alert.runModal()
                } catch {
                    let alert = NSAlert(error: error)
                    alert.runModal()
                }
            }
        }
    }

    @MainActor private static func alert(_ message: String) {
        let alert = NSAlert()
        alert.messageText = message
        alert.runModal()
    }
}
