import AppKit
import SwiftUI

/// Central motion policy: follows the system accessibility setting, or the user
/// override in Settings → General → Motion.
enum Motion {
    static var isReduced: Bool {
        switch AppSettings.shared.motionChoice {
        case .system:
            return NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        case .reduced:
            return true
        case .full:
            return false
        }
    }

    static var spring: Animation? {
        isReduced ? nil : .spring(response: 0.28, dampingFraction: 0.78)
    }
}
