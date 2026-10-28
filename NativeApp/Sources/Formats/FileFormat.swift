import Foundation
import UniformTypeIdentifiers

enum FormatCategory: String, CaseIterable {
    case image
    case audio
    case video
    case document
    case subtitle
    case archive

    var symbol: String {
        switch self {
        case .image: return "photo"
        case .audio: return "waveform"
        case .video: return "film"
        case .document: return "doc.text"
        case .subtitle: return "captions.bubble"
        case .archive: return "archivebox"
        }
    }

    var title: String {
        switch self {
        case .image: return "Image"
        case .audio: return "Audio"
        case .video: return "Video"
        case .document: return "Document"
        case .subtitle: return "Subtitle"
        case .archive: return "Archive"
        }
    }
}

enum FileFormat: String, CaseIterable, Identifiable, Hashable {
    case jpg, png, webp, heic, tiff, svg, avif, bmp, gif
    case mp3, m4a, wav, flac, ogg, opus, aiff, wma
    case mp4, mov, mkv, webm, avi, wmv
    case pdf, docx, pages, md, txt, html, epub, rtf, rtfd, textClipping
    case ppt, pptx, xlsx, xls, ods, csv, tsv
    case srt, vtt
    case zip, tar, gz, rar

    var id: String { rawValue }

    static let images: [FileFormat] = [.jpg, .png, .webp, .heic, .tiff, .svg, .avif, .bmp]
    static let imageTargets: [FileFormat] = [.jpg, .png, .webp, .heic, .tiff, .avif, .bmp, .pdf]
    static let audio: [FileFormat] = [.mp3, .m4a, .wav, .flac, .ogg, .opus, .aiff, .wma]
    static let video: [FileFormat] = [.mp4, .mov, .mkv, .webm, .avi, .wmv]
    static let subtitles: [FileFormat] = [.srt, .vtt]
    static let archives: [FileFormat] = [.zip, .tar, .gz, .rar]
    static let documents: [FileFormat] = [.docx, .pages, .md, .rtf, .rtfd, .textClipping]
    static let spreadsheets: [FileFormat] = [.xlsx, .xls, .ods, .csv, .tsv]
    static let slideShows: [FileFormat] = [.ppt, .pptx]
    static let documentTargets: [FileFormat] = [.docx, .pages, .pdf, .txt, .md, .html, .epub, .png, .jpg]
    /// Formats that can be dragged in but are never offered as an output.
    static let inputOnly: Set<FileFormat> = [.rar, .ppt, .xls, .rtf, .rtfd, .textClipping]

    var category: FormatCategory {
        switch self {
        case .jpg, .png, .webp, .heic, .tiff, .svg, .avif, .bmp: return .image
        case .gif: return .video
        case .mp3, .m4a, .wav, .flac, .ogg, .opus, .aiff, .wma: return .audio
        case .mp4, .mov, .mkv, .webm, .avi, .wmv: return .video
        case .pdf, .docx, .pages, .md, .txt, .html, .epub, .rtf, .rtfd, .textClipping,
             .ppt, .pptx, .xlsx, .xls, .ods, .csv, .tsv: return .document
        case .srt, .vtt: return .subtitle
        case .zip, .tar, .gz, .rar: return .archive
        }
    }

    var displayName: String {
        switch self {
        case .gz: return "GZIP"
        case .md: return "MD"
        case .textClipping: return "TEXT CLIPPING"
        default: return rawValue.uppercased()
        }
    }

    var fileExtension: String {
        switch self {
        case .gz: return "tar.gz"
        default: return rawValue
        }
    }

    var aliases: [String] {
        switch self {
        case .jpg: return ["jpg", "jpeg", "jpe", "jfif"]
        case .tiff: return ["tiff", "tif"]
        case .heic: return ["heic", "heif"]
        case .m4a: return ["m4a", "aac", "m4b"]
        case .mp4: return ["mp4", "m4v"]
        case .mov: return ["mov", "qt"]
        case .gz: return ["gz", "tgz"]
        case .txt: return ["txt", "text", "log"]
        case .md: return ["md", "markdown"]
        case .html: return ["html", "htm", "xhtml"]
        case .aiff: return ["aiff", "aif"]
        case .pages: return ["pages"]
        case .epub: return ["epub"]
        case .rtf: return ["rtf"]
        case .rtfd: return ["rtfd"]
        case .textClipping: return ["textclipping"]
        case .pptx: return ["pptx"]
        case .ppt: return ["ppt"]
        case .xlsx: return ["xlsx"]
        case .xls: return ["xls"]
        case .ods: return ["ods"]
        case .csv: return ["csv"]
        case .tsv: return ["tsv"]
        default: return [rawValue]
        }
    }

    var utType: UTType? {
        switch self {
        case .jpg: return .jpeg
        case .png: return .png
        case .webp: return .webP
        case .heic: return .heic
        case .tiff: return .tiff
        case .svg: return .svg
        case .avif: return UTType("public.avif")
        case .bmp: return .bmp
        case .gif: return .gif
        case .mp3: return .mp3
        case .m4a: return .mpeg4Audio
        case .wav: return .wav
        case .flac: return UTType("org.xiph.flac")
        case .ogg: return UTType("org.xiph.ogg-audio") ?? UTType("public.ogg")
        case .opus: return UTType("public.opus") ?? UTType("org.xiph.opus")
        case .aiff: return .aiff
        case .wma: return UTType("com.microsoft.windows-media-wma")
        case .mp4: return .mpeg4Movie
        case .mov: return .quickTimeMovie
        case .mkv: return UTType("org.matroska.mkv")
        case .webm: return UTType("org.webmproject.webm")
        case .avi: return .avi
        case .wmv: return UTType("com.microsoft.windows-media-wmv")
        case .pdf: return .pdf
        case .docx: return UTType("org.openxmlformats.wordprocessingml.document")
        case .pages: return UTType("com.apple.iwork.pages.pages")
        case .md: return UTType("net.daringfireball.markdown")
        case .txt: return .plainText
        case .html: return .html
        case .epub: return UTType("org.idpf.epub-container")
        case .rtf: return .rtf
        case .rtfd: return UTType("com.apple.rtfd")
        case .textClipping: return UTType("com.apple.finder.textclipping")
        case .ppt: return UTType("com.microsoft.powerpoint.ppt")
        case .pptx: return UTType("org.openxmlformats.presentationml.presentation")
        case .xlsx: return UTType("org.openxmlformats.spreadsheetml.sheet")
        case .xls: return UTType("com.microsoft.excel.xls")
        case .ods: return UTType("org.oasis-open.opendocument.spreadsheet")
        case .csv: return .commaSeparatedText
        case .tsv: return .tabSeparatedText
        case .srt: return UTType("com.subrip.srt") ?? .plainText
        case .vtt: return UTType("org.w3.webvtt") ?? .plainText
        case .zip: return .zip
        case .tar: return UTType("public.tar-archive")
        case .gz: return .gzip
        case .rar: return UTType("com.rarlab.rar-archive")
        }
    }

    static func detect(_ url: URL) -> FileFormat? {
        let name = url.lastPathComponent.lowercased()
        if name.hasSuffix(".tar.gz") || name.hasSuffix(".tgz") { return .gz }
        let ext = url.pathExtension.lowercased()
        guard !ext.isEmpty else { return nil }
        return allCases.first { $0.aliases.contains(ext) }
    }

    static func detect(extension ext: String) -> FileFormat? {
        let lower = ext.lowercased()
        return allCases.first { $0.aliases.contains(lower) }
    }

    var isMultiTrack: Bool { category == .video || category == .audio }
}
