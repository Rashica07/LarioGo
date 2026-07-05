//
//  Theme.swift
//  LarioGo
//
//  Created by user on 29.6.26.
//


//
//  Theme.swift
//  LarioGo
//
//  Lake-inspired visual language for Lecco / Lake Como tourism.
//

import SwiftUI

/// Central design tokens. Keeping these in one place enforces a cohesive,
/// government-grade visual identity across every screen.
enum Theme {
    /// Deep Azure — primary brand color (headers, key surfaces).
    static let azure = Color(red: 0x00 / 255, green: 0x4E / 255, blue: 0x64 / 255)
    /// Clear Water Teal — interactive accent (buttons, highlights, pins).
    static let teal = Color(red: 0x25 / 255, green: 0xA1 / 255, blue: 0x8E / 255)
    /// Sand White — light background.
    static let sand = Color(red: 0xF8 / 255, green: 0xF9 / 255, blue: 0xFA / 255)
    /// Warm accent used sparingly for tickets / calls to action.
    static let coral = Color(red: 0xFF / 255, green: 0x8C / 255, blue: 0x61 / 255)

    /// Vertical lake gradient used on hero surfaces and the splash.
    static let lakeGradient = LinearGradient(
        colors: [azure, teal],
        startPoint: .top,
        endPoint: .bottom
    )

    /// Subtle deep gradient for immersive headers.
    static let deepGradient = LinearGradient(
        colors: [
            Color(red: 0x00 / 255, green: 0x3B / 255, blue: 0x4D / 255),
            azure,
            teal,
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    enum Radius {
        static let card: CGFloat = 22
        static let chip: CGFloat = 14
        static let button: CGFloat = 18
    }
}

extension Color {
    /// Adaptive primary text color for content on sand backgrounds.
    static let inkPrimary = Color(red: 0x10 / 255, green: 0x28 / 255, blue: 0x30 / 255)
    static let inkSecondary = Color(red: 0x4A / 255, green: 0x5A / 255, blue: 0x60 / 255)
}
