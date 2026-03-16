import SwiftUI

struct PrivacyPolicyView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.lg) {
                    section(title: "Information Collection") {
                        "DocSage processes all documents entirely on your device. We do not collect, transmit, or store any personal data, documents, or files on external servers. Any AI-powered features, including summarization and text extraction, are performed using on-device processing capabilities provided by the operating system."
                    }

                    section(title: "Use of Data") {
                        "The App accesses files only when you explicitly import or scan them. Document data is stored locally within the App's sandboxed container on your device. We do not access your files for analytics, advertising, or any purpose beyond providing the features you request."
                    }

                    section(title: "Data Security") {
                        "Your documents are protected by the security mechanisms built into iOS, including App Sandbox, Data Protection, and hardware encryption. Files processed by the App remain under your control at all times. We recommend keeping your device passcode enabled and your operating system up to date to maintain the highest level of protection."
                    }

                    section(title: "Third-Party Services") {
                        "The App does not integrate with third-party analytics, advertising, or tracking services. No data is shared with external parties. If future updates introduce any third-party integrations, this policy will be updated accordingly, and you will be notified within the App."
                    }

                    section(title: "Children's Privacy") {
                        "The App is not directed at children under the age of 13. We do not knowingly collect personal information from children. Since no personal data is collected from any user, the App complies with applicable child privacy regulations by design."
                    }

                    section(title: "Changes to This Policy") {
                        "We may update this Privacy Policy from time to time to reflect changes in the App or applicable regulations. Any changes will be posted within the App, and the \"Last updated\" date will be revised. Continued use of the App after changes are posted constitutes your acceptance of the updated policy."
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
            .navigationTitle("Privacy Policy")
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
