import SwiftUI
import UIKit

extension Color {
    // MARK: - Accent Colors (same in both modes)
    static let appPrimary = Color(red: 0.388, green: 0.400, blue: 0.945)       // #6366F1
    static let appPrimaryLight = Color(red: 0.506, green: 0.549, blue: 0.973)  // #818CF8
    static let appAccent = Color(red: 0.024, green: 0.714, blue: 0.831)        // #06B6D4
    static let appSuccess = Color(red: 0.063, green: 0.725, blue: 0.506)       // #10B981
    static let appWarning = Color(red: 0.961, green: 0.620, blue: 0.043)       // #F59E0B
    static let appDanger = Color(red: 0.937, green: 0.267, blue: 0.267)        // #EF4444

    // MARK: - Adaptive Background Colors
    static let appBGDark = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.059, green: 0.090, blue: 0.165, alpha: 1)  // #0F172A
            : UIColor.systemBackground
    })

    static let appBGCard = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.118, green: 0.161, blue: 0.231, alpha: 1)  // #1E293B
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
    static let appGradientPrimary = LinearGradient(
        colors: [appPrimary, appAccent],
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
}

extension ShapeStyle where Self == Color {
    static var appPrimary: Color { Color.appPrimary }
    static var appAccent: Color { Color.appAccent }
}
