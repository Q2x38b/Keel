import SwiftUI
import UIKit

/// A centralized haptic feedback manager providing tasteful, thoughtful feedback
/// throughout the app. Designed to enhance UX without being annoying.
///
/// Design Philosophy:
/// - Selection changes: Ultra-light feedback (selection generator)
/// - Button taps: Light feedback (light impact)
/// - Important actions: Medium feedback (medium impact)
/// - Success/errors: Notification feedback (success/error)
/// - Special moments: Rigid/soft impacts for texture
final class HapticManager {
    static let shared = HapticManager()

    // MARK: - Feedback Generators (pre-prepared for responsiveness)
    private let lightImpact = UIImpactFeedbackGenerator(style: .light)
    private let mediumImpact = UIImpactFeedbackGenerator(style: .medium)
    private let heavyImpact = UIImpactFeedbackGenerator(style: .heavy)
    private let rigidImpact = UIImpactFeedbackGenerator(style: .rigid)
    private let softImpact = UIImpactFeedbackGenerator(style: .soft)
    private let selectionFeedback = UISelectionFeedbackGenerator()
    private let notificationFeedback = UINotificationFeedbackGenerator()

    private init() {
        prepareGenerators()
    }

    /// Pre-warms the haptic engines for more responsive feedback
    func prepareGenerators() {
        lightImpact.prepare()
        mediumImpact.prepare()
        selectionFeedback.prepare()
        notificationFeedback.prepare()
    }

    // MARK: - Selection & Navigation

    /// For tab switches, day selection, picker changes
    /// Ultra-subtle, like brushing past options
    func selection() {
        selectionFeedback.selectionChanged()
        selectionFeedback.prepare()
    }

    /// For confirming a selection (e.g., picking a color, selecting a location)
    func selectionConfirm() {
        softImpact.impactOccurred(intensity: 0.5)
        softImpact.prepare()
    }

    // MARK: - Button Interactions

    /// Standard button tap - light and crisp
    func buttonTap() {
        lightImpact.impactOccurred(intensity: 0.6)
        lightImpact.prepare()
    }

    /// Primary action button (e.g., "Add Class", "Save")
    func primaryAction() {
        mediumImpact.impactOccurred(intensity: 0.7)
        mediumImpact.prepare()
    }

    /// Floating action button - slightly more prominent
    func floatingAction() {
        rigidImpact.impactOccurred(intensity: 0.6)
        rigidImpact.prepare()
    }

    // MARK: - Feedback States

    /// Task completed successfully (save, add, create)
    func success() {
        notificationFeedback.notificationOccurred(.success)
        notificationFeedback.prepare()
    }

    /// Something went wrong
    func error() {
        notificationFeedback.notificationOccurred(.error)
        notificationFeedback.prepare()
    }

    /// Warning or confirmation needed
    func warning() {
        notificationFeedback.notificationOccurred(.warning)
        notificationFeedback.prepare()
    }

    // MARK: - Gestures & Context

    /// Long press recognized - confirms the gesture landed
    func longPress() {
        mediumImpact.impactOccurred(intensity: 0.8)
        mediumImpact.prepare()
    }

    /// Context menu appearing
    func contextMenu() {
        rigidImpact.impactOccurred(intensity: 0.5)
        rigidImpact.prepare()
    }

    /// Drag/swipe threshold crossed
    func threshold() {
        lightImpact.impactOccurred(intensity: 0.4)
        lightImpact.prepare()
    }

    // MARK: - Sheet & Modal Interactions

    /// Sheet expanded to new detent
    func sheetSnap() {
        softImpact.impactOccurred(intensity: 0.4)
        softImpact.prepare()
    }

    /// Modal/sheet dismissed
    func dismiss() {
        softImpact.impactOccurred(intensity: 0.3)
        softImpact.prepare()
    }

    // MARK: - Toggle & Switch

    /// Toggle switched on/off
    func toggle() {
        rigidImpact.impactOccurred(intensity: 0.5)
        rigidImpact.prepare()
    }

    // MARK: - Special Moments

    /// Something delightful happened (e.g., first class added)
    func celebration() {
        // A nice double-tap feeling
        DispatchQueue.main.async {
            self.mediumImpact.impactOccurred(intensity: 0.6)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.lightImpact.impactOccurred(intensity: 0.4)
            self.lightImpact.prepare()
            self.mediumImpact.prepare()
        }
    }

    /// Map centered/focused on location
    func mapFocus() {
        softImpact.impactOccurred(intensity: 0.4)
        softImpact.prepare()
    }

    /// Delete action confirmed
    func delete() {
        heavyImpact.impactOccurred(intensity: 0.6)
        heavyImpact.prepare()
    }
}

// MARK: - SwiftUI View Extension for Easy Access

extension View {
    /// Adds haptic feedback to any view's tap gesture
    func hapticTap(_ style: HapticStyle = .button) -> some View {
        self.simultaneousGesture(
            TapGesture().onEnded { _ in
                switch style {
                case .button:
                    HapticManager.shared.buttonTap()
                case .selection:
                    HapticManager.shared.selection()
                case .primary:
                    HapticManager.shared.primaryAction()
                case .floating:
                    HapticManager.shared.floatingAction()
                }
            }
        )
    }
}

enum HapticStyle {
    case button
    case selection
    case primary
    case floating
}

// MARK: - Haptic Button Style

/// A button style that combines scale animation with haptic feedback
struct HapticButtonStyle: ButtonStyle {
    var hapticStyle: HapticStyle = .button
    var scaleEffect: CGFloat = 0.95

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scaleEffect : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, isPressed in
                if isPressed {
                    switch hapticStyle {
                    case .button:
                        HapticManager.shared.buttonTap()
                    case .selection:
                        HapticManager.shared.selection()
                    case .primary:
                        HapticManager.shared.primaryAction()
                    case .floating:
                        HapticManager.shared.floatingAction()
                    }
                }
            }
    }
}

/// A button style for floating action buttons with haptic feedback
struct HapticFloatingButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, isPressed in
                if isPressed {
                    HapticManager.shared.floatingAction()
                }
            }
    }
}

/// A button style for selection items (days, colors, etc.)
struct HapticSelectionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.7 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, isPressed in
                if isPressed {
                    HapticManager.shared.selection()
                }
            }
    }
}
