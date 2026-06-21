import SwiftUI

struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    var buttonTitle: String?
    var action: (() -> Void)?

    var body: some View {
        VStack(spacing: 0) {
            Image(systemName: icon)
                .font(.system(size: 56))
                .foregroundStyle(Color.appTextDim)
                .symbolEffect(.pulse, options: .repeating)

            Spacer().frame(height: AppSpacing.lg)

            Text(title)
                .font(.appH3)
                .foregroundStyle(Color.appText)

            Spacer().frame(height: AppSpacing.sm)

            Text(message)
                .font(.appCaption)
                .foregroundStyle(Color.appTextMuted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, AppSpacing.xl)

            if let buttonTitle, let action {
                Spacer().frame(height: AppSpacing.lg)

                Button(buttonTitle, action: action)
                    .buttonStyle(.borderedProminent)
                    .padding(.horizontal, AppSpacing.xxl)
            }
        }
        .padding(AppSpacing.xl)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title). \(message)")
    }
}
