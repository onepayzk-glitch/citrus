import AppKit
import CoreGraphics
import SwiftUI

enum AnnotationColor: String, CaseIterable, Identifiable {
    case red, orange, yellow, green, blue, white, black

    var id: String { rawValue }

    var title: String { rawValue.capitalized }

    var color: NSColor {
        switch self {
        case .red: return .systemRed
        case .orange: return .systemOrange
        case .yellow: return .systemYellow
        case .green: return .systemGreen
        case .blue: return .systemBlue
        case .white: return .white
        case .black: return .black
        }
    }

    var swiftUI: Color { Color(nsColor: color) }
}

struct AnnotationItem: Identifiable, Equatable {
    enum Kind: String, CaseIterable, Identifiable {
        case box, arrow, highlight, text, step

        var id: String { rawValue }

        var title: String {
            switch self {
            case .box: return "Box"
            case .arrow: return "Arrow"
            case .highlight: return "Highlight"
            case .text: return "Text"
            case .step: return "Step"
            }
        }

        var symbol: String {
            switch self {
            case .box: return "rectangle"
            case .arrow: return "arrow.up.right"
            case .highlight: return "highlighter"
            case .text: return "textformat"
            case .step: return "1.circle"
            }
        }
    }

    var id = UUID()
    var kind: Kind
    var rect: CGRect
    var text: String = ""
    var color: AnnotationColor = .red
    var lineWidth: CGFloat = 4
}

enum AnnotationRenderer {
    static func render(_ image: CGImage, items: [AnnotationItem]) -> CGImage {
        let width = image.width
        let height = image.height
        guard let context = CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return image }
        context.interpolationQuality = .high
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        for (index, item) in items.enumerated() {
            draw(item, number: index + 1, in: context, height: CGFloat(height), scale: 1)
        }
        return context.makeImage() ?? image
    }

    private static func flipped(_ rect: CGRect, height: CGFloat) -> CGRect {
        CGRect(x: rect.minX, y: height - rect.maxY, width: rect.width, height: rect.height)
    }

    private static func flipped(_ point: CGPoint, height: CGFloat) -> CGPoint {
        CGPoint(x: point.x, y: height - point.y)
    }

    private static func draw(_ item: AnnotationItem, number: Int, in context: CGContext, height: CGFloat, scale: CGFloat) {
        let color = item.color.color
        let lineWidth = max(1, item.lineWidth * scale)
        switch item.kind {
        case .box:
            let rect = flipped(item.rect, height: height)
            context.setFillColor(color.withAlphaComponent(0.14).cgColor)
            context.fill(rect.insetBy(dx: lineWidth / 2, dy: lineWidth / 2))
            context.setStrokeColor(color.cgColor)
            context.setLineWidth(lineWidth)
            context.stroke(rect.insetBy(dx: lineWidth / 2, dy: lineWidth / 2))
        case .highlight:
            let rect = flipped(item.rect, height: height)
            context.setFillColor(NSColor.systemYellow.withAlphaComponent(0.38).cgColor)
            context.fill(rect)
        case .arrow:
            let start = flipped(CGPoint(x: item.rect.minX, y: item.rect.maxY), height: height)
            let end = flipped(CGPoint(x: item.rect.maxX, y: item.rect.minY), height: height)
            context.setStrokeColor(color.cgColor)
            context.setLineWidth(lineWidth)
            context.setLineCap(.round)
            context.move(to: start)
            context.addLine(to: end)
            context.strokePath()
            let angle = atan2(end.y - start.y, end.x - start.x)
            let headLength = max(10, lineWidth * 4)
            for offset in [CGFloat.pi * 0.75, -CGFloat.pi * 0.75] {
                let point = CGPoint(
                    x: end.x + cos(angle + offset) * headLength,
                    y: end.y + sin(angle + offset) * headLength
                )
                context.move(to: end)
                context.addLine(to: point)
            }
            context.strokePath()
        case .text:
            let attributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: max(14, 18 * scale), weight: .bold),
                .foregroundColor: color,
            ]
            let origin = flipped(CGPoint(x: item.rect.minX, y: item.rect.minY), height: height)
            let string = NSAttributedString(string: item.text.isEmpty ? "Text" : item.text, attributes: attributes)
            let line = CTLineCreateWithAttributedString(string)
            context.saveGState()
            context.textMatrix = .identity
            context.textPosition = CGPoint(x: origin.x, y: origin.y - (string.size().height * 0.8))
            CTLineDraw(line, context)
            context.restoreGState()
        case .step:
            let center = flipped(CGPoint(x: item.rect.midX, y: item.rect.midY), height: height)
            let radius = max(14, min(item.rect.width, item.rect.height) / 2)
            context.setFillColor(color.cgColor)
            context.fillEllipse(in: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
            let attributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: radius, weight: .bold),
                .foregroundColor: NSColor.white,
            ]
            let string = NSAttributedString(string: "\(number)", attributes: attributes)
            let line = CTLineCreateWithAttributedString(string)
            let bounds = CTLineGetBoundsWithOptions(line, .useGlyphPathBounds)
            context.saveGState()
            context.textMatrix = .identity
            context.textPosition = CGPoint(x: center.x - bounds.width / 2, y: center.y - bounds.height / 2)
            CTLineDraw(line, context)
            context.restoreGState()
        }
    }
}
