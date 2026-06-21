import SwiftUI

// MARK: - Animated Mesh Gradient View

@available(iOS 18.0, *)
struct AnimatedMeshGradientView: View {
    @State private var isAnimating = false
    var colors: [Color] = [
        .appPrimary, .appAccent, Color(red: 0.15, green: 0.1, blue: 0.35),
        .appAccent.opacity(0.7), .appPrimary.opacity(0.5), Color(red: 0.1, green: 0.2, blue: 0.4),
        Color(red: 0.05, green: 0.1, blue: 0.25), .appPrimary.opacity(0.3), Color(red: 0.08, green: 0.15, blue: 0.3)
    ]

    var body: some View {
        MeshGradient(
            width: 3, height: 3,
            points: [
                [0.0, 0.0], [0.5, 0.0], [1.0, 0.0],
                [isAnimating ? 0.0 : 0.1, 0.5], [isAnimating ? 0.8 : 0.3, isAnimating ? 0.3 : 0.7], [isAnimating ? 0.9 : 1.0, 0.5],
                [0.0, 1.0], [0.5, 1.0], [1.0, 1.0]
            ],
            colors: colors
        )
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.easeInOut(duration: 5).repeatForever(autoreverses: true)) {
                isAnimating = true
            }
        }
    }
}

// MARK: - Aurora Background View

struct AuroraBackgroundView: View {
    @State private var phase: CGFloat = 0
    let colors: [Color]

    init(colors: [Color] = [.appPrimary, .appAccent, .purple.opacity(0.6)]) {
        self.colors = colors
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30)) { timeline in
            let now = timeline.date.timeIntervalSinceReferenceDate
            Canvas { context, size in
                // Draw 4 large blurred orbs that slowly move
                let orbs: [(color: Color, baseX: CGFloat, baseY: CGFloat, radius: CGFloat, speed: Double)] = [
                    (colors[0 % colors.count], 0.3, 0.3, size.width * 0.5, 0.3),
                    (colors[1 % colors.count], 0.7, 0.4, size.width * 0.45, 0.25),
                    (colors[2 % colors.count], 0.5, 0.7, size.width * 0.55, 0.35),
                    (colors[0 % colors.count].opacity(0.5), 0.2, 0.6, size.width * 0.4, 0.2),
                ]

                for orb in orbs {
                    let x = size.width * orb.baseX + sin(now * orb.speed) * size.width * 0.15
                    let y = size.height * orb.baseY + cos(now * orb.speed * 0.8) * size.height * 0.1

                    let rect = CGRect(
                        x: x - orb.radius / 2,
                        y: y - orb.radius / 2,
                        width: orb.radius,
                        height: orb.radius
                    )

                    context.opacity = 0.4
                    context.addFilter(.blur(radius: orb.radius * 0.4))
                    context.fill(
                        Circle().path(in: rect),
                        with: .color(orb.color)
                    )
                }
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}

// MARK: - Breathing Glow Border

struct BreathingGlowBorder: ViewModifier {
    let colors: [Color]
    let lineWidth: CGFloat
    let cornerRadius: CGFloat
    @State private var rotation: Double = 0
    @State private var glowOpacity: Double = 0.6

    init(
        colors: [Color] = [.appPrimary, .appAccent, .purple, .appPrimary],
        lineWidth: CGFloat = 3,
        cornerRadius: CGFloat = AppCornerRadius.lg
    ) {
        self.colors = colors
        self.lineWidth = lineWidth
        self.cornerRadius = cornerRadius
    }

    func body(content: Content) -> some View {
        content
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(
                        AngularGradient(
                            gradient: Gradient(colors: colors),
                            center: .center,
                            angle: .degrees(rotation)
                        ),
                        lineWidth: lineWidth
                    )
                    .blur(radius: 4)
                    .opacity(glowOpacity)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(
                        AngularGradient(
                            gradient: Gradient(colors: colors),
                            center: .center,
                            angle: .degrees(rotation)
                        ),
                        lineWidth: lineWidth * 0.5
                    )
                    .opacity(glowOpacity + 0.2)
            )
            .onAppear {
                withAnimation(.linear(duration: 4).repeatForever(autoreverses: false)) {
                    rotation = 360
                }
                withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                    glowOpacity = 1.0
                }
            }
    }
}

extension View {
    func breathingGlow(
        colors: [Color] = [.appPrimary, .appAccent, .purple, .appPrimary],
        lineWidth: CGFloat = 3,
        cornerRadius: CGFloat = AppCornerRadius.lg
    ) -> some View {
        modifier(BreathingGlowBorder(colors: colors, lineWidth: lineWidth, cornerRadius: cornerRadius))
    }
}
