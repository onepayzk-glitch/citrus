import Foundation

@main struct DependencyTests {
    @MainActor static func main() async throws {
        // Office route that can use LibreOffice: prompt only when it is missing.
        precondition(DependencyAdvisor.missingDependency(source: .docx, target: .pdf, officeAvailable: false, ffmpegAvailable: true, pagesAvailable: true) == .libreOffice)
        precondition(DependencyAdvisor.missingDependency(source: .docx, target: .pdf, officeAvailable: true, ffmpegAvailable: true, pagesAvailable: true) == nil)

        // Text-only office targets stay on the built-in engine, no prompt.
        precondition(DependencyAdvisor.missingDependency(source: .docx, target: .txt, officeAvailable: false, ffmpegAvailable: true, pagesAvailable: true) == nil)

        // FFmpeg-only outputs prompt when FFmpeg is missing.
        precondition(DependencyAdvisor.missingDependency(source: .mp4, target: .mkv, officeAvailable: true, ffmpegAvailable: false, pagesAvailable: true) == .ffmpeg)
        precondition(DependencyAdvisor.missingDependency(source: .mp4, target: .mkv, officeAvailable: true, ffmpegAvailable: true, pagesAvailable: true) == nil)
        precondition(DependencyAdvisor.missingDependency(source: .wav, target: .flac, officeAvailable: true, ffmpegAvailable: false, pagesAvailable: true) == .ffmpeg)

        // Native routes never prompt.
        precondition(DependencyAdvisor.missingDependency(source: .png, target: .jpg, officeAvailable: false, ffmpegAvailable: false, pagesAvailable: true) == nil)
        precondition(DependencyAdvisor.missingDependency(source: .mp4, target: .mp4, officeAvailable: false, ffmpegAvailable: false, pagesAvailable: true) == nil)

        // PAGES output needs the Pages app.
        precondition(DependencyAdvisor.missingDependency(source: .docx, target: .pages, officeAvailable: true, ffmpegAvailable: true, pagesAvailable: false) == .pages)
        precondition(DependencyAdvisor.missingDependency(source: .docx, target: .pages, officeAvailable: true, ffmpegAvailable: true, pagesAvailable: true) == nil)

        // Tools without a native fallback.
        precondition(DependencyAdvisor.missingDependency(forTool: .audioChannels, ffmpegAvailable: false) == .ffmpeg)
        precondition(DependencyAdvisor.missingDependency(forTool: .redactAudio, ffmpegAvailable: false) == .ffmpeg)
        precondition(DependencyAdvisor.missingDependency(forTool: .audioToVideo, ffmpegAvailable: false) == .ffmpeg)
        precondition(DependencyAdvisor.missingDependency(forTool: .compress, ffmpegAvailable: false) == nil)
        precondition(DependencyAdvisor.missingDependency(forTool: .audioChannels, ffmpegAvailable: true) == nil)

        print("PASS dependency advisor: office, ffmpeg, pages prompts and fallbacks")
    }
}
