//
//  PressableScaleStyle.swift
//  LarioGo
//
//  Created by user on 29.6.26.
//


//
//  PressableScale.swift
//  LarioGo
//

import SwiftUI
import UIKit

/// A button style that scales with a spring and fires light haptic feedback
/// on press — the "app-like" physical response that signals premium quality.
struct PressableScaleStyle: ButtonStyle {
    var scale: CGFloat = 0.95

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, isPressed in
                if isPressed { Haptics.tap() }
            }
    }
}

extension ButtonStyle where Self == PressableScaleStyle {
    static var pressableScale: PressableScaleStyle { PressableScaleStyle() }
    static func pressableScale(_ scale: CGFloat) -> PressableScaleStyle {
        PressableScaleStyle(scale: scale)
    }
}

/// Lightweight haptics facade.
enum Haptics {
    static func tap() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }

    static func success() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }

    static func selection() {
        UISelectionFeedbackGenerator().selectionChanged()
    }
}
