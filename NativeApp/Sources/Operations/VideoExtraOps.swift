import AVFoundation
import Foundation

extension VideoOps {
    /// Mute video: export a copy without any audio track.
    static func removeAudio(_ url: URL, to destination: URL, progress: @escaping (Double) -> Void) async throws {
        let asset = AVURLAsset(url: url)
        if !FFmpeg.isAvailable, await MediaInfo.isNativelyReadable(url) {
            let composition = AVMutableComposition()
            let duration = try await asset.load(.duration)
            guard let source = try await asset.loadTracks(withMediaType: .video).first,
                  let track = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid) else {
                throw OpenTangerineError.invalidInput("No video track found.")
            }
            try track.insertTimeRange(CMTimeRange(start: .zero, duration: duration), of: source, at: .zero)
            track.preferredTransform = try await source.load(.preferredTransform)
            try await AVExporter.export(asset: composition, to: destination, format: .mp4, preset: AVAssetExportPresetHighestQuality, progress: progress)
            return
        }
        let duration = await FFmpeg.probeDuration(url) ?? 0
        var args = ["-i", url.path, "-an", "-c:v", "libx264", "-preset", "medium", "-pix_fmt", "yuv420p", "-movflags", "+faststart", "-f", "mp4"]
        args.append(destination.path)
        try await FFmpeg.run(args, purpose: "Muting video", duration: duration, progress: progress)
    }
}
