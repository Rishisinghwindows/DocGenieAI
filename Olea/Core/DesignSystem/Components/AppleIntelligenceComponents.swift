//
//  AppleIntelligenceComponents.swift
//  DocGenieAI
//
//  Role: Reusable visual primitives that give the app its 2026 Apple-
//  Intelligence design vocabulary. These compose into Inbox, Onboarding,
//  Splash, InboxCard, FormAutofill — anywhere the app needs to read as
//  AI-affordant, premium, and current with iOS 26's "Liquid Glass" language.
//
//  Primitives in this file:
//    • AnimatedMeshBackground   — drifting mesh-gradient hero (iOS 18+);
//                                  rotating angular gradient on iOS 17.
//    • AIShimmerRim             — iridescent rotating-border modifier that
//                                  ships around Apple's own AI affordances
//                                  (Mail summary, Notes Writing Tools).
//    • HairlineBorder           — replaces 2019-era drop shadows with a
//                                  single Color.appBorder hairline (matches
//                                  iOS 26 Liquid Glass conventions).
//    • AnimatedSparkles         — canonical "AI is alive" glyph using
//                                  variableColor + contentTransition.
//
//  All primitives source from `AppColors` tokens so a single palette change
//  ripples through every AI surface.
//

import SwiftUI
import simd

// MARK: - Animated Mesh Background
//
// iOS 18+ uses MeshGradient with TimelineView-driven point drift for a true
// living-canvas hero background. iOS 17 falls back to a slow AngularGradient
// rotation so the brand feel is preserved on older devices.

struct AnimatedMeshBackground: View {
    var colors: [Color] = [
        Color.appPrimary,    // indigo
        Color.appAIViolet,   // violet
        Color.appPrimaryLight, // soft indigo
        Color.appAccent,     // sunset pink
        Color.appAITeal      // teal accent
    ]

    var body: some View {
        if #available(iOS 18, *) {
            ModernMesh(colors: colors)
        } else {
            LegacyAngularMesh(colors: colors)
        }
    }
}

@available(iOS 18, *)
private struct ModernMesh: View {
    let colors: [Color]

    var body: some View {
        // 15fps is plenty for a blurred ambient background — halving the
        // frame rate from the original 30fps freed enough CPU for the Tools
        // tab's ScrollView to run at 60Hz on device without stutter.
        TimelineView(.animation(minimumInterval: 1.0 / 15.0)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            MeshGradient(
                width: 3,
                height: 3,
                points: points(at: t),
                colors: tile(colors: colors)
            )
        }
        // .drawingGroup() flattens the mesh into a Metal-backed offscreen
        // texture. Without it, SwiftUI re-diffs the mesh's view tree every
        // frame; with it, the timeline just swaps textures. Big win on
        // screens where the mesh sits behind an interactive ScrollView.
        .drawingGroup()
    }

    private func points(at t: TimeInterval) -> [SIMD2<Float>] {
        // Three control points drift on slow sine waves so the gradient feels
        // alive without being distracting. Frequencies are mutually irrational
        // to avoid synchronized "pumping".
        let mx = 0.5 + 0.18 * Float(sin(t * 0.21))
        let my = 0.5 + 0.18 * Float(cos(t * 0.17))
        let lx = 0.5 + 0.22 * Float(sin(t * 0.13 + 1.2))
        let ly = 0.5 + 0.22 * Float(cos(t * 0.19 + 0.6))
        let rx = 0.5 + 0.15 * Float(sin(t * 0.27 + 2.4))
        let ry = 0.5 + 0.15 * Float(cos(t * 0.23 + 1.8))
        let _ = lx; let _ = ry
        return [
            [0, 0], [0.5, 0], [1, 0],
            [0, 0.5], [mx, my], [1, 0.5],
            [0, 1], [rx, ly], [1, 1]
        ]
    }

    private func tile(colors: [Color]) -> [Color] {
        let c0 = colors[safe: 0] ?? .indigo
        let c1 = colors[safe: 1] ?? .purple
        let c2 = colors[safe: 2] ?? .blue
        let c3 = colors[safe: 3] ?? .pink
        let c4 = colors[safe: 4] ?? .teal
        return [c0, c1, c2,
                c1, c3, c0,
                c4, c0, c1]
    }
}

private struct LegacyAngularMesh: View {
    let colors: [Color]
    @State private var angle: Double = 0

    var body: some View {
        AngularGradient(colors: colors + [colors.first ?? .indigo], center: .center, angle: .degrees(angle))
            .onAppear {
                withAnimation(.linear(duration: 30).repeatForever(autoreverses: false)) {
                    angle = 360
                }
            }
            .blur(radius: 40)
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

// MARK: - Apple-Intelligence Shimmer Rim
//
// The iridescent border that ships around system AI affordances (Mail summary,
// Notes Writing Tools, Image Playground). Subtle when idle, more saturated when
// `isActive` is true (e.g. during a Foundation Models call).

struct AIShimmerRim: ViewModifier {
    var isActive: Bool = true
    var cornerRadius: CGFloat = 22
    var lineWidth: CGFloat = 1.4

    @State private var phase: Double = 0

    func body(content: Content) -> some View {
        content
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(
                        AngularGradient(
                            colors: [
                                Color.appAccent,      // sunset pink
                                Color.appPrimary,     // indigo
                                Color.appAITeal,      // teal
                                Color.appAIViolet,    // violet
                                Color.appAccent       // pink (loop)
                            ],
                            center: .center,
                            angle: .degrees(phase)
                        ),
                        lineWidth: lineWidth
                    )
                    .opacity(isActive ? 0.85 : 0.35)
                    .blur(radius: isActive ? 2 : 1)
            }
            .onAppear {
                withAnimation(.linear(duration: 5).repeatForever(autoreverses: false)) {
                    phase = 360
                }
            }
    }
}

extension View {
    /// Wraps the view in the iridescent Apple-Intelligence rim. Use sparingly,
    /// only on surfaces that initiate or display AI output.
    func aiShimmerRim(isActive: Bool = true, cornerRadius: CGFloat = 22, lineWidth: CGFloat = 1.4) -> some View {
        modifier(AIShimmerRim(isActive: isActive, cornerRadius: cornerRadius, lineWidth: lineWidth))
    }
}

// MARK: - Hairline Border
//
// Drops the 2019 drop-shadow + heavy elevation pattern in favor of a single
// hairline that reads as premium on iOS 26. Replace `.shadow(...)` calls with
// `.hairline(cornerRadius: 16)` for the modern look.

struct HairlineBorder: ViewModifier {
    var cornerRadius: CGFloat = 16
    var opacity: Double = 0.5

    func body(content: Content) -> some View {
        content.overlay {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(Color.appBorder.opacity(opacity), lineWidth: 0.5)
        }
    }
}

extension View {
    func hairline(cornerRadius: CGFloat = 16, opacity: Double = 0.5) -> some View {
        modifier(HairlineBorder(cornerRadius: cornerRadius, opacity: opacity))
    }
}

// MARK: - Sparkles Animator
//
// A canonical "AI is alive" icon: variableColor.iterative.reversing keeps a
// gentle pulse going, while a content transition makes state changes feel
// continuous.

struct AnimatedSparkles: View {
    var size: CGFloat = 18
    var isThinking: Bool = false
    var palette: [Color] = [
        Color(red: 0.40, green: 0.42, blue: 0.95),
        Color(red: 0.20, green: 0.80, blue: 0.85)
    ]

    var body: some View {
        Image(systemName: isThinking ? "sparkles" : "sparkle.magnifyingglass")
            .font(.system(size: size, weight: .medium))
            .symbolEffect(.variableColor.iterative.reversing, options: .repeating)
            .foregroundStyle(
                LinearGradient(colors: palette, startPoint: .topLeading, endPoint: .bottomTrailing)
            )
            .contentTransition(.symbolEffect(.replace.downUp))
    }
}
