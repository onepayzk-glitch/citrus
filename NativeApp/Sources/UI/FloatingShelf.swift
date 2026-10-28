import AppKit
import SwiftUI

/// A lightweight floating shelf that keeps dragged files available across apps.
@MainActor
final class FloatingShelfManager {
    static let shared = FloatingShelfManager()
    private var panels: [UUID: NSPanel] = [:]

    func present(urls: [URL]) {
        guard !urls.isEmpty else { return }
        let id = UUID()
        let view = FloatingShelfView(urls: urls) { [weak self] in self?.close(id) }
        let controller = NSHostingController(rootView: view)
        let panel = NSPanel(contentViewController: controller)
        panel.title = "Float"
        panel.styleMask = [.titled, .closable, .resizable, .nonactivatingPanel, .utilityWindow]
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isReleasedWhenClosed = false
        panel.setContentSize(NSSize(width: 360, height: 460))
        panel.center()
        panel.minSize = NSSize(width: 280, height: 240)
        panels[id] = panel
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
    }

    private func close(_ id: UUID) {
        panels[id]?.close()
        panels.removeValue(forKey: id)
    }
}

private struct FloatingShelfView: View {
    let urls: [URL]
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Label("Float", systemImage: "pin.fill")
                    .font(.headline)
                Spacer()
                Text("\(urls.count) item\(urls.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(12)
            Divider()
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
                    ForEach(urls, id: \.self) { url in
                        HStack(spacing: 10) {
                            Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                                .resizable()
                                .frame(width: 28, height: 28)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(url.lastPathComponent)
                                    .lineLimit(1)
                                Text(url.deletingLastPathComponent().path)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }
                            Spacer(minLength: 0)
                            Button {
                                NSWorkspace.shared.activateFileViewerSelecting([url])
                            } label: {
                                Image(systemName: "folder")
                            }
                            .buttonStyle(.borderless)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .contentShape(Rectangle())
                        .draggable(url)
                    }
                }
                .padding(.vertical, 6)
            }
            Divider()
            HStack {
                Text("Drag an item into another app, or close the shelf to release it.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Close", action: onClose)
                    .keyboardShortcut(.cancelAction)
            }
            .padding(10)
        }
        .frame(minWidth: 280, minHeight: 240)
    }
}
