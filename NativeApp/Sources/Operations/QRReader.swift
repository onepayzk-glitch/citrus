import CoreImage
import Foundation
import ImageIO

/// Reads QR codes locally with CoreImage. No network and no uploads.
enum QRReader {
    struct Result: Identifiable {
        let id = UUID()
        let payload: String
        let bounds: CGRect
    }

    static func read(_ url: URL) throws -> [Result] {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil),
              let ciImage = CIImage(cgImage: image) as CIImage? else {
            throw OpenTangerineError.unreadable(url)
        }
        guard let detector = CIDetector(ofType: CIDetectorTypeQRCode, context: nil, options: [CIDetectorAccuracy: CIDetectorAccuracyHigh]) else {
            throw OpenTangerineError.invalidInput("QR detection is not available on this Mac.")
        }
        let features = detector.features(in: ciImage).compactMap { $0 as? CIQRCodeFeature }
        return features.compactMap { feature in
            guard let payload = feature.messageString, !payload.isEmpty else { return nil }
            return Result(payload: payload, bounds: feature.bounds)
        }
    }
}
