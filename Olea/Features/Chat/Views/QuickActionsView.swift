import SwiftUI

struct QuickActionsView: View {
    let actions: [QuickAction]
    let onTap: (QuickAction) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(actions) { action in
                    Button {
                        HapticManager.light()
                        onTap(action)
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: action.icon)
                                .font(.system(size: 11))
                            Text(LocalizedStringKey(action.label))
                                .font(.appMicro)
                        }
                        .foregroundStyle(Color.appPrimary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.appPrimary.opacity(0.1), in: Capsule())
                    }
                    .buttonStyle(.scale)
                    .accessibilityLabel(action.label)
                    .accessibilityHint("Double tap to \(action.prompt.lowercased())")
                }
            }
            .padding(.horizontal, AppSpacing.md)
        }
        .accessibilityLabel("Quick actions")
    }
}
