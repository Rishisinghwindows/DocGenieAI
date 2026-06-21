import SwiftUI
import SwiftData

struct AppTabView: View {
    init() {
        let appearance = UITabBarAppearance()
        appearance.configureWithDefaultBackground()

        let primaryColor = UIColor(Color.appPrimary)
        let mutedColor = UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 0.580, green: 0.639, blue: 0.722, alpha: 1)
                : UIColor.secondaryLabel
        }

        appearance.stackedLayoutAppearance.selected.iconColor = primaryColor
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = [
            .foregroundColor: primaryColor
        ]
        appearance.stackedLayoutAppearance.normal.iconColor = mutedColor
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = [
            .foregroundColor: mutedColor
        ]

        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }

    @Environment(\.modelContext) private var modelContext
    @State private var router = NavigationRouter()
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("lastWhatsNewVersion") private var lastWhatsNewVersion = ""
    @State private var showSplash = true
    @State private var showWhatsNew = false
    @State private var whatsNewFeatures: [WhatsNewFeature] = []

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    var body: some View {
        ZStack {
            if hasCompletedOnboarding {
                tabContent
            } else {
                OnboardingView {
                    withAnimation(.easeInOut(duration: 0.4)) {
                        hasCompletedOnboarding = true
                        lastWhatsNewVersion = appVersion
                    }
                }
            }

            if showSplash {
                splashOverlay
            }
        }
        .task {
            SharedFileImportService.shared.checkAndImportSharedFiles(context: modelContext)
            try? await Task.sleep(for: .seconds(1.8))
            withAnimation(.easeOut(duration: 0.5)) {
                showSplash = false
            }
            if hasCompletedOnboarding && lastWhatsNewVersion != appVersion {
                if let features = WhatsNewData.features(for: appVersion) {
                    whatsNewFeatures = features
                    try? await Task.sleep(for: .seconds(0.5))
                    showWhatsNew = true
                } else {
                    lastWhatsNewVersion = appVersion
                }
            }
        }
        .sheet(isPresented: $showWhatsNew) {
            WhatsNewView(version: appVersion, features: whatsNewFeatures) {
                lastWhatsNewVersion = appVersion
                showWhatsNew = false
            }
            .presentationCornerRadius(24)
            .presentationBackground(.regularMaterial)
            .interactiveDismissDisabled()
        }
    }

    private var tabContent: some View {
        TabView(selection: Binding(
            get: { router.selectedTab },
            set: { newTab in
                if router.selectedTab == newTab {
                    router.resetCurrentTab()
                } else {
                    HapticManager.selection()
                    router.selectedTab = newTab
                }
            }
        )) {
            InboxView()
                .tabItem {
                    Label(AppTab.inbox.title, systemImage: AppTab.inbox.systemImage)
                }
                .tag(AppTab.inbox)

            FilesTabView()
                .tabItem {
                    Label(AppTab.files.title, systemImage: AppTab.files.systemImage)
                }
                .tag(AppTab.files)

            ToolsTabView()
                .tabItem {
                    Label(AppTab.tools.title, systemImage: AppTab.tools.systemImage)
                }
                .tag(AppTab.tools)

            ChatTabView()
                .tabItem {
                    Label(AppTab.chat.title, systemImage: AppTab.chat.systemImage)
                }
                .tag(AppTab.chat)

            SettingsTabView()
                .tabItem {
                    Label(AppTab.settings.title, systemImage: AppTab.settings.systemImage)
                }
                .tag(AppTab.settings)
        }
        .tint(Color.appPrimary)
        .environment(router)
    }

    private var splashOverlay: some View {
        ZStack {
            // Same living-canvas backdrop as onboarding for brand continuity.
            AnimatedMeshBackground()
                .ignoresSafeArea()
                .opacity(0.45)
                .overlay(Color.appBGDark.opacity(0.6).ignoresSafeArea())

            VStack(spacing: AppSpacing.md) {
                ZStack {
                    Circle()
                        .fill(.ultraThinMaterial)
                        .frame(width: 140, height: 140)
                        .overlay(Circle().strokeBorder(Color.white.opacity(0.18), lineWidth: 0.8))

                    Image(systemName: "tray.full.fill")
                        .font(.system(size: 64, weight: .medium))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.appPrimary, Color.appAccent],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .applySplashBreathing()
                        .scaleEffect(showSplash ? 1.0 : 0.85)
                }
                .aiShimmerRim(cornerRadius: 90, lineWidth: 1.6)

                Text("Olea")
                    .font(.appH1)
                    .foregroundStyle(Color.appText)
                    .padding(.top, AppSpacing.sm)

                Text("Your documents, automatically organized.")
                    .font(.appCaption)
                    .foregroundStyle(Color.appTextDim)
            }
        }
        .transition(.opacity)
    }
}

private extension View {
    @ViewBuilder
    func applySplashBreathing() -> some View {
        if #available(iOS 18, *) {
            self.symbolEffect(.breathe.plain.byLayer, options: .repeating)
        } else {
            self.symbolEffect(.pulse, options: .repeating)
        }
    }
}
