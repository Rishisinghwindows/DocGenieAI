import SwiftUI
import SwiftData
import TipKit

struct SettingsTabView: View {
    @Environment(\.modelContext) private var modelContext

    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = true
    @AppStorage("hasCompletedTutorial") private var hasCompletedTutorial = true
    @AppStorage("appAppearance") private var appAppearance: Int = 0
    @AppStorage(LocationService.autoTagDefaultsKey) private var autoTagLocation = false
    @AppStorage(SpotlightIndexingService.defaultsEnabledKey) private var spotlightIndexingEnabled = true
    @State private var showOnboardingReset = false
    @State private var showTipsReset = false
    @State private var showTerms = false
    @State private var showPrivacy = false
    @State private var showMemories = false
    @State private var showClearMemories = false
    @State private var showVault = false
    @Query(sort: \ChatMemory.lastUsedAt, order: .reverse) private var memories: [ChatMemory]
    @Query(filter: #Predicate<DocumentFile> { $0.isInVault == true }) private var vaultFiles: [DocumentFile]

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    private var storageUsed: String {
        let dir = FileStorageService.shared.appFilesDirectory
        guard let files = try? FileManager.default.contentsOfDirectory(atPath: dir.path) else { return "0 MB" }
        var total: Int64 = 0
        for file in files {
            let path = dir.appendingPathComponent(file).path
            if let attrs = try? FileManager.default.attributesOfItem(atPath: path),
               let size = attrs[.size] as? Int64 {
                total += size
            }
        }
        return total.formattedFileSize
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppSpacing.lg) {
                    // App Info
                    VStack(spacing: AppSpacing.xs) {
                        GlowingIcon(
                            systemName: "doc.viewfinder",
                            color: .appPrimary,
                            size: 28,
                            bgSize: 56
                        )

                        Text("Olea")
                            .font(.appH2)
                            .foregroundStyle(Color.appText)

                        Text("v\(appVersion)")
                            .font(.appMicro)
                            .foregroundStyle(Color.appTextDim)
                    }
                    .padding(.top, AppSpacing.md)
                    .padding(.bottom, AppSpacing.lg)

                    // Appearance
                    settingsCard(title: "Appearance", icon: "paintbrush") {
                        Picker("Appearance", selection: $appAppearance) {
                            Text("System").tag(0)
                            Text("Light").tag(1)
                            Text("Dark").tag(2)
                        }
                        .pickerStyle(.segmented)
                    }

                    // Secure Vault
                    settingsCard(title: "Security", icon: "lock.shield") {
                        settingsRow(icon: "lock.shield.fill", text: "Secure Vault", badge: vaultFiles.isEmpty ? nil : "\(vaultFiles.count)") {
                            showVault = true
                        }
                    }

                    // Privacy
                    settingsCard(title: "Privacy", icon: "hand.raised") {
                        Toggle(isOn: $autoTagLocation) {
                            HStack(spacing: AppSpacing.sm) {
                                Image(systemName: "location.fill")
                                    .foregroundStyle(Color.appAccent)
                                    .frame(width: 20)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Auto-tag Location")
                                        .font(.appBody)
                                        .foregroundStyle(Color.appText)
                                    Text("Save where each document was scanned or imported. Off by default.")
                                        .font(.appMicro)
                                        .foregroundStyle(Color.appTextMuted)
                                        .multilineTextAlignment(.leading)
                                }
                            }
                        }
                        .tint(Color.appPrimary)
                        .onChange(of: autoTagLocation) { _, newValue in
                            if newValue { LocationService.shared.requestPermission() }
                        }

                        Divider().background(Color.appTextMuted.opacity(0.2))

                        Toggle(isOn: $spotlightIndexingEnabled) {
                            HStack(spacing: AppSpacing.sm) {
                                Image(systemName: "magnifyingglass.circle.fill")
                                    .foregroundStyle(Color.appAccent)
                                    .frame(width: 20)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Find in iOS Search")
                                        .font(.appBody)
                                        .foregroundStyle(Color.appText)
                                    Text("Surface your documents in Spotlight, Lock Screen search, and Siri Suggestions. Vault files are never indexed.")
                                        .font(.appMicro)
                                        .foregroundStyle(Color.appTextMuted)
                                        .multilineTextAlignment(.leading)
                                }
                            }
                        }
                        .tint(Color.appPrimary)
                        .onChange(of: spotlightIndexingEnabled) { _, newValue in
                            handleSpotlightToggle(enabled: newValue)
                        }
                    }

                    // AI & Storage
                    settingsCard(title: "System", icon: "cpu") {
                        HStack {
                            Image(systemName: "brain")
                                .foregroundStyle(Color.appAccent)
                                .frame(width: 20)
                            Text("AI Engine")
                                .font(.appBody)
                                .foregroundStyle(Color.appTextMuted)
                            Spacer()
                            let isAI = AIService.shared.isOnDeviceAIAvailable
                            Text(isAI ? "On-Device" : "Keyword")
                                .font(.appCaption)
                                .foregroundStyle(isAI ? Color.appSuccess : Color.appTextMuted)
                                .padding(.horizontal, AppSpacing.sm)
                                .padding(.vertical, AppSpacing.xs)
                                .background((isAI ? Color.appSuccess : Color.appTextMuted).opacity(0.15), in: Capsule())
                            if isAI {
                                Text("On-Device")
                                    .font(.appMicro)
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.appSuccess, in: Capsule())
                            }
                        }
                        Divider().background(Color.appBorder)
                        HStack {
                            Image(systemName: "internaldrive")
                                .foregroundStyle(Color.appAccent)
                                .frame(width: 20)
                            Text("Storage")
                                .font(.appBody)
                                .foregroundStyle(Color.appTextMuted)
                            Spacer()
                            Text(storageUsed)
                                .font(.appH3)
                                .foregroundStyle(Color.appAccent)
                        }
                    }

                    // Memory
                    settingsCard(title: "Memory", icon: "brain") {
                        settingsRow(icon: "list.bullet.rectangle", text: "View Memories", badge: memories.isEmpty ? nil : "\(memories.count)") {
                            showMemories = true
                        }
                        Divider().background(Color.appBorder)
                        settingsRow(icon: "trash", text: "Clear All Memories", badge: nil) {
                            showClearMemories = true
                        }
                    }

                    // About
                    settingsCard(title: "About", icon: "info.circle") {
                        settingsRow(icon: "doc.plaintext", text: "Terms & Conditions", badge: nil) {
                            showTerms = true
                        }
                        Divider().background(Color.appBorder)
                        settingsRow(icon: "hand.raised", text: "Privacy Policy", badge: nil) {
                            showPrivacy = true
                        }
                        Divider().background(Color.appBorder)
                        settingsRow(icon: "envelope", text: "Support & Feedback", badge: nil) {
                            if let url = URL(string: "mailto:\(AppConstants.supportEmail)") {
                                UIApplication.shared.open(url)
                            }
                        }
                        Divider().background(Color.appBorder)
                        settingsRow(icon: "star", text: "Rate App", badge: nil) {
                            if let url = URL(string: AppConstants.appStoreURL) {
                                UIApplication.shared.open(url)
                            }
                        }
                        Divider().background(Color.appBorder)
                        settingsRow(icon: "square.and.arrow.up", text: "Share App", badge: nil) {
                            if let url = URL(string: AppConstants.appStoreURL) {
                                ShareService.shared.share(fileURL: url)
                            }
                        }
                        Divider().background(Color.appBorder)
                        settingsRow(icon: "arrow.counterclockwise", text: "Replay Onboarding", badge: nil) {
                            showOnboardingReset = true
                        }
                        Divider().background(Color.appBorder)
                        settingsRow(icon: "hand.tap", text: "Replay Tutorial", badge: nil) {
                            hasCompletedTutorial = false
                        }
                        Divider().background(Color.appBorder)
                        settingsRow(icon: "lightbulb", text: "Reset Tips & Hints", badge: nil) {
                            showTipsReset = true
                        }
                        Divider().background(Color.appBorder)
                        Text("v\(appVersion) (\(buildNumber))")
                            .font(.appMicro)
                            .foregroundStyle(Color.appTextDim)
                            .frame(maxWidth: .infinity)
                            .padding(.top, AppSpacing.xs)
                    }

                    Spacer(minLength: AppSpacing.xxl)
                }
            }
            .background(Color.appBGDark)
            .navigationTitle("Settings")
            .sheet(isPresented: $showVault) {
                VaultView()
                    .presentationCornerRadius(24)
                    .presentationBackground(.ultraThinMaterial)
            }
            .sheet(isPresented: $showTerms) {
                TermsAndConditionsView()
                    .presentationCornerRadius(24)
                    .presentationBackground(.ultraThinMaterial)
            }
            .sheet(isPresented: $showPrivacy) {
                PrivacyPolicyView()
                    .presentationCornerRadius(24)
                    .presentationBackground(.ultraThinMaterial)
            }
            .alert("Replay Onboarding?", isPresented: $showOnboardingReset) {
                Button("Replay", role: .destructive) {
                    withAnimation(.easeInOut(duration: 0.4)) {
                        hasCompletedOnboarding = false
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will show the onboarding walkthrough again.")
            }
            .alert("Reset Tips?", isPresented: $showTipsReset) {
                Button("Reset", role: .destructive) {
                    try? Tips.resetDatastore()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("All feature tips and hints will appear again.")
            }
            .alert("Clear All Memories?", isPresented: $showClearMemories) {
                Button("Clear", role: .destructive) {
                    MemoryService.shared.clearAllMemories(context: modelContext)
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Olea will forget everything it learned about you. This cannot be undone.")
            }
            .sheet(isPresented: $showMemories) {
                MemoryListView()
                    .presentationCornerRadius(24)
                    .presentationBackground(.ultraThinMaterial)
            }
        }
    }

    // MARK: - Spotlight toggle handler

    /// User flipped "Find in iOS Search". On → rebuild the index from every
    /// non-vault doc so the user sees results immediately. Off → wipe every
    /// Olea-owned item out of the system index.
    private func handleSpotlightToggle(enabled: Bool) {
        let service = SpotlightIndexingService.shared
        if enabled {
            let descriptor = FetchDescriptor<DocumentFile>()
            if let docs = try? modelContext.fetch(descriptor) {
                service.bulkReindex(docs)
            }
        } else {
            service.clearAll()
        }
    }

    // MARK: - Helpers

    private func settingsCard(title: String, icon: String, @ViewBuilder content: () -> some View) -> some View {
        AppCard(style: .glass) {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                Label(title, systemImage: icon)
                    .font(.appCaption)
                    .foregroundStyle(Color.appTextDim)
                    .padding(.bottom, AppSpacing.xs)
                content()
            }
            .padding(AppSpacing.md)
        }
        .padding(.horizontal, AppSpacing.md)
    }

    private func settingsRow(icon: String, text: String, badge: String?, action: @escaping () -> Void) -> some View {
        Button {
            HapticManager.light()
            action()
        } label: {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(Color.appAccent)
                    .frame(width: 20)
                Text(text)
                    .font(.appBody)
                    .foregroundStyle(Color.appTextMuted)
                Spacer()
                if let badge {
                    Text(badge)
                        .font(.appCaption)
                        .foregroundStyle(Color.appTextMuted)
                        .padding(.horizontal, AppSpacing.sm)
                        .padding(.vertical, 2)
                        .background(Color.appTextMuted.opacity(0.12), in: Capsule())
                }
                Image(systemName: "chevron.right")
                    .font(.appCaption)
                    .foregroundStyle(Color.appTextDim)
            }
        }
    }
}

// MARK: - Memory List View

struct MemoryListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \ChatMemory.lastUsedAt, order: .reverse) private var memories: [ChatMemory]

    var body: some View {
        NavigationStack {
            Group {
                if memories.isEmpty {
                    EmptyStateView(
                        icon: "brain",
                        title: "No Memories",
                        message: "Olea will remember important things you tell it, like your preferences and frequently used files."
                    )
                } else {
                    List {
                        ForEach(memories) { memory in
                            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                                Text(memory.content)
                                    .font(.appBody)
                                    .foregroundStyle(Color.appText)
                                HStack {
                                    Text(memory.category.capitalized)
                                        .font(.appMicro)
                                        .foregroundStyle(Color.appPrimary)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.appPrimary.opacity(0.12), in: Capsule())
                                    Spacer()
                                    Text(memory.createdAt.relativeDisplay)
                                        .font(.appMicro)
                                        .foregroundStyle(Color.appTextDim)
                                }
                            }
                            .padding(.vertical, AppSpacing.xs)
                            .listRowBackground(Color.appBGCard)
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    MemoryService.shared.deleteMemory(memory, context: modelContext)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .background(Color.appBGDark)
            .navigationTitle("Memories (\(memories.count))")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(Color.appPrimary)
                }
            }
        }
    }
}
