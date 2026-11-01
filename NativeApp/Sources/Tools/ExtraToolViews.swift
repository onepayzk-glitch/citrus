import AppKit
import SwiftUI

// MARK: - Annotate photo

@MainActor
struct AnnotateImageToolView: View {
    let session: ToolSession
    @State private var image: CGImage?
    @State private var loadError: String?
    @State private var items: [AnnotationItem] = []
    @State private var kind: AnnotationItem.Kind = .box
    @State private var color: AnnotationColor = .red
    @State private var text = ""
    @State private var error: String?

    var body: some View {
        ToolShell(session: session, saveTitle: "Annotate", onSave: save) {
            ZStack {
                if let image {
                    AnnotateCanvas(image: image, items: $items, kind: kind, color: color, text: text)
                } else {
                    LoadingOrError(error: loadError)
                }
            }
        } sidebar: {
            SidebarSection(title: L10n.t("Markup")) {
                Picker("", selection: $kind) {
                    ForEach(AnnotationItem.Kind.allCases) { kind in
                        Label(kind.title, systemImage: kind.symbol).tag(kind)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                if kind == .text || kind == .step {
                    TextField(L10n.t("Text"), text: $text)
                        .textFieldStyle(.roundedBorder)
                }
                Picker("", selection: $color) {
                    ForEach(AnnotationColor.allCases) { option in
                        Text(option.title).tag(option)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
            }
            SidebarSection(title: "Annotations (\(items.count))") {
                if items.isEmpty {
                    Text(L10n.t("Drag on the photo to add the selected markup."))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(items) { item in
                        HStack {
                            Image(systemName: item.kind.symbol)
                            Text(item.text.isEmpty ? item.kind.title : item.text)
                                .lineLimit(1)
                            Spacer()
                            Button {
                                items.removeAll { $0.id == item.id }
                            } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(.borderless)
                        }
                        .font(.callout)
                    }
                    Button(L10n.t("Clear all")) { items.removeAll() }
                        .controlSize(.small)
                }
            }
            if let error {
                Text(error).font(.caption).foregroundStyle(.red)
            }
        }
        .task { load() }
    }

    private func load() {
        do {
            image = try ImageIOBridge.load(session.primary)
        } catch {
            loadError = error.localizedDescription
        }
    }

    private func save() {
        guard let image else { return }
        let rendered = AnnotationRenderer.render(image, items: items)
        let destination = session.outputURL(suffix: "Annotated", ext: "png")
        let items = items
        guard !items.isEmpty else { error = "Add at least one annotation first."; return }
        session.run(title: "Annotating photo", detail: session.primary.lastPathComponent) { progress in
            try ImageIOBridge.write(rendered, to: destination, format: .png)
            progress(1)
            return [destination]
        }
    }
}

private struct AnnotateCanvas: View {
    let image: CGImage
    @Binding var items: [AnnotationItem]
    let kind: AnnotationItem.Kind
    let color: AnnotationColor
    let text: String

    private var nsImage: NSImage { ImageOps.nsImage(image) }

    var body: some View {
        GeometryReader { proxy in
            let fit = FitGeometry(container: proxy.size, image: CGSize(width: image.width, height: image.height))
            ZStack(alignment: .topLeading) {
                CheckerboardBackground()
                Image(nsImage: nsImage)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: fit.displayRect.width, height: fit.displayRect.height)
                    .offset(x: fit.displayRect.minX, y: fit.displayRect.minY)
                Canvas { context, _ in
                    for (index, item) in items.enumerated() {
                        draw(item, number: index + 1, in: &context, fit: fit)
                    }
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 2)
                    .onEnded { value in
                        let start = fit.toImage(value.startLocation)
                        let end = fit.toImage(value.location)
                        var rect = CGRect(
                            x: min(start.x, end.x), y: min(start.y, end.y),
                            width: abs(end.x - start.x), height: abs(end.y - start.y)
                        )
                        if rect.width < 6 || rect.height < 6 {
                            rect = CGRect(x: end.x - 24, y: end.y - 24, width: 48, height: 48)
                        }
                        let item = AnnotationItem(kind: kind, rect: rect, text: text, color: color)
                        items.append(item)
                    }
            )
        }
        .clipShape(RoundedRectangle(cornerRadius: Theme.cardCorner, style: .continuous))
    }

    private func draw(_ item: AnnotationItem, number: Int, in context: inout GraphicsContext, fit: FitGeometry) {
        let rect = fit.toDisplay(item.rect)
        let tint = item.color.swiftUI
        switch item.kind {
        case .box:
            context.fill(Path(roundedRect: rect, cornerRadius: 3), with: .color(tint.opacity(0.14)))
            context.stroke(Path(roundedRect: rect, cornerRadius: 3), with: .color(tint), lineWidth: 2)
        case .highlight:
            context.fill(Path(rect), with: .color(.yellow.opacity(0.38)))
        case .arrow:
            var path = Path()
            let start = CGPoint(x: rect.minX, y: rect.maxY)
            let end = CGPoint(x: rect.maxX, y: rect.minY)
            path.move(to: start)
            path.addLine(to: end)
            let angle = atan2(end.y - start.y, end.x - start.x)
            let head: CGFloat = 12
            for offset in [CGFloat.pi * 0.75, -CGFloat.pi * 0.75] {
                path.move(to: end)
                path.addLine(to: CGPoint(x: end.x + cos(angle + offset) * head, y: end.y + sin(angle + offset) * head))
            }
            context.stroke(path, with: .color(tint), lineWidth: 2.5)
        case .text:
            context.draw(
                Text(item.text.isEmpty ? "Text" : item.text)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(tint),
                at: CGPoint(x: rect.minX, y: rect.minY),
                anchor: .topLeading
            )
        case .step:
            let center = CGPoint(x: rect.midX, y: rect.midY)
            let radius = max(12, min(rect.width, rect.height) / 2)
            context.fill(Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)), with: .color(tint))
            context.draw(
                Text("\(number)").font(.system(size: radius, weight: .bold)).foregroundColor(.white),
                at: center,
                anchor: .center
            )
        }
    }
}

// MARK: - Mute video

@MainActor
struct MuteVideoToolView: View {
    let session: ToolSession

    var body: some View {
        FormShell(session: session, saveTitle: "Remove Audio", onSave: save) {
            FormHeading(L10n.t("Remove audio"))
            Text("Exports a new copy of \(session.primary.lastPathComponent) with every audio track removed. The original file is not changed.")
                .foregroundStyle(.secondary)
            Text("Output keeps the original video dimensions and frame rate. A new file named “\(session.baseName) Muted.mp4” is saved next to the original.")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }

    private func save() {
        let destination = session.outputURL(suffix: "Muted", ext: "mp4")
        session.run(title: "Muting video", detail: session.primary.lastPathComponent) { progress in
            try await VideoOps.removeAudio(session.primary, to: destination, progress: progress)
            return [destination]
        }
    }
}

// MARK: - Extract archive

@MainActor
struct ExtractArchiveToolView: View {
    let session: ToolSession
    @State private var error: String?

    var body: some View {
        FormShell(session: session, saveTitle: "Extract", onSave: save) {
            FormHeading(L10n.t("Extract archive"))
            Text(session.primary.lastPathComponent)
                .font(.title3.weight(.semibold))
            Text(L10n.t("The archive is unpacked into a new folder named “Extracted” beside it. The original archive is not changed."))
                .foregroundStyle(.secondary)
            Text(L10n.t("RAR archives use the system bsdtar; if your archive needs a different extractor, install `unar` first."))
                .font(.callout)
                .foregroundStyle(.secondary)
            if let error { Text(error).foregroundStyle(.red) }
        }
    }

    private func save() {
        let directory = ConversionMatrix.uniqueDirectory(directory: session.outputDirectory, name: "Extracted")
        let format = session.primaryFormat
        session.run(title: "Extracting archive", detail: session.primary.lastPathComponent) { progress in
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try await ArchiveEngine().extract(session.primary, format: format, into: directory)
            progress(1)
            NSWorkspace.shared.activateFileViewerSelecting([directory])
            return [directory]
        }
    }
}

// MARK: - Read QR codes

@MainActor
struct ReadQRCodeToolView: View {
    let session: ToolSession
    @State private var results: [QRReader.Result] = []
    @State private var error: String?
    @State private var copied = false

    var body: some View {
        FormShell(session: session, saveTitle: "Done", saveEnabled: true, onSave: { ToolWindowManager.shared.close(session) }) {
            FormHeading(L10n.t("QR codes"))
            if let error {
                Text(error).foregroundStyle(.red)
            } else if results.isEmpty {
                HStack {
                    ProgressView()
                    Text(L10n.t("Reading codes…")).foregroundStyle(.secondary)
                }
            } else {
                ForEach(results) { result in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(result.payload)
                            .font(.body)
                            .textSelection(.enabled)
                        Button(L10n.t("Copy")) {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(result.payload, forType: .string)
                            copied = true
                        }
                        .controlSize(.small)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .card()
                }
            }
            if copied { Text(L10n.t("Copied to the clipboard.")).font(.caption).foregroundStyle(.secondary) }
        }
        .task { read() }
    }

    private func read() {
        do {
            results = try QRReader.read(session.primary)
            if results.isEmpty { error = "No QR code was found in this image." }
        } catch {
            self.error = error.localizedDescription
        }
    }
}
