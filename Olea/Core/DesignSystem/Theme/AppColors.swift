//
//  AppColors.swift
//  DocGenieAI
//
//  Role: Single source of truth for the app's color palette. All UI code
//  should reference these tokens (Color.appPrimary, etc.) rather than raw
//  RGB values, so palette refreshes are one-file changes.
//
//  Conventions:
//    • app* prefix marks design-system tokens; system colors keep their
//      Apple names.
//    • Adaptive tokens (backgrounds, text, borders) use UIColor closures so
//      they auto-flip with dark/light mode. Accent colors are the same in
//      both modes — they're brand, not surface.
//    • appAccent shifted from cyan (#06B6D4) → sunset pink (#F472BE) in the
//      2026 refresh to harmonize with the iridescent AI shimmer rim.
//      appAccentCyan retained as a secondary accent for non-AI surfaces.
//    • appAIViolet / appAITeal are used inside MeshGradient + AIShimmerRim
//      and aren't typically referenced from individual views.
//

import SwiftUI
import UIKit

extension Color {
    // MARK: - Accent Colors (same in both modes)
    //
    // 2026 refresh: the AI gradient pivots from indigo→cyan (techy, 2023-style)
    // to indigo→sunset-pink (premium, matches the iridescent shimmer rim). Cyan
    // stays as a secondary accent for non-AI surfaces (file types, info chips).
    static let appPrimary = Color(red: 0.388, green: 0.400, blue: 0.945)       // #6366F1 indigo
    static let appPrimaryLight = Color(red: 0.506, green: 0.549, blue: 0.973)  // #818CF8 soft indigo
    static let appAccent = Color(red: 0.957, green: 0.451, blue: 0.745)        // #F472BE sunset pink (NEW)
    static let appAccentCyan = Color(red: 0.024, green: 0.714, blue: 0.831)    // #06B6D4 (was appAccent; kept as secondary)
    static let appAIViolet = Color(red: 0.553, green: 0.404, blue: 0.957)      // #8D67F4 violet — for AI shimmer
    static let appAITeal = Color(red: 0.176, green: 0.808, blue: 0.792)        // #2DCECA teal — for AI shimmer
    static let appSuccess = Color(red: 0.063, green: 0.725, blue: 0.506)       // #10B981
    static let appWarning = Color(red: 0.961, green: 0.620, blue: 0.043)       // #F59E0B
    static let appDanger = Color(red: 0.937, green: 0.267, blue: 0.267)        // #EF4444

    // MARK: - Adaptive Background Colors
    //
    // Backgrounds were #0F172A (very cold navy) → warmed to #14132D (slight
    // violet tint) to harmonize with the indigo+pink AI palette. Cards lifted
    // similarly so glass blur reads with subtle warmth instead of fluorescent.
    static let appBGDark = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.078, green: 0.075, blue: 0.180, alpha: 1)  // #14132D warm navy
            : UIColor.systemBackground
    })

    static let appBGCard = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.137, green: 0.137, blue: 0.255, alpha: 1)  // #232341 warm slate
            : UIColor.secondarySystemBackground
    })

    static let appBGElevated = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.149, green: 0.196, blue: 0.278, alpha: 1)  // #263247
            : UIColor.tertiarySystemBackground
    })

    // MARK: - Adaptive Text Colors
    static let appText = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.945, green: 0.961, blue: 0.976, alpha: 1)  // #F1F5F9
            : UIColor.label
    })

    static let appTextMuted = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.580, green: 0.639, blue: 0.722, alpha: 1)  // #94A3B8
            : UIColor.secondaryLabel
    })

    static let appTextDim = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.392, green: 0.455, blue: 0.545, alpha: 1)  // #64748B
            : UIColor.tertiaryLabel
    })

    // MARK: - Adaptive Border & Effects
    static let appBorder = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.200, green: 0.255, blue: 0.333, alpha: 1)  // #334155
            : UIColor.separator
    })

    static let appAIBubbleBG = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.130, green: 0.165, blue: 0.250, alpha: 1)
            : UIColor(red: 0.930, green: 0.935, blue: 0.970, alpha: 1)  // Light indigo tint
    })

    static let appGlassStroke = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor.white.withAlphaComponent(0.12)
            : UIColor.black.withAlphaComponent(0.08)
    })

    // MARK: - Gradients (same in both modes - they use accent colors)
    //
    // Primary gradient: indigo → sunset pink. Reads as warm, premium, AI-y.
    // Use appGradientAI for any surface that is AI-produced or AI-affordant.
    static let appGradientPrimary = LinearGradient(
        colors: [appPrimary, appAccent],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let appGradientAI = LinearGradient(
        colors: [appPrimary, appAIViolet, appAccent],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let appGradientAccent = LinearGradient(
        colors: [appAccent, appPrimary],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let appGradientSuccess = LinearGradient(
        colors: [appSuccess, Color(red: 0.016, green: 0.820, blue: 0.659)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let appGradientDanger = LinearGradient(
        colors: [appDanger, Color(red: 0.965, green: 0.408, blue: 0.408)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    // MARK: - Interactive State Colors
    static let appPrimaryPressed = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.30, green: 0.31, blue: 0.85, alpha: 1)
            : UIColor(red: 0.30, green: 0.31, blue: 0.85, alpha: 1)
    })

    static let appDisabled = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.25, green: 0.29, blue: 0.37, alpha: 1)
            : UIColor.quaternaryLabel
    })

    static let appOverlay = Color.black.opacity(0.4)

    static let appInputBG = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.10, green: 0.13, blue: 0.20, alpha: 1)
            : UIColor.tertiarySystemFill
    })
}

extension ShapeStyle where Self == Color {
    static var appPrimary: Color { Color.appPrimary }
    static var appAccent: Color { Color.appAccent }
    static var appAccentCyan: Color { Color.appAccentCyan }
    static var appAIViolet: Color { Color.appAIViolet }
    static var appAITeal: Color { Color.appAITeal }
}
