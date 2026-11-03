import Foundation

enum ConversionMatrix {
    /// The full Tangerine conversion wheel: inputs and the exact output set per input.
    /// Mirrors the published matrix (275 options): images 57, audio 56, video 48, PDF 9,
    /// documents 51, EPUB 6, TXT 8, slides 6, spreadsheets 21, subtitles 4, archives 9.
    static func targets(for source: FileFormat) -> [FileFormat] {
        let list: [FileFormat]
        switch source {
        case .jpg, .png, .webp, .heic, .tiff, .svg, .avif, .bmp:
            list = FileFormat.imageTargets
        case .mp3, .m4a, .wav, .flac, .ogg, .opus, .aiff, .wma:
            list = FileFormat.audio
        case .mp4, .mov, .mkv, .webm, .avi, .wmv:
            list = FileFormat.video + [.gif, .mp3]
        case .gif:
            list = FileFormat.video
        case .pdf:
            list = [.docx, .pages, .pptx, .xlsx, .jpg, .png, .epub, .txt, .md]
        case .ppt, .pptx:
            list = [.pdf, .jpg, .png]
        case .xlsx, .xls, .ods, .csv, .tsv:
            list = FileFormat.spreadsheets + [.pdf]
        case .docx, .pages, .md, .rtf, .rtfd, .textClipping:
            list = FileFormat.documentTargets
        case .epub:
            list = [.pdf, .docx, .pages, .txt, .md, .html]
        case .txt:
            list = [.docx, .pages, .pdf, .md, .html, .epub, .jpg, .png]
        case .srt, .vtt:
            list = FileFormat.subtitles + [.txt]
        case .html:
            list = []
        case .zip, .tar, .gz, .rar:
            list = [.zip, .tar, .gz]
        }
        return list.filter { $0 != source && !FileFormat.inputOnly.contains($0) }
    }

    static func targets(for sources: [FileFormat]) -> [FileFormat] {
        guard let first = sources.first else { return [] }
        var common = targets(for: first)
        for source in sources.dropFirst() {
            let next = Set(targets(for: source))
            common = common.filter { next.contains($0) }
        }
        return common
    }

    static var totalConversions: Int {
        FileFormat.allCases.reduce(0) { $0 + targets(for: $1).count }
    }

    static func outputURL(for source: URL, target: FileFormat, in directory: URL, existing: Set<String> = []) -> URL {
        let base = strippedBaseName(source.lastPathComponent)
        var candidate = "\(base).\(target.fileExtension)"
        var counter = 2
        let fm = FileManager.default
        while existing.contains(candidate) || fm.fileExists(atPath: directory.appendingPathComponent(candidate).path) {
            candidate = "\(base) \(counter).\(target.fileExtension)"
            counter += 1
        }
        return directory.appendingPathComponent(candidate)
    }

    /// Uniquifies a full file name ("photo Compressed.jpg" -> "photo Compressed 2.jpg").
    static func uniqueFileURL(directory: URL, fileName: String) -> URL {
        let fm = FileManager.default
        let ns = fileName as NSString
        let ext = ns.pathExtension
        let base = ns.deletingPathExtension
        var candidate = fileName
        var counter = 2
        while fm.fileExists(atPath: directory.appendingPathComponent(candidate).path) {
            candidate = ext.isEmpty ? "\(base) \(counter)" : "\(base) \(counter).\(ext)"
            counter += 1
        }
        return directory.appendingPathComponent(candidate)
    }

    static func uniqueURL(directory: URL, baseName: String, suffix: String, ext: String) -> URL {
        let fm = FileManager.default
        var candidate = suffix.isEmpty ? "\(baseName).\(ext)" : "\(baseName) \(suffix).\(ext)"
        var counter = 2
        while fm.fileExists(atPath: directory.appendingPathComponent(candidate).path) {
            candidate = suffix.isEmpty ? "\(baseName) \(counter).\(ext)" : "\(baseName) \(suffix) \(counter).\(ext)"
            counter += 1
        }
        return directory.appendingPathComponent(candidate)
    }

    static func uniqueDirectory(directory: URL, name: String) -> URL {
        let fm = FileManager.default
        var candidate = name
        var counter = 2
        while fm.fileExists(atPath: directory.appendingPathComponent(candidate).path) {
            candidate = "\(name) \(counter)"
            counter += 1
        }
        return directory.appendingPathComponent(candidate)
    }

    static func strippedBaseName(_ fileName: String) -> String {
        let lower = fileName.lowercased()
        if lower.hasSuffix(".tar.gz") { return String(fileName.dropLast(7)) }
        if lower.hasSuffix(".tgz") { return String(fileName.dropLast(4)) }
        guard let dot = fileName.lastIndex(of: "."), dot != fileName.startIndex else { return fileName }
        return String(fileName[..<dot])
    }
}
