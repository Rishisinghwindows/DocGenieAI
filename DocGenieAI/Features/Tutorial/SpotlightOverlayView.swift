import SwiftUI

struct SpotlightOverlayView: View {
    @Binding var currentStep: Int
    @Binding var isShowing: Bool
    let anchors: [TutorialTarget: CGRect]

    private let steps = TutorialStep.steps
    private let spotlightPadding: CGFloat = 8

    private var activeStep: TutorialStep? {
        guard currentStep >= 0, currentStep < steps.count else { return nil }
        return steps[currentStep]
    }

    private var targetFrame: CGRect {
        guard let step = activeStep, let frame = anchors[step.target] else {
            return .zero
        }
        return frame.insetBy(dx: -spotlightPadding, dy: -spotlightPadding)
    }

    private var isLastStep: Bool {
        currentStep >= steps.count - 1
    }

    private var tooltipAbove: Bool {
        targetFrame.midY > UIScreen.main.bounds.height / 2
    }

    var body: some View {
        ZStack {
            // Semi-transparent backdrop with spotlight cutout
            Canvas { context, size in
                context.fill(
                    Path(CGRect(origin: .zero, size: size)),
                    with: .color(Color.black.opacity(0.75))
                )
                context.blendMode = .destinationOut
                let cutoutRect = targetFrame
                let path = Path(roundedRect: cutoutRect, cornerRadius: AppCornerRadius.md)
                context.fill(path, with: .color(.white))
            }
            .compositingGroup()
            .ignoresSafeArea()
            .allowsHitTesting(false)

            // Glowing ring around spotlight
            if targetFrame != .zero {
                RoundedRectangle(cornerRadius: AppCornerRadius.md)
                    .stroke(Color.appPrimary, lineWidth: 2)
                    .glow(color: .appPrimary, radius: 10)
                    .frame(width: targetFrame.width, height: targetFrame.height)
                    .position(x: targetFrame.midX, y: targetFrame.midY)
                    .allowsHitTesting(false)
            }

            // Tooltip card
            if let step = activeStep {
                tooltipCard(step: step)
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
        }
        .animation(.spring(response: 0.45, dampingFraction: 0.8), value: currentStep)
    }

    // MARK: - Tooltip Card

    @ViewBuilder
    private func tooltipCard(step: TutorialStep) -> some View {
        let screenWidth = UIScreen.main.bounds.width

        VStack(spacing: AppSpacing.md) {
            HStack(alignment: .top, spacing: AppSpacing.md) {
                GlowingIcon(
                    systemName: step.icon,
                    color: .appPrimary,
                    size: 20,
                    bgSize: 40
                )

                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text(step.title)
                        .font(.appH3)
                        .foregroundStyle(Color.appText)

                    Text(step.description)
                        .font(.appBody)
                        .foregroundStyle(Color.appTextMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }

            HStack {
                Text("\(currentStep + 1) of \(steps.count)")
                    .font(.appCaption)
                    .foregroundStyle(Color.appTextDim)

                Spacer()

                Button {
                    HapticManager.light()
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        isShowing = false
                    }
                } label: {
                    Text("Skip")
                        .font(.appBody)
                        .foregroundStyle(Color.appTextMuted)
                }
                .accessibilityLabel("Skip tutorial")

                Button {
                    HapticManager.medium()
                    if isLastStep {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            isShowing = false
                        }
                    } else {
                        withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
                            currentStep += 1
                        }
                    }
                } label: {
                    Text(isLastStep ? "Get Started" : "Next")
                        .font(.appH3)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, AppSpacing.lg)
                        .padding(.vertical, AppSpacing.sm)
                        .background(Color.appGradientPrimary, in: Capsule())
                        .glow(color: .appPrimary, radius: 6)
                }
                .accessibilityLabel(isLastStep ? "Get Started" : "Next step")
            }
        }
        .padding(AppSpacing.md)
        .glassCard()
        .padding(.horizontal, AppSpacing.lg)
        .frame(maxWidth: screenWidth)
        .position(
            x: screenWidth / 2,
            y: tooltipYPosition
        )
    }

    private var tooltipYPosition: CGFloat {
        let estimatedTooltipHeight: CGFloat = 140
        let margin: CGFloat = AppSpacing.md
        if tooltipAbove {
            return targetFrame.minY - estimatedTooltipHeight / 2 - margin
        } else {
            return targetFrame.maxY + estimatedTooltipHeight / 2 + margin
        }
    }
}
