import SwiftUI

struct PrimaryButton: View {
    /// LocalizedStringKey so callers' string literals flow through the
    /// catalog. A plain String would have silently bypassed localization
    /// for every primary CTA in the app.
    let title: LocalizedStringKey
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
                        .tint(.white)
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
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(Color.appGradientPrimary, in: RoundedRectangle(cornerRadius: AppCornerRadius.md))
            .shadow(color: .appPrimary.opacity(0.3), radius: 8, y: 4)
        }
        .buttonStyle(.scale)
        .disabled(isLoading)
        .opacity(isLoading ? 0.8 : 1)
        .accessibilityLabel(Text(title))
        .accessibilityHint(isLoading ? "Loading" : "Double tap to activate")
    }
}
