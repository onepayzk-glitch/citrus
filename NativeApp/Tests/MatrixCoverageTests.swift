import Foundation

/// Verifies that every route in the published conversion matrix resolves to an engine
/// on a machine with all optional engines installed. Skips when the assembly build lacks
/// LibreOffice, FFmpeg or Pages so the suite stays green on machines without them.
@main struct MatrixCoverageTests {
    @MainActor static func main() async throws {
        let office = OfficeEngine.isAvailable
        let ffmpeg = FFmpeg.isAvailable
        let pages = FileManager.default.fileExists(atPath: "/Applications/Pages.app")

        guard office, ffmpeg, pages else {
            print("SKIP matrix coverage: needs LibreOffice + FFmpeg + Pages (office=\(office) ffmpeg=\(ffmpeg) pages=\(pages))")
            return
        }

        var total = 0
        var missing: [String] = []
        var perSource: [String: Int] = [:]
        for source in FileFormat.allCases {
            for target in ConversionMatrix.targets(for: source) {
                total += 1
                perSource[source.rawValue, default: 0] += 1
                if Engines.engine(from: source, to: target) == nil {
                    missing.append("\(source.rawValue)->\(target.rawValue)")
                }
            }
        }

        precondition(total == 275, "expected 275 routes, got \(total)")
        precondition(missing.isEmpty, "routes without engine: \(missing.joined(separator: ", "))")

        // Family totals from the published matrix.
        let imageCount = ["jpg", "png", "webp", "heic", "tiff", "svg", "avif", "bmp"].reduce(0) { $0 + (perSource[$1] ?? 0) }
        let audioCount = ["mp3", "m4a", "wav", "flac", "ogg", "opus", "aiff", "wma"].reduce(0) { $0 + (perSource[$1] ?? 0) }
        let videoCount = ["mp4", "mov", "mkv", "webm", "avi", "wmv", "gif"].reduce(0) { $0 + (perSource[$1] ?? 0) }
        precondition(imageCount == 57, "image routes \(imageCount)")
        precondition(audioCount == 56, "audio routes \(audioCount)")
        precondition(videoCount == 48, "video routes \(videoCount)")

        print("PASS matrix coverage: \(total)/275 routes have engines (images \(imageCount), audio \(audioCount), video \(videoCount))")
    }
}
