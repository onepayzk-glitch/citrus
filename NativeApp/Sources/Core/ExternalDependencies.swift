import Foundation

/// The 1.0 build is an assembly build: external engines are not bundled. This type
/// describes a dependency that a user is about to need, and decides when a route or a
/// tool needs one that is missing.
enum ExternalDependency: String, CaseIterable, Identifiable {
    case libreOffice
    case ffmpeg
    case pages

    var id: String { rawValue }

    var title: String {
        switch self {
        case .libreOffice: return "LibreOffice"
        case .ffmpeg: return "FFmpeg"
        case .pages: return "Pages"
        }
    }

    var summary: String {
        switch self {
        case .libreOffice:
            return L10n.t("LibreOffice gives Office documents their original layout when converting DOCX, PPTX, XLSX and ODS. Without it the built-in text engine still converts the content, with approximate layout.")
        case .ffmpeg:
            return L10n.t("FFmpeg adds MP3, FLAC, OGG, Opus, WMA, MKV, WebM, AVI, WMV and GIF support. Without it these routes cannot run.")
        case .pages:
            return L10n.t("Exporting to PAGES uses the Pages app installed on this Mac. Pages is a free Apple app.")
        }
    }

    var fallbackDescription: String? {
        switch self {
        case .libreOffice: return L10n.t("Continue with the built-in text engine")
        case .ffmpeg, .pages: return nil
        }
    }

    var isInstalled: Bool {
        switch self {
        case .libreOffice: return OfficeEngine.isAvailable
        case .ffmpeg: return FFmpeg.isAvailable
        case .pages: return FileManager.default.fileExists(atPath: "/Applications/Pages.app")
        }
    }
}

enum DependencyAdvisor {
    /// Decides whether a conversion route needs a missing external dependency.
    /// Availability flags are parameters so the logic is testable without the apps.
    static func missingDependency(
        source: FileFormat?,
        target: FileFormat,
        officeAvailable: Bool = OfficeEngine.isAvailable,
        ffmpegAvailable: Bool = FFmpeg.isAvailable,
        pagesAvailable: Bool = FileManager.default.fileExists(atPath: "/Applications/Pages.app")
    ) -> ExternalDependency? {
        if target == .pages, !pagesAvailable { return .pages }
        if let source, OfficeEngine.sourceFormats.contains(source), !officeAvailable,
           target == .pdf || target == .png || target == .jpg {
            return .libreOffice
        }
        if !ffmpegAvailable, needsFFmpeg(target: target) { return .ffmpeg }
        return nil
    }

    /// FFmpeg-only output formats in this build.
    static func needsFFmpeg(target: FileFormat) -> Bool {
        [.mkv, .webm, .avi, .wmv, .gif, .mp3, .flac, .ogg, .opus, .wma].contains(target)
    }

    /// Tools that have no native fallback and cannot run without FFmpeg.
    static func missingDependency(forTool tool: ToolID, ffmpegAvailable: Bool = FFmpeg.isAvailable) -> ExternalDependency? {
        let hardFFmpegTools: Set<ToolID> = [.audioChannels, .redactAudio, .audioToVideo]
        if hardFFmpegTools.contains(tool), !ffmpegAvailable { return .ffmpeg }
        return nil
    }
}
