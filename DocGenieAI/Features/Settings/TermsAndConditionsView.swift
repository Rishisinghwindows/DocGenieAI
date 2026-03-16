import SwiftUI

struct TermsAndConditionsView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.lg) {
                    section(title: "Agreement to Terms") {
                        "By downloading, installing, or using DocSage (the \"App\"), you agree to be bound by these Terms and Conditions. If you do not agree to these terms, please do not use the App. We reserve the right to update or modify these terms at any time, and your continued use of the App constitutes acceptance of any changes."
                    }

                    section(title: "Use License") {
                        "We grant you a limited, non-exclusive, non-transferable, revocable license to use the App for personal, non-commercial purposes on any Apple device you own or control. You may not copy, modify, distribute, sell, or lease any part of the App. You may not reverse-engineer or attempt to extract the source code of the App, unless applicable laws prohibit these restrictions."
                    }

                    section(title: "Disclaimer") {
                        "The App is provided on an \"as-is\" and \"as-available\" basis. We make no warranties, expressed or implied, regarding the accuracy, reliability, or availability of the App or any content processed through it. Document processing results, including OCR and AI-generated summaries, may contain inaccuracies and should be reviewed before use in any official capacity."
                    }

                    section(title: "Limitations of Liability") {
                        "In no event shall DocSage or its developers be liable for any indirect, incidental, special, consequential, or punitive damages arising out of or related to your use of the App. This includes but is not limited to loss of data, loss of revenue, or damage to documents. Our total liability shall not exceed the amount you paid, if any, for accessing the App."
                    }

                    section(title: "Governing Law") {
                        "These Terms shall be governed by and construed in accordance with the laws of the jurisdiction in which the developer operates, without regard to conflict of law principles. Any disputes arising under these Terms shall be resolved in the competent courts of that jurisdiction."
                    }

                    Text("Last updated: March 2026")
                        .font(.appCaption)
                        .foregroundStyle(Color.appTextDim)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, AppSpacing.md)

                    Spacer(minLength: AppSpacing.xxl)
                }
                .padding(.horizontal, AppSpacing.md)
                .padding(.top, AppSpacing.md)
            }
            .background(Color.appBGDark)
            .navigationTitle("Terms & Conditions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(.appH3)
                        .foregroundStyle(Color.appPrimary)
                }
            }
        }
    }

    @ViewBuilder
    private func section(title: String, content: () -> String) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text(title)
                .font(.appH3)
                .foregroundStyle(Color.appText)

            Text(content())
                .font(.appBody)
                .foregroundStyle(Color.appTextMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
