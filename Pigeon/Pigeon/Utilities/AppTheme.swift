//
//  AppTheme.swift
//  Pigeon
//
//  Created by Colin Teahan on 1/10/26.
//
//  Centralized theme constants for consistent styling.
//

import SwiftUI

enum AppTheme {
    // MARK: - Typography

    enum Fonts {
        static let monoSmall = Font.system(size: 10, design: .monospaced)
        static let mono = Font.system(size: 11, design: .monospaced)
        static let monoBold = Font.system(size: 11, weight: .semibold, design: .monospaced)
        static let monoMedium = Font.system(size: 12, design: .monospaced)
        static let monoLarge = Font.system(size: 13, design: .monospaced)
    }

    // MARK: - Colors

    enum Colors {
        // Syntax highlighting
        static let string = Color.green
        static let number = Color.cyan
        static let boolean = Color.orange
        static let null = Color.secondary
        static let key = Color.purple
        static let url = Color.blue

        // Status indicators
        static let connected = Color.green
        static let connecting = Color.yellow
        static let reconnecting = Color.orange
        static let disconnected = Color.gray.opacity(0.5)
        static let failed = Color.red

        // UI elements
        static let codeBackground = Color.black.opacity(0.2)
        static let expandedBackground = Color.gray.opacity(0.08)
    }

    // MARK: - Spacing

    enum Spacing {
        static let xxs: CGFloat = 2
        static let xs: CGFloat = 4
        static let sm: CGFloat = 6
        static let md: CGFloat = 8
        static let lg: CGFloat = 12
        static let xl: CGFloat = 16
    }

    // MARK: - Corner Radius

    enum CornerRadius {
        static let small: CGFloat = 4
        static let medium: CGFloat = 8
    }
}

// MARK: - View Modifiers

struct MonoTextStyle: ViewModifier {
    var size: Font = AppTheme.Fonts.mono

    func body(content: Content) -> some View {
        content
            .font(size)
            .textSelection(.enabled)
    }
}

struct CodeBlockStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(.horizontal, AppTheme.Spacing.md)
            .padding(.vertical, AppTheme.Spacing.sm)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppTheme.Colors.codeBackground)
            .cornerRadius(AppTheme.CornerRadius.small)
    }
}

extension View {
    func monoText(_ size: Font = AppTheme.Fonts.mono) -> some View {
        modifier(MonoTextStyle(size: size))
    }

    func codeBlockStyle() -> some View {
        modifier(CodeBlockStyle())
    }
}
