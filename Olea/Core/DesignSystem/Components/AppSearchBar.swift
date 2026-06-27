import SwiftUI

struct AppSearchBar: View {
    @Binding var text: String
    /// LocalizedStringKey (not String) so the placeholder routes through the
    /// catalog. Callers pass string literals which auto-convert.
    var placeholder: LocalizedStringKey = "Search..."

    var body: some View {
        HStack(spacing: AppSpacing.sm) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Color.appTextDim)
                .font(.appBody)

            TextField(placeholder, text: $text)
                .font(.appBody)
                .foregroundStyle(Color.appText)

            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Color.appTextDim)
                }
            }
        }
        .padding(.horizontal, AppSpacing.md)
        .frame(height: 44)
        .background(Color.appBGCard, in: RoundedRectangle(cornerRadius: AppCornerRadius.md))
        .overlay(
            RoundedRectangle(cornerRadius: AppCornerRadius.md)
                .stroke(Color.appBorder, lineWidth: 1)
        )
    }
}
