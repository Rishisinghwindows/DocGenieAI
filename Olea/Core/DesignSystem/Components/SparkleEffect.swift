import SwiftUI

// MARK: - SparkleView

struct SparkleView: View {
    let particleCount: Int
    let colors: [Color]
    @State private var startTime: Date = .now

    init(count: Int = 20, colors: [Color] = [.white, .appPrimary, .appAccent]) {
        self.particleCount = count
        self.colors = colors
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0/30)) { timeline in
            let elapsed = timeline.date.timeIntervalSince(startTime)

            Canvas { context, size in
                for i in 0..<particleCount {
                    let seed = Double(i) * 137.508 // golden angle
                    let x = size.width * CGFloat((sin(seed) + 1) / 2)
                    let y = size.height * CGFloat((cos(seed * 0.7) + 1) / 2)

                    // Twinkle: each particle has its own phase
                    let twinklePhase = sin(elapsed * 2.0 + seed) * 0.5 + 0.5
                    let scale = 0.3 + twinklePhase * 0.7
                    let opacity = 0.2 + twinklePhase * 0.8

                    let sparkleSize = CGFloat(2 + twinklePhase * 4)

                    context.opacity = opacity

                    // Draw a 4-point star
                    let center = CGPoint(x: x, y: y)
                    let starPath = createStarPath(center: center, size: sparkleSize * scale)

                    let colorIndex = i % colors.count
                    context.fill(starPath, with: .color(colors[colorIndex]))
                }
            }
        }
        .allowsHitTesting(false)
        .onAppear { startTime = .now }
    }

    private func createStarPath(center: CGPoint, size: CGFloat) -> Path {
        var path = Path()
        // Horizontal line
        path.move(to: CGPoint(x: center.x - size, y: center.y))
        path.addLine(to: CGPoint(x: center.x + size, y: center.y))
        // Vertical line
        path.move(to: CGPoint(x: center.x, y: center.y - size))
        path.addLine(to: CGPoint(x: center.x, y: center.y + size))
        // Diagonal lines (smaller)
        let diag = size * 0.5
        path.move(to: CGPoint(x: center.x - diag, y: center.y - diag))
        path.addLine(to: CGPoint(x: center.x + diag, y: center.y + diag))
        path.move(to: CGPoint(x: center.x + diag, y: center.y - diag))
        path.addLine(to: CGPoint(x: center.x - diag, y: center.y + diag))
        return path.strokedPath(StrokeStyle(lineWidth: 1, lineCap: .round))
    }
}

// MARK: - RisingParticlesView

struct RisingParticlesView: View {
    let particleCount: Int
    let color: Color
    @State private var startTime: Date = .now

    init(count: Int = 15, color: Color = .appPrimary) {
        self.particleCount = count
        self.color = color
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0/30)) { timeline in
            let elapsed = timeline.date.timeIntervalSince(startTime)

            Canvas { context, size in
                for i in 0..<particleCount {
                    let seed = Double(i) * 97.531
                    let lifetime = 3.0 + fmod(seed, 4.0) // 3-7 seconds per cycle
                    let progress = fmod(elapsed + seed * 0.1, lifetime) / lifetime

                    let x = size.width * CGFloat(fmod(seed / 100, 1.0)) + sin(elapsed * 0.5 + seed) * 20
                    let y = size.height * (1.0 - CGFloat(progress)) // Rise from bottom

                    let particleSize = CGFloat(2 + (1.0 - progress) * 3)
                    let opacity = progress < 0.1 ? progress * 10 :
                                  progress > 0.8 ? (1.0 - progress) * 5 : 1.0

                    context.opacity = opacity * 0.6
                    context.fill(
                        Circle().path(in: CGRect(x: x - particleSize/2, y: y - particleSize/2, width: particleSize, height: particleSize)),
                        with: .color(color)
                    )
                }
            }
        }
        .allowsHitTesting(false)
        .onAppear { startTime = .now }
    }
}

// MARK: - SuccessBurstView

struct SuccessBurstView: View {
    @State private var particles: [BurstParticle] = []
    @State private var startTime: Date = .now
    let color: Color

    init(color: Color = .appSuccess) {
        self.color = color
    }

    var body: some View {
        TimelineView(.animation) { timeline in
            let elapsed = timeline.date.timeIntervalSince(startTime)

            Canvas { context, size in
                let center = CGPoint(x: size.width / 2, y: size.height / 2)

                for particle in particles {
                    let age = elapsed - particle.delay
                    guard age > 0 && age < particle.lifetime else { continue }

                    let progress = age / particle.lifetime
                    let distance = particle.speed * CGFloat(age)
                    let x = center.x + cos(particle.angle) * distance
                    let y = center.y + sin(particle.angle) * distance
                    let opacity = 1.0 - pow(progress, 1.5)
                    let size = particle.size * (1.0 - CGFloat(progress) * 0.5)

                    guard opacity > 0.01 else { continue }

                    context.opacity = opacity
                    context.fill(
                        Circle().path(in: CGRect(x: x - size/2, y: y - size/2, width: size, height: size)),
                        with: .color(particle.color)
                    )
                }
            }
        }
        .allowsHitTesting(false)
        .onAppear {
            startTime = .now
            particles = (0..<24).map { i in
                let angle = (Double(i) / 24.0) * .pi * 2 + Double.random(in: -0.15...0.15)
                return BurstParticle(
                    angle: CGFloat(angle),
                    speed: CGFloat.random(in: 60...150),
                    size: CGFloat.random(in: 3...7),
                    color: [color, color.opacity(0.7), .white.opacity(0.8)].randomElement()!,
                    delay: Double.random(in: 0...0.1),
                    lifetime: Double.random(in: 0.6...1.2)
                )
            }
        }
    }
}

private struct BurstParticle {
    let angle: CGFloat
    let speed: CGFloat
    let size: CGFloat
    let color: Color
    let delay: Double
    let lifetime: Double
}

// MARK: - Sparkle Overlay Modifier

struct SparkleOverlayModifier: ViewModifier {
    let isActive: Bool

    func body(content: Content) -> some View {
        content.overlay {
            if isActive {
                SparkleView(count: 12, colors: [.white.opacity(0.8), .appPrimary.opacity(0.5)])
                    .transition(.opacity)
            }
        }
    }
}

extension View {
    func sparkleOverlay(isActive: Bool) -> some View {
        modifier(SparkleOverlayModifier(isActive: isActive))
    }
}
