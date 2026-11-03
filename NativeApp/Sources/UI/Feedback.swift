import AppKit

/// Sound and haptic feedback shared by conversion, tool and action entry points.
/// Both are controlled by Settings → General → "Sound and haptic feedback".
enum Feedback {
    static var isEnabled: Bool { AppSettings.shared.soundAndHaptics }

    @MainActor static func success() {
        guard isEnabled else { return }
        if let sound = AppSettings.shared.soundChoice.soundName {
            NSSound(named: sound)?.play()
        }
        NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
    }

    @MainActor static func tick() {
        guard isEnabled else { return }
        NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .drawCompleted)
    }
}
