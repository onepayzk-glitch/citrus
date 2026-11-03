import SwiftUI

// The Liquid Glass API exists only in the macOS 26 SDK. These wrappers keep one
// code base building on older toolchains (macOS 15 Command Line Tools) by
// substituting a translucent material with the same shape.
// shortcut: the SDK is detected via the compiler version (Xcode 26 ships Swift
// 6.2); inline glassEffect again when pre-26 toolchain support is dropped.

extension View {
    /// Liquid Glass surface on macOS 26, translucent material on older systems.
    @ViewBuilder
    func glassSurface<S: Shape>(tint: Color? = nil, interactive: Bool = false, in shape: S) -> some View {
        #if compiler(>=6.2)
        if #available(macOS 26.0, *) {
            switch (tint, interactive) {
            case (nil, false):
                glassEffect(.regular, in: shape)
            case (let tint?, false):
                glassEffect(.regular.tint(tint), in: shape)
            case (let tint?, true):
                glassEffect(.regular.tint(tint).interactive(), in: shape)
            case (nil, true):
                glassEffect(.regular.interactive(), in: shape)
            }
        } else {
            materialSurface(tint: tint, in: shape)
        }
        #else
        materialSurface(tint: tint, in: shape)
        #endif
    }

    /// Translucent stand-in used when the building SDK has no Liquid Glass.
    @ViewBuilder
    private func materialSurface<S: Shape>(tint: Color?, in shape: S) -> some View {
        background {
            ZStack {
                shape.fill(.ultraThinMaterial)
                if let tint {
                    shape.fill(tint.opacity(0.8))
                }
            }
        }
    }
}

extension View {
    /// Wheel surface: Liquid Glass or a solid, higher-contrast background.
    @ViewBuilder
    func wheelSurface<S: Shape>(tint: Color? = nil, selected: Bool = false, in shape: S) -> some View {
        if AppSettings.shared.wheelSurface == .solid {
            background {
                ZStack {
                    shape.fill(Color(nsColor: .windowBackgroundColor).opacity(0.96))
                    if let tint {
                        shape.fill(tint.opacity(selected ? 0.42 : 0.12))
                    }
                    shape.stroke(Color(nsColor: .separatorColor).opacity(0.6), lineWidth: 1)
                }
            }
        } else {
            glassSurface(tint: tint, in: shape)
        }
    }
}

/// Liquid Glass grouping on macOS 26; plain content on older systems.
struct GlassGroup<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        #if compiler(>=6.2)
        if #available(macOS 26.0, *) {
            GlassEffectContainer(spacing: 0) { content }
        } else {
            content
        }
        #else
        content
        #endif
    }
}
