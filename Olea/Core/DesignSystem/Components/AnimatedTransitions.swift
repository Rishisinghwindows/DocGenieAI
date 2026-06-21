import SwiftUI

// MARK: - ScrollReveal Modifier

struct ScrollRevealModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .scrollTransition(.animated(.spring(duration: 0.4, bounce: 0.15))) { content, phase in
                content
                    .opacity(phase.isIdentity ? 1 : 0)
                    .scaleEffect(phase.isIdentity ? 1 : 0.92)
                    .offset(y: phase.isIdentity ? 0 : 20)
                    .blur(radius: phase.isIdentity ? 0 : 2)
            }
    }
}

// MARK: - Parallax Modifier

struct ParallaxModifier: ViewModifier {
    var speed: CGFloat = 0.3

    func body(content: Content) -> some View {
        content
            .visualEffect { content, geometryProxy in
                content
                    .offset(y: -geometryProxy.frame(in: .global).minY * speed)
            }
    }
}

// MARK: - BouncePress Button Style

struct BounceButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
            .brightness(configuration.isPressed ? -0.05 : 0)
            .animation(.spring(duration: 0.2, bounce: 0.4), value: configuration.isPressed)
    }
}

// MARK: - Floating Modifier

struct FloatingModifier: ViewModifier {
    @State private var isFloating = false
    var yOffset: CGFloat = 6
    var duration: Double = 2.0

    func body(content: Content) -> some View {
        content
            .offset(y: isFloating ? -yOffset : yOffset)
            .animation(.easeInOut(duration: duration).repeatForever(autoreverses: true), value: isFloating)
            .onAppear { isFloating = true }
    }
}

// MARK: - PulseRing View

struct PulseRingView: View {
    let color: Color
    @State private var scale: CGFloat = 0.8
    @State private var opacity: Double = 1.0

    var body: some View {
        Circle()
            .stroke(color, lineWidth: 2)
            .scaleEffect(scale)
            .opacity(opacity)
            .onAppear {
                withAnimation(.easeOut(duration: 1.5).repeatForever(autoreverses: false)) {
                    scale = 2.0
                    opacity = 0.0
                }
            }
    }
}

// MARK: - TypewriterText

struct TypewriterText: View {
    let text: String
    let speed: Double
    @State private var displayedCount: Int = 0

    init(_ text: String, speed: Double = 0.03) {
        self.text = text
        self.speed = speed
    }

    var body: some View {
        Text(String(text.prefix(displayedCount)))
            .onAppear {
                displayedCount = 0
                for i in 1...text.count {
                    DispatchQueue.main.asyncAfter(deadline: .now() + speed * Double(i)) {
                        displayedCount = i
                    }
                }
            }
    }
}

// MARK: - View Extensions

extension View {
    func scrollReveal() -> some View { modifier(ScrollRevealModifier()) }
    func parallax(speed: CGFloat = 0.3) -> some View { modifier(ParallaxModifier(speed: speed)) }
    func floating(yOffset: CGFloat = 6, duration: Double = 2.0) -> some View { modifier(FloatingModifier(yOffset: yOffset, duration: duration)) }
}

extension ButtonStyle where Self == BounceButtonStyle {
    static var bounce: BounceButtonStyle { BounceButtonStyle() }
}
