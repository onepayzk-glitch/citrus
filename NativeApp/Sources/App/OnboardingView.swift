import AppKit
import SwiftUI

/// First-run guide. Mirrors Tangerine's six-step introduction: welcome, the three
/// drag wheels, privacy, and finish setup. Wording and artwork are this project's own.
@MainActor
final class OnboardingWindowController: NSWindowController {
    static let shared = OnboardingWindowController()

    private init() {
        let view = OnboardingView()
            .environmentObject(AppSettings.shared)
        let controller = NSHostingController(rootView: view)
        let window = NSWindow(contentViewController: controller)
        window.title = "Getting Started"
        window.titlebarAppearsTransparent = true
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false
        window.setContentSize(NSSize(width: 680, height: 540))
        window.center()
        super.init(window: window)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func show() {
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}

private struct OnboardingSlide {
    let kicker: String
    let title: String
    let body: String
    let symbol: String
    let key: String?

    static let all: [OnboardingSlide] = [
        OnboardingSlide(
            kicker: "WELCOME",
            title: "Drop. Tap a key. Done.",
            body: "Open Tangerine lives in the menu bar. Drag files in Finder, tap a modifier while you drag, and pick what you want from the wheel around your pointer.",
            symbol: "arrow.down.right.and.arrow.up.left",
            key: nil
        ),
        OnboardingSlide(
            kicker: "1 · CONVERT",
            title: "Convert formats with ⇧ Shift.",
            body: "Start dragging a file, then hold Shift. The wheel lists every format this file can become. Drop it on one: the converted copy is saved next to the original with a clear name.",
            symbol: "arrow.triangle.2.circlepath",
            key: "⇧"
        ),
        OnboardingSlide(
            kicker: "2 · TOOLS",
            title: "Edit files with ⌘ Command.",
            body: "Hold Command while dragging to see the tools for that file: compress, crop, trim, split, annotate, redact, merge PDFs, and more. Every tool makes a new file and leaves the original alone.",
            symbol: "wrench.and.screwdriver",
            key: "⌘"
        ),
        OnboardingSlide(
            kicker: "3 · ACTIONS",
            title: "Act on files with ⌃ Control.",
            body: "Hold Control while dragging to AirDrop, Float, Copy, Move, copy a path, or open the folder in Terminal. Actions never touch your conversion allowance because there is none.",
            symbol: "doc.on.doc",
            key: "⌃"
        ),
        OnboardingSlide(
            kicker: "PRIVATE BY DESIGN",
            title: "Your files never leave this Mac.",
            body: "Conversions and tools run locally. There is no account, no telemetry, and no upload. Two optional local engines add coverage: FFmpeg for more media codecs and LibreOffice for Office layout fidelity.",
            symbol: "lock.shield",
            key: nil
        ),
    ]
}

struct OnboardingView: View {
    @EnvironmentObject private var settings: AppSettings
    @State private var page = 0

    private var slides: [OnboardingSlide] { OnboardingSlide.all }
    private var isLast: Bool { page == slides.count }

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 22) {
                ZStack {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(Theme.accent.opacity(0.14))
                    Image(systemName: isLast ? "checkmark.seal.fill" : slides[page].symbol)
                        .font(.system(size: 42, weight: .medium))
                        .foregroundStyle(Theme.accent)
                }
                .frame(width: 96, height: 96)

                VStack(alignment: .leading, spacing: 10) {
                    Text(isLast ? L10n.t("FINISH SETUP") : L10n.t(slides[page].kicker))
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .tracking(2)
                        .foregroundStyle(Theme.accent)
                    Text(isLast ? L10n.t("A couple of defaults, then you're set.") : L10n.t(slides[page].title))
                        .font(.system(size: 27, weight: .bold, design: .rounded))
                        .fixedSize(horizontal: false, vertical: true)
                    Text(L10n.t(isLast
                         ? "Open Tangerine stays in the menu bar and starts again after you sign in if you leave that on. You can change every option later in Settings."
                         : slides[page].body))
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    if let key = slides[safe: page]?.key {
                        HStack(spacing: 10) {
                            Text(key)
                                .font(.system(size: 26, weight: .semibold, design: .rounded))
                                .frame(width: 44, height: 44)
                                .background(Theme.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                            Text(L10n.t("Hold while dragging"))
                                .font(.callout)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.top, 2)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 30)
            .padding(.top, 34)

            if isLast {
                VStack(alignment: .leading, spacing: 12) {
                    Toggle(L10n.t("Start automatically at login"), isOn: $settings.launchAtLogin)
                    Toggle(L10n.t("Sound and haptic feedback"), isOn: $settings.soundAndHaptics)
                }
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
                .card()
                .padding(.horizontal, 30)
                .padding(.top, 22)
            }

            Spacer(minLength: 0)

            HStack(spacing: 10) {
                Button(L10n.t("Skip")) { finish() }
                    .controlSize(.large)
                Spacer()
                HStack(spacing: 6) {
                    ForEach(0...slides.count, id: \.self) { index in
                        Circle()
                            .fill(index == page ? Theme.accent : Color.secondary.opacity(0.28))
                            .frame(width: 6, height: 6)
                    }
                }
                Spacer()
                if page > 0 {
                    Button(L10n.t("Back")) { withAnimation(.snappy(duration: 0.2)) { page -= 1 } }
                        .controlSize(.large)
                }
                Button(isLast ? L10n.t("Finish") : L10n.t("Continue")) {
                    if isLast { finish() } else { withAnimation(.snappy(duration: 0.2)) { page += 1 } }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 30)
            .padding(.bottom, 24)
        }
        .frame(width: 680, height: 540)
        .background(
            LinearGradient(colors: [Theme.accent.opacity(0.08), Color(nsColor: .windowBackgroundColor)], startPoint: .topTrailing, endPoint: .bottomLeading)
        )
        .tint(Theme.accent)
    }

    private func finish() {
        UserDefaults.standard.set(true, forKey: "hasCompletedWelcome")
        UserDefaults.standard.set(true, forKey: "hasOpenedSettings")
        OnboardingWindowController.shared.close()
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
