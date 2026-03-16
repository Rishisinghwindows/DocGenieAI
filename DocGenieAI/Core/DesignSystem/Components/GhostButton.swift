import SwiftUI

struct GhostButton: View {
    let title: String
    var icon: String? = nil
    let action: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: {
            HapticManager.medium()
            action()
        }) {
            HStack(spacing: AppSpacing.sm) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .semibold))
                }
                Text(title)
                    .font(.appH3)
                    .fontWeight(.semibold)
            }
            .foregroundStyle(Color.appTextMuted)
            .frame(maxWidth: .infinity)
            .frame(height: 44)
        }
        .buttonStyle(.scale)
        .accessibilityLabel(title)
        .accessibilityHint("Double tap to activate")
    }
}
