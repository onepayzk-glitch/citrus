import AppKit
import Foundation
import PDFKit

/// Serializes LibreOffice processes so one persistent profile can be reused.
/// Blocking happens on a background thread while waiting; the run itself is async.
private final class AsyncLock: @unchecked Sendable {
    private let semaphore = DispatchSemaphore(value: 1)

    func withLock<T>(_ body: () async throws -> T) async rethrows -> T {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            let semaphore = self.semaphore
            DispatchQueue.global(qos: .userInitiated).async {
                semaphore.wait()
                continuation.resume()
            }
        }
        defer { semaphore.signal() }
        return try await body()
    }
}

/// Uses an installed LibreOffice as an optional high-fidelity engine for Office
/// documents. Nothing is bundled, downloaded, or installed by this app: when no
/// LibreOffice is found, Office conversions fall back to the built-in text engine.
struct OfficeEngine: ConversionEngine {
    enum Health: Equatable {
        case missing
        case ready(path: String, version: String)
        case broken(path: String, reason: String)

        var summary: String {
            switch self {
            case .missing:
                return "No LibreOffice found. Office conversions use the built-in text engine."
            case let .ready(path, version):
                return "\(version) · \(path)"
            case let .broken(path, reason):
                return "LibreOffice at \(path) could not run: \(reason)"
            }
        }

        var isReady: Bool {
            if case .ready = self { return true }
            return false
        }
    }

    /// Input formats that LibreOffice converts with higher fidelity than the text engine.
    static let sourceFormats: Set<FileFormat> = [
        // Plain text stays on the built-in engine: it is deterministic and needs no
        // external app, and the typography difference is not worth the dependency.
        .docx, .rtf, .html, .csv, .tsv, .xlsx, .xls, .ods, .ppt, .pptx,
    ]

    private static let processLock = AsyncLock()

    private static let profileURL: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent("Citrus", isDirectory: true)
            .appendingPathComponent("LibreOfficeProfile", isDirectory: true)
        let fallback = FileManager.default.temporaryDirectory.appendingPathComponent("opentangerine-libreoffice-profile", isDirectory: true)
        let url = base ?? fallback
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }()

    /// Search order: user setting, standard app locations, Homebrew, PATH.
    static var candidateBinaries: [String] {
        var paths: [String] = []
        let configured = AppSettings.shared.officeEnginePath.trimmingCharacters(in: .whitespacesAndNewlines)
        if !configured.isEmpty { paths.append(configured) }
        paths += [
            "/Applications/LibreOffice.app/Contents/MacOS/soffice",
            FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications/LibreOffice.app/Contents/MacOS/soffice").path,
            "/opt/homebrew/bin/soffice",
            "/usr/local/bin/soffice",
        ]
        if let found = Shell.which("soffice") { paths.append(found) }
        var seen = Set<String>()
        return paths.filter { path in
            let resolved = (path as NSString).resolvingSymlinksInPath
            guard FileManager.default.isExecutableFile(atPath: resolved), !seen.contains(resolved) else { return false }
            seen.insert(resolved)
            return true
        }
    }

    static var binary: String? { candidateBinaries.first }

    static var isAvailable: Bool { binary != nil }

    static func checkHealth() async -> Health {
        guard let binary else { return .missing }
        do {
            let result = try await Shell.run(binary, ["--version"], timeout: 30)
            let firstLine = result.stdout.split(separator: "\n").first.map(String.init)?.trimmingCharacters(in: .whitespaces) ?? ""
            guard result.succeeded, firstLine.lowercased().contains("libreoffice") else {
                return .broken(path: binary, reason: firstLine.isEmpty ? result.stderr : firstLine)
            }
            return .ready(path: binary, version: firstLine)
        } catch {
            return .broken(path: binary, reason: error.localizedDescription)
        }
    }

    func supports(from: FileFormat, to: FileFormat) -> Bool {
        guard OfficeEngine.isAvailable, OfficeEngine.sourceFormats.contains(from) else { return false }
        return to == .pdf || to == .png || to == .jpg
    }

    func convert(_ request: ConversionRequest) async throws {
        guard let binary = OfficeEngine.binary else {
            throw OpenTangerineError.invalidInput("No LibreOffice installation was found. Install LibreOffice or set its soffice path in Settings → Formats → Office engine.")
        }
        let fm = FileManager.default
        let work = fm.temporaryDirectory.appendingPathComponent("opentangerine-office-\(UUID().uuidString)")
        defer { try? fm.removeItem(at: work) }

        request.progress(0.15)
        var pdf: URL?
        var lastError = ""
        // A shared profile makes warm conversions fast; a fresh profile is the fallback
        // when the shared one is busy or stale (for example after a crash).
        for profile in [OfficeEngine.profileURL, work.appendingPathComponent("profile")] {
            let outputDirectory = work.appendingPathComponent("out-\(profile.lastPathComponent)")
            try? fm.createDirectory(at: profile, withIntermediateDirectories: true)
            try? fm.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
            let result = try await OfficeEngine.processLock.withLock {
                try await Self.runLibreOffice(binary: binary, profile: profile, output: outputDirectory, source: request.source)
            }
            if result.succeeded,
               let produced = (try? fm.contentsOfDirectory(at: outputDirectory, includingPropertiesForKeys: nil))?
                   .first(where: { $0.pathExtension.lowercased() == "pdf" }),
               fm.fileExists(atPath: produced.path) {
                pdf = produced
                break
            }
            lastError = result.stderr.isEmpty ? result.stdout : result.stderr
        }

        guard let pdf, fm.fileExists(atPath: pdf.path) else {
            throw OpenTangerineError.toolFailed("LibreOffice", lastError)
        }
        request.progress(0.7)
        if request.target == .pdf {
            try fm.moveItem(at: pdf, to: request.destination)
            request.progress(1)
            return
        }
        try renderPages(of: pdf, to: request.destination, format: request.target, progress: request.progress)
    }

    private static func runLibreOffice(binary: String, profile: URL, output: URL, source: URL) async throws -> ShellResult {
        let arguments = [
            "-env:UserInstallation=\(profile.absoluteString)",
            "--headless",
            "--norestore",
            "--nolockcheck",
            "--nodefault",
            "--convert-to", "pdf",
            "--outdir", output.path,
            source.path,
        ]
        return try await Shell.run(binary, arguments, timeout: 180)
    }

    /// Renders the LibreOffice PDF to PNG/JPG. One page becomes one image; several pages
    /// become a folder of page images, matching the PDF → image behavior.
    private func renderPages(of pdfURL: URL, to destination: URL, format: FileFormat, progress: @escaping (Double) -> Void) throws {
        let document = try PDFOps.document(pdfURL)
        let pageCount = document.pageCount
        guard pageCount > 0 else { throw OpenTangerineError.invalidInput("The document has no pages.") }
        if pageCount == 1, let page = document.page(at: 0), let image = PDFRenderer.render(page: page, dpi: 200) {
            try ImageIOBridge.write(image, to: destination, format: format, quality: 0.92)
            progress(1)
            return
        }
        let folder = destination.deletingPathExtension()
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let base = ConversionMatrix.strippedBaseName(pdfURL.lastPathComponent)
        for index in 0..<pageCount {
            guard let page = document.page(at: index), let image = PDFRenderer.render(page: page, dpi: 200) else {
                throw OpenTangerineError.encodeFailed("page \(index + 1)")
            }
            let pageURL = folder.appendingPathComponent("\(base) - page \(index + 1).\(format.fileExtension)")
            try ImageIOBridge.write(image, to: pageURL, format: format, quality: 0.92)
            progress(0.7 + 0.3 * Double(index + 1) / Double(pageCount))
        }
        try? FileManager.default.removeItem(at: destination)
        try FileManager.default.moveItem(at: folder, to: destination)
    }
}
