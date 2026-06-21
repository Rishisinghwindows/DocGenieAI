import SwiftUI

struct WelcomeSuggestionCard: View {
    let action: QuickAction
    let onTap: () -> Void

    private var accentColor: Color {
        switch action.label {
        case "Scan": return .cyan
        case "Merge": return .purple
        case "Convert": return .orange
        case "OCR": return .green
        case "Compress": return .pink
        case "Watermark": return .indigo
        default: return .appPrimary
        }
    }

    var body: some View {
        Button(action: {
            HapticManager.light()
            onTap()
        }) {
            VStack(alignment: .leading, spacing: 10) {
                // Icon with colored background
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(accentColor.opacity(0.15))
                        .frame(width: 44, height: 44)
                    Image(systemName: action.icon)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(accentColor)
                }

                Spacer(minLength: 0)

                Text(action.label)
                    .font(.appBody)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.appText)

                Text(action.prompt)
                    .font(.appMicro)
                    .foregroundStyle(Color.appTextDim)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.appBGCard)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(
                                LinearGradient(
                                    colors: [accentColor.opacity(0.4), Color.appBorder],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
                    .shadow(color: accentColor.opacity(0.2), radius: 8, y: 4)
            )
        }
        .buttonStyle(.scale)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(action.label)
        .accessibilityHint("Double tap to \(action.prompt.lowercased())")
    }
}
