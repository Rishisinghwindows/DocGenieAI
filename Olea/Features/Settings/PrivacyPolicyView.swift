import SwiftUI

struct PrivacyPolicyView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.lg) {
                    section(title: "Information Collection") {
                        "Olea processes all documents entirely on your device. We do not collect, transmit, or store any personal data, documents, or files on external servers. AI-powered features — including auto-organization, semantic search, multi-document Q&A, and summarization — are performed using Apple Intelligence (Foundation Models framework) and on-device frameworks (Vision, Speech, Natural Language) provided by the operating system. No prompts, embeddings, or document text ever leave your device."
                    }

                    section(title: "Apple Intelligence and Foundation Models") {
                        "On devices running iOS 26 or later that support Apple Intelligence, Olea uses Apple's on-device Foundation Models to classify documents, generate summaries, and answer questions about your content. Apple's Foundation Models framework runs the model locally; no document text, queries, or model outputs are transmitted to Apple servers or any third party. On older devices, Olea falls back to a built-in keyword classifier and search."
                    }

                    section(title: "Permissions") {
                        "Olea requests access to your Camera (to scan documents), Photo Library (to import images), Contacts (to match document mentions against your address book), Location (only when you opt in to auto-tag documents), Microphone and Speech Recognition (for voice notes), and Documents (to import files). All permissions are off by default unless required for the feature you initiate, and each can be revoked in Settings."
                    }

                    section(title: "Use of Data") {
                        "The App accesses files only when you explicitly import or scan them. Document data is stored locally within the App's sandboxed container on your device. We do not access your files for analytics, advertising, or any purpose beyond providing the features you request."
                    }

                    section(title: "Data Security") {
                        "Your documents are protected by the security mechanisms built into iOS, including App Sandbox, Data Protection, and hardware encryption. Files processed by the App remain under your control at all times. We recommend keeping your device passcode enabled and your operating system up to date to maintain the highest level of protection."
                    }

                    section(title: "Advertising") {
                        "The free version of Olea displays advertisements via Google AdMob. With your consent (required in the EU/UK/California via the GDPR/CPRA consent form on first launch), Google receives device identifiers (including IDFA when you grant App Tracking Transparency), IP address, and basic device information to personalize ads. If you decline tracking, Google still serves non-personalized ads using only contextual information. You can manage these preferences any time in Settings → Ads → Manage preferences. Olea Pro removes all advertisements and disables all data sharing with Google."
                    }

                    section(title: "Third-Party Services") {
                        "Olea uses Google AdMob and Google's User Messaging Platform to display and manage advertising. These services are governed by Google's privacy policy. No other third-party analytics, telemetry, or tracking SDKs are integrated. Document content (text, images, OCR output, embeddings) is never sent to Google or any other third party — only the device-level identifiers required to render ads."
                    }

                    section(title: "Children's Privacy") {
                        "The App is not directed at children under the age of 13. We do not knowingly collect personal information from children. Since no personal data is collected from any user, the App complies with applicable child privacy regulations by design."
                    }

                    section(title: "Changes to This Policy") {
                        "We may update this Privacy Policy from time to time to reflect changes in the App or applicable regulations. Any changes will be posted within the App, and the \"Last updated\" date will be revised. Continued use of the App after changes are posted constitutes your acceptance of the updated policy."
                    }

                    Text("Last updated: May 2026")
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
