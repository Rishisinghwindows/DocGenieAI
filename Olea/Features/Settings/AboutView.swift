import SwiftUI

struct AboutView: View {
    @Environment(\.dismiss) private var dismiss

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppSpacing.lg) {
                    // App Icon & Identity
                    VStack(spacing: AppSpacing.sm) {
                        GlowingIcon(
                            systemName: "doc.viewfinder",
                            color: .appPrimary,
                            size: 40,
                            bgSize: 80
                        )

                        Text("Olea")
                            .font(.appH1)
                            .foregroundStyle(Color.appText)

                        Text("Version \(appVersion) (\(buildNumber))")
                            .font(.appCaption)
                            .foregroundStyle(Color.appTextDim)
                            .padding(.horizontal, AppSpacing.md)
                            .padding(.vertical, AppSpacing.xs)
                            .background(Color.appBGCard, in: Capsule())
                    }
                    .padding(.top, AppSpacing.xl)

                    // Description
                    AppCard(style: .glass) {
                        Text("Olea is your all-in-one document companion. Scan paper documents, manage your digital files, and unlock powerful PDF tools -- all enhanced by on-device artificial intelligence. No cloud uploads, no subscriptions. Your documents stay private and under your control.")
                            .font(.appBody)
                            .foregroundStyle(Color.appTextMuted)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(AppSpacing.sm)
                    }
                    .padding(.horizontal, AppSpacing.md)

                    // Capabilities
                    AppCard(style: .glass) {
                        VStack(alignment: .leading, spacing: AppSpacing.sm) {
                            Text("Capabilities")
                                .font(.appH3)
                                .foregroundStyle(Color.appText)

                            capabilityRow(icon: "doc.viewfinder", text: "Document Scanner with Filters")
                            capabilityRow(icon: "wrench.and.screwdriver", text: "23+ PDF & Conversion Tools")
                            capabilityRow(icon: "text.viewfinder", text: "OCR Text Recognition")
                            capabilityRow(icon: "brain", text: "AI Document Assistant")
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(AppSpacing.sm)
                    }
                    .padding(.horizontal, AppSpacing.md)

                    // Footer
                    VStack(spacing: AppSpacing.xs) {
                        Text("Made with \u{2764}\u{FE0F} in India")
                            .font(.appCaption)
                            .foregroundStyle(Color.appTextDim)

                        Text("\u{00A9} 2026 Olea. All rights reserved.")
                            .font(.appMicro)
                            .foregroundStyle(Color.appTextDim.opacity(0.7))
                    }
                    .padding(.top, AppSpacing.md)

                    Spacer(minLength: AppSpacing.xxl)
                }
            }
            .background(Color.appBGDark)
            .navigationTitle("About")
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

    private func capabilityRow(icon: String, text: String) -> some View {
        HStack(spacing: AppSpacing.sm) {
            Image(systemName: icon)
                .font(.appCaption)
                .foregroundStyle(Color.appAccent)
                .frame(width: 20)
            Text(text)
                .font(.appBody)
                .foregroundStyle(Color.appTextMuted)
        }
    }
}
