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

        // Wheel and motion choices
        precondition(WheelSize.allCases.count == 3)
        precondition(WheelSize.compact.scale < WheelSize.standard.scale)
        precondition(WheelSize.large.scale > WheelSize.standard.scale)
        precondition(WheelSurface.allCases.count == 2)
        precondition(MotionChoice.allCases.count == 3)

        // Tool ordering and hidden tools
        let settingsTools = AppSettings.shared
        let originalOrder = settingsTools.toolOrder
        let originalHidden = settingsTools.hiddenTools
        settingsTools.toolOrder = [ToolID.editImage.rawValue, ToolID.compress.rawValue]
        settingsTools.hiddenTools = [ToolID.compress.rawValue]
        let orderedTools = settingsTools.orderedTools([ToolID.compress, ToolID.editImage, ToolID.cropImage])
        let allBefore = settingsTools.allToolsInOrder
        let cropIndex = allBefore.firstIndex(of: .cropImage)!
        settingsTools.moveTool(.cropImage, offset: -1)
        let allAfter = settingsTools.allToolsInOrder
        let movedIndex = allAfter.firstIndex(of: .cropImage)!
        settingsTools.toolOrder = originalOrder
        settingsTools.hiddenTools = originalHidden
        precondition(orderedTools == [.editImage, .cropImage], "tool order: \(orderedTools)")
        precondition(movedIndex == cropIndex - 1, "move up: \(cropIndex) -> \(movedIndex)")

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
