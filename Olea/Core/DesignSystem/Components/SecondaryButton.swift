import SwiftUI

struct SecondaryButton: View {
    let title: String
    var icon: String? = nil
    var isLoading: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: {
            HapticManager.medium()
            action()
        }) {
            HStack(spacing: AppSpacing.sm) {
                if isLoading {
                    ProgressView()
                        .tint(.appPrimary)
                } else {
                    if let icon {
                        Image(systemName: icon)
                            .font(.system(size: 15, weight: .semibold))
                    }
                    Text(title)
                        .font(.appH3)
                        .fontWeight(.semibold)
                }
            }
            .foregroundStyle(Color.appPrimary)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(.clear, in: RoundedRectangle(cornerRadius: AppCornerRadius.md))
            .overlay(RoundedRectangle(cornerRadius: AppCornerRadius.md).stroke(Color.appPrimary, lineWidth: 1.5))
            .glow(color: .appPrimary, radius: 4)
        }
        .buttonStyle(.scale)
        .disabled(isLoading)
        .opacity(isLoading ? 0.8 : 1)
        .accessibilityLabel(title)
        .accessibilityHint(isLoading ? "Loading" : "Double tap to activate")
    }
}
