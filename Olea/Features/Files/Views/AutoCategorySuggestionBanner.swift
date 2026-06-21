import SwiftUI

struct AutoCategorySuggestionBanner: View {
    let tagName: String
    let onChangeTag: () -> Void
    let onDismiss: () -> Void

    private var fileTag: FileTag? {
        FileTag(rawValue: tagName)
    }

    var body: some View {
        HStack(spacing: 10) {
            // Tag icon and label
            if let tag = fileTag {
                Image(systemName: tag.icon)
                    .font(.appCaption)
                    .foregroundStyle(tag.color)
            }

            Text("Auto-tagged as \"\(tagName)\"")
                .font(.appCaption)
                .foregroundStyle(.secondary)

            Spacer()

            // Change button
            Button {
                HapticManager.light()
                onChangeTag()
            } label: {
                Text("Change")
                    .font(.appMicro)
                    .foregroundStyle(.appPrimary)
            }

            // Dismiss button
            Button {
                HapticManager.light()
                onDismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.appMicro)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .glassCard(cornerRadius: 12)
    }
}

#Preview {
    VStack(spacing: 16) {
        AutoCategorySuggestionBanner(
            tagName: "Invoice",
            onChangeTag: {},
            onDismiss: {}
        )

        AutoCategorySuggestionBanner(
            tagName: "Receipt",
            onChangeTag: {},
            onDismiss: {}
        )

        AutoCategorySuggestionBanner(
            tagName: "Legal",
            onChangeTag: {},
            onDismiss: {}
        )
    }
    .padding()
}
