import SwiftUI

struct TypingIndicator: View {
    @State private var dot1Scale: CGFloat = 0.5
    @State private var dot2Scale: CGFloat = 0.5
    @State private var dot3Scale: CGFloat = 0.5

    var body: some View {
        HStack(spacing: 4) {
            DotView(scale: dot1Scale)
            DotView(scale: dot2Scale)
            DotView(scale: dot3Scale)
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, 12)
        .background(Color.appAIBubbleBG, in: RoundedRectangle(cornerRadius: AppCornerRadius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: AppCornerRadius.lg)
                .stroke(Color.appBorder, lineWidth: 1)
        )
        .onAppear { startAnimation() }
        .accessibilityLabel("Olea is typing")
    }

    private func startAnimation() {
        let base = Animation.easeInOut(duration: 0.5).repeatForever(autoreverses: true)
        withAnimation(base) { dot1Scale = 1.0 }
        withAnimation(base.delay(0.15)) { dot2Scale = 1.0 }
        withAnimation(base.delay(0.3)) { dot3Scale = 1.0 }
    }
}

private struct DotView: View {
    let scale: CGFloat

    var body: some View {
        Circle()
            .fill(Color.appTextMuted)
            .frame(width: 8, height: 8)
            .scaleEffect(scale)
    }
}
