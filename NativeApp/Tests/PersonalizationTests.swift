import AppKit
import Foundation

@main struct PersonalizationTests {
    @MainActor static func main() async throws {
        // Output naming template
        precondition(OutputNaming.fileName(base: "photo", suffix: "Compressed", ext: "jpg", template: "{name} {tool}") == "photo Compressed.jpg")
        precondition(OutputNaming.fileName(base: "photo", suffix: "Trimmed", ext: "mp4", template: "{name}-{tool}") == "photo-Trimmed.mp4")
        precondition(OutputNaming.fileName(base: "photo", suffix: "Edited", ext: "png", template: "{name}") == "photo.png")
        precondition(OutputNaming.fileName(base: "a/b", suffix: "", ext: "png", template: "{name}").contains("/") == false)
        precondition(OutputNaming.fileName(base: "photo", suffix: "Edited", ext: "png", template: "   ") == "photo Edited.png")
        let dated = OutputNaming.fileName(base: "photo", suffix: "X", ext: "png", template: "{name}-{date}", date: Date(timeIntervalSince1970: 0))
        precondition(dated.contains("1970-01-01"), "date placeholder: \(dated)")
        let indexed = OutputNaming.fileName(base: "photo", suffix: "X", ext: "png", template: "{name} {index}", index: 3)
        precondition(indexed == "photo 3.png", "index placeholder: \(indexed)")

        // Choice surfaces
        precondition(AccentChoice.allCases.count == 7)
        precondition(MenuBarIconStyle.allCases.count == 3)
        precondition(SoundChoice.allCases.count == 4)
        precondition(SoundChoice.none.soundName == nil)
        precondition(SoundChoice.glass.soundName == "Glass")

        // Menu-bar artwork renders for every style.
        for style in MenuBarIconStyle.allCases {
            let image = BrandArtwork.menuBarImage(style: style)
            precondition(image.size.width > 0 && image.size.height > 0, "\(style) image")
            precondition(image.isTemplate, "\(style) template")
        }

        // Per-format quality override falls back to the global quality and can be reset.
        let settings = AppSettings.shared
        let previous = settings.jpegQuality
        settings.setQuality(nil, for: .webp)
        precondition(settings.quality(for: .webp) == settings.jpegQuality)
        settings.setQuality(0.5, for: .webp)
        precondition(settings.quality(for: .webp) == 0.5)
        settings.setQuality(nil, for: .webp)
        precondition(settings.quality(for: .webp) == settings.jpegQuality)
        settings.jpegQuality = previous

        print("PASS personalization: naming template, accent/icon/sound choices, quality overrides")
    }
}
