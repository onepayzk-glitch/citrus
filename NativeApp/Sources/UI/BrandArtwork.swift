import AppKit

/// Menu-bar icon variants. Defined here because the icon generator compiles this
/// file on its own without the rest of the app sources.
enum MenuBarIconStyle: String, CaseIterable, Identifiable {
    case citrus, minimal, monogram

    var id: String { rawValue }

    /// English keys; the Settings picker localizes them with L10n.t.
    var title: String {
        switch self {
        case .citrus: return "Citrus fruit"
        case .minimal: return "Minimal dot"
        case .monogram: return "Monogram C"
        }
    }
}

/// Original vector mark, shared by app artwork and the template menu-bar icon.
enum BrandArtwork {
    static func image(size: CGFloat, template: Bool = false) -> NSImage {
        let image = NSImage(size: NSSize(width: size, height: size), flipped: false) { rect in
            let s = rect.width
            if !template {
                NSColor(srgbRed: 1, green: 0.36, blue: 0.06, alpha: 1).setFill()
                NSBezierPath(roundedRect: rect.insetBy(dx: s * 0.04, dy: s * 0.04), xRadius: s * 0.22, yRadius: s * 0.22).fill()
            }
            (template ? NSColor.labelColor : NSColor.white).setStroke()
            let fruit = NSBezierPath(ovalIn: NSRect(x: s * 0.23, y: s * 0.2, width: s * 0.54, height: s * 0.52))
            fruit.lineWidth = s * 0.055
            fruit.stroke()
            let leaf = NSBezierPath()
            leaf.move(to: NSPoint(x: s * 0.49, y: s * 0.73))
            leaf.curve(to: NSPoint(x: s * 0.72, y: s * 0.84), controlPoint1: NSPoint(x: s * 0.49, y: s * 0.88), controlPoint2: NSPoint(x: s * 0.66, y: s * 0.88))
            leaf.curve(to: NSPoint(x: s * 0.49, y: s * 0.73), controlPoint1: NSPoint(x: s * 0.70, y: s * 0.73), controlPoint2: NSPoint(x: s * 0.59, y: s * 0.71))
            (template ? NSColor.labelColor : NSColor.white).setFill()
            leaf.fill()
            let shine = NSBezierPath()
            shine.move(to: NSPoint(x: s * 0.34, y: s * 0.49))
            shine.curve(to: NSPoint(x: s * 0.43, y: s * 0.61), controlPoint1: NSPoint(x: s * 0.34, y: s * 0.56), controlPoint2: NSPoint(x: s * 0.39, y: s * 0.61))
            shine.lineWidth = s * 0.04
            shine.lineCapStyle = .round
            shine.stroke()
            return true
        }
        image.isTemplate = template
        return image
    }

    /// Menu-bar mark for the chosen style. Always a template image so macOS can
    /// invert it for the light/dark menu bar.
    static func menuBarImage(style: MenuBarIconStyle, size: CGFloat = 24) -> NSImage {
        switch style {
        case .citrus:
            return image(size: size, template: true)
        case .minimal:
            let image = NSImage(size: NSSize(width: size, height: size), flipped: false) { rect in
                let s = rect.width
                NSColor.labelColor.setFill()
                NSBezierPath(ovalIn: NSRect(x: s * 0.2, y: s * 0.2, width: s * 0.6, height: s * 0.6)).fill()
                NSBezierPath(ovalIn: NSRect(x: s * 0.42, y: s * 0.42, width: s * 0.16, height: s * 0.16)).fill()
                return true
            }
            image.isTemplate = true
            return image
        case .monogram:
            let image = NSImage(size: NSSize(width: size, height: size), flipped: false) { rect in
                let text = "C" as NSString
                let attributes: [NSAttributedString.Key: Any] = [
                    .font: NSFont.systemFont(ofSize: rect.width * 0.78, weight: .bold),
                    .foregroundColor: NSColor.labelColor,
                ]
                let textSize = text.size(withAttributes: attributes)
                text.draw(at: NSPoint(x: (rect.width - textSize.width) / 2, y: (rect.height - textSize.height) / 2), withAttributes: attributes)
                return true
            }
            image.isTemplate = true
            return image
        }
    }
}
