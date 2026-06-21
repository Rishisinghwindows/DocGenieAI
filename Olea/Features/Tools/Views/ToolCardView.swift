//
//  ToolCardView.swift
//  Olea
//
//  Premium grid cell for the Tools tab. Glass material + hairline border
//  replace the drop-shadow design. Tools whose `section == "AI Intelligence"`
//  get the iridescent AI shimmer rim + animated sparkle so the AI lane reads
//  visually different from utility tools.
//

import SwiftUI

struct ToolCardView: View {
    let tool: ToolItem
    let action: () -> Void

    @State private var pressed: Bool = false

    /// AI Intelligence tools get the iridescent rim + animated icon.
    private var isAITool: Bool {
        tool.section == "AI Intelligence"
    }

    var body: some View {
        Button {
            HapticManager.light()
            action()
        } label: {
            VStack(spacing: AppSpacing.sm) {
                iconBlock

                Text(tool.rawValue)
                    .font(.appH3)
                    .foregroundStyle(Color.appText)

                Text(tool.description)
                    .font(.appCaption)
                    .foregroundStyle(Color.appTextMuted)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, AppSpacing.lg)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: AppCornerRadius.lg))
            .background(Color.appBGCard.opacity(0.45), in: RoundedRectangle(cornerRadius: AppCornerRadius.lg))
            .modifier(AICardRimIfNeeded(isAI: isAITool))
            .hairline(cornerRadius: AppCornerRadius.lg, opacity: isAITool ? 0 : 0.45)
            .scaleEffect(pressed ? 0.97 : 1.0)
            .animation(.spring(response: 0.28, dampingFraction: 0.75), value: pressed)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(tool.rawValue), \(tool.description)")
        .accessibilityHint("Double tap to open tool")
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in pressed = true }
                .onEnded { _ in pressed = false }
        )
    }

    // MARK: - Icon block

    /// Soft halo + glass disk + tinted glyph. AI tools layer in the variable-color
    /// sparkle effect so the icon feels alive.
    private var iconBlock: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [tool.color.opacity(0.32), .clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: 38
                    )
                )
                .frame(width: 64, height: 64)
                .blur(radius: 6)

            Circle()
                .fill(.ultraThinMaterial)
                .frame(width: 52, height: 52)
                .overlay(Circle().strokeBorder(Color.white.opacity(0.10), lineWidth: 0.5))

            Image(systemName: tool.systemImage)
                .font(.system(size: 26, weight: .medium))
                .foregroundStyle(
                    LinearGradient(
                        colors: isAITool
                            ? [Color.appPrimary, Color.appAccent]
                            : [tool.color, tool.color.opacity(0.7)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .modifier(AISymbolPulseIfNeeded(isAI: isAITool))
        }
    }
}

// MARK: - Conditional modifiers
//
// Wrapping the modifier in a struct keeps the view body's expression simple
// enough for the Swift compiler to type-check quickly, and isolates the
// conditional behavior to one branch each.

private struct AICardRimIfNeeded: ViewModifier {
    let isAI: Bool
    func body(content: Content) -> some View {
        if isAI {
            content.aiShimmerRim(isActive: true, cornerRadius: AppCornerRadius.lg, lineWidth: 0.9)
        } else {
            content
        }
    }
}

private struct AISymbolPulseIfNeeded: ViewModifier {
    let isAI: Bool
    func body(content: Content) -> some View {
        if isAI {
            content.symbolEffect(.variableColor.iterative.reversing, options: .repeating)
        } else {
            content
        }
    }
}
