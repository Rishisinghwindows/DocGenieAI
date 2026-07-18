//
//  OleaApp.swift
//  Olea
//
//  Role: App entry point. Owns the WindowGroup, the SwiftData container, and
//  the launch-time wiring for all the cross-cutting services that need to
//  start before the first view renders.
//
//  Init responsibilities (synchronous, before the scene exists):
//    • CrashReporter — MetricKit subscriber; daily crash/hang reports get
//                       logged to OSLog from the previous launch.
//    • AdsCoordinator — kicks off async MobileAds SDK initialization +
//                       preloads app-open + interstitial ads.
//    • UsageManager  — mirrors persisted Pro state into the Ads layer so
//                       Pro users see no ads from the first frame.
//
//  Scene responsibilities (async, after first render):
//    • TipKit configure — gated behind iOS <26 because TipKit's SwiftData
//                          datastore conflicts with our ModelContainer on iOS 26
//                          (reproducible Trace/BPT trap; see DocSageTipKit
//                          crash report in DiagnosticReports/).
//    • Consent flow + cold-launch app-open ad — UMP first, then ATT, then
//                          AdsCoordinator.onAppLaunched.
//    • ExpiryActivityService — reconciles Live Activities for any docs whose
//                               expiry has entered the user's reminder window.
//
//  scenePhase observer: keeps AdsCoordinator informed of background/foreground
//  transitions so the App-Open ad can fire on resume only after the
//  configured background interval.
//

import SwiftUI
import SwiftData
import TipKit
import AppIntents
import CoreSpotlight

@main
struct OleaApp: App {
    @AppStorage("appAppearance") private var appAppearance: Int = 0
    /// Drives live language switching. Mutating its `currentLanguage` makes
    /// SwiftUI rebuild the root view (via the `.id(...)` modifier below),
    /// which re-resolves every localized string against the new bundle.
    @State private var localization = LocalizationManager.shared

    private var colorScheme: ColorScheme? {
        switch appAppearance {
        case 1: return .light
        case 2: return .dark
        default: return nil
        }
    }

    init() {
        CrashReporter.shared.start()
        AdsCoordinator.shared.start()
        // Mirror the persisted Pro state into the ads layer so Pro users see
        // no ads from the first frame.
        UsageManager.shared.syncAdsProState()
    }

    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            AppTabView()
                .preferredColorScheme(colorScheme)
                // Re-evaluate the whole tree whenever the chosen language
                // changes. SwiftUI doesn't observe Bundle.main directly, so
                // we use .id() to discard and rebuild the view hierarchy
                // against the swizzled bundle. Strings re-resolve on the
                // very next render frame.
                .id(localization.currentLanguage ?? "system")
                // Also bind the SwiftUI locale env so date/number formatters
                // and any locale-sensitive system UI (alert buttons, share
                // sheet, etc.) match.
                .environment(\.locale, Locale(identifier: localization.currentLanguage ?? Locale.current.identifier))
                .task {
                    // NOTE: on iOS 26 + the current SwiftData container, TipKit's
                    // SwiftData-backed datastore posts notifications that fire the
                    // _SwiftData_SwiftUI observer and assert inside SwiftData
                    // (Trace/BPT trap reproduced in DiagnosticReports/DocGenieAI-2026-05-10-1754*.ips).
                    // Until Apple addresses the bridge issue, disable Tips on iOS 26
                    // and store the datastore in a sandbox-private subfolder otherwise.
                    if #unavailable(iOS 26) {
                        let docs = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                        let tipsURL = docs?.appendingPathComponent("TipKit", isDirectory: true)
                        if let tipsURL { try? FileManager.default.createDirectory(at: tipsURL, withIntermediateDirectories: true) }
                        try? Tips.configure([
                            .displayFrequency(.immediate),
                            tipsURL.map { Tips.ConfigurationOption.datastoreLocation(.url($0)) } ?? .datastoreLocation(.applicationDefault)
                        ])
                    } else {
                        AppLogger.ui.info("TipKit disabled on iOS 26 — see comment for SwiftData bridge crash details.")
                    }
                }
                .onOpenURL { url in
                    handleDeepLink(url)
                }
                .onContinueUserActivity(CSSearchableItemActionType) { activity in
                    handleSpotlightTap(activity)
                }
                .task {
                    // First launch after install / schema bump: rebuild the
                    // Spotlight index in one batch so the user can find their
                    // existing library from system search immediately.
                    await runSpotlightBulkIndexIfNeeded()
                }
                .task {
                    // Reconcile Live Activities for any docs whose expiry has entered
                    // the user's reminder window since last launch.
                    let context = ModelContext(SharedModelContainer.shared)
                    ExpiryActivityService.shared.reconcile(modelContext: context)
                }
                .task {
                    // Consent + cold-launch app-open ad. Sequence matters: UMP
                    // consent first (so we know if we can serve any ads), then
                    // ATT (Apple requires it be the last tracking prompt), then
                    // the cold-launch app-open. The launch counter inside the
                    // coordinator silently suppresses the first launch so the
                    // user sees onboarding before any ad.
                    if let root = UIApplication.shared.connectedScenes
                        .compactMap({ $0 as? UIWindowScene })
                        .first?.windows.first(where: \.isKeyWindow)?.rootViewController {
                        await AdConsentManager.shared.requestConsentIfNeeded(from: root)
                    }
                    AdsCoordinator.shared.onAppLaunched()
                }
                .onChange(of: scenePhase) { _, newPhase in
                    switch newPhase {
                    case .active:
                        AdsCoordinator.shared.onAppEnteredForeground()
                    case .background:
                        AdsCoordinator.shared.onAppEnteredBackground()
                    default:
                        break
                    }
                }
        }
        .modelContainer(SharedModelContainer.shared)
    }

    /// Handles Siri Shortcut deep links (docsage:// scheme, kept for backward
    /// compat with the old bundle ID). Posts a Notification the AppTabView
    /// observes to switch tabs / open sheets — same hand-off pattern we use
    /// for Spotlight taps, so both entry points converge on one code path.
    private func handleDeepLink(_ url: URL) {
        guard url.scheme == "docsage" || url.scheme == "olea" else { return }
        guard let host = url.host else { return }
        NotificationCenter.default.post(
            name: .oleaDeepLink,
            object: nil,
            userInfo: ["host": host]
        )
    }

    /// User tapped an Olea document in Spotlight / Lock Screen search / Siri
    /// Suggestions. The activity carries the doc's UUID as its unique
    /// identifier; we hand that off to the router, which switches to the Files
    /// tab and lets `FilesTabView` resolve the actual DocumentFile.
    private func handleSpotlightTap(_ activity: NSUserActivity) {
        guard let identifier = activity.userInfo?[CSSearchableItemActivityIdentifier] as? String,
              let uuid = UUID(uuidString: identifier) else { return }
        NotificationCenter.default.post(
            name: .oleaOpenDocumentFromSpotlight,
            object: nil,
            userInfo: ["id": uuid]
        )
    }

    private func runSpotlightBulkIndexIfNeeded() async {
        let service = SpotlightIndexingService.shared
        guard service.isEnabled, !service.hasCompletedBulkIndex else { return }
        let context = ModelContext(SharedModelContainer.shared)
        let descriptor = FetchDescriptor<DocumentFile>()
        guard let docs = try? context.fetch(descriptor) else { return }
        service.bulkReindex(docs)
    }
}

extension Notification.Name {
    /// Fired when iOS hands a Spotlight result back to Olea. `userInfo["id"]`
    /// is a `UUID`. Observed by `FilesTabView` so it can open the matching
    /// DocumentFile in the viewer.
    static let oleaOpenDocumentFromSpotlight = Notification.Name("oleaOpenDocumentFromSpotlight")

    /// Fired for docsage:// or olea:// URL taps (Siri Shortcuts, App
    /// Intents, custom widgets). `userInfo["host"]` is the URL host —
    /// currently one of "scan", "chat", "tools", "files", "settings",
    /// "inbox". Observed by AppTabView which routes via NavigationRouter.
    static let oleaDeepLink = Notification.Name("oleaDeepLink")

    /// Fired when a deep link asks for the scanner. Observed by
    /// ToolsTabView, which owns the fullScreenCover(showScanner:).
    /// We can't just set a router flag because the scanner presentation
    /// state is view-local, not router-owned.
    static let oleaOpenScanner = Notification.Name("oleaOpenScanner")
}

// MARK: - Siri App Intents

struct ScanDocumentIntent: AppIntent {
    static let title: LocalizedStringResource = "Scan Document"
    static let description: IntentDescription = "Open Olea to scan a document with the camera"
    static let openAppWhenRun = true

    func perform() async throws -> some IntentResult {
        .result()
    }
}

struct OpenDocSageIntent: AppIntent {
    static let title: LocalizedStringResource = "Open Olea"
    static let description: IntentDescription = "Open the Olea document assistant"
    static let openAppWhenRun = true

    func perform() async throws -> some IntentResult {
        .result()
    }
}

struct AskDocSageIntent: AppIntent {
    static let title: LocalizedStringResource = "Ask Olea"
    static let description: IntentDescription = "Ask Olea a question about your documents"
    static let openAppWhenRun = true

    func perform() async throws -> some IntentResult {
        .result()
    }
}

struct DocSageShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: ScanDocumentIntent(),
            phrases: [
                "Scan a document with \(.applicationName)",
                "Scan with \(.applicationName)",
                "\(.applicationName) scan"
            ],
            shortTitle: "Scan Document",
            systemImageName: "doc.viewfinder"
        )

        AppShortcut(
            intent: AskDocSageIntent(),
            phrases: [
                "Ask \(.applicationName)",
                "Ask \(.applicationName) about my document",
                "\(.applicationName) help"
            ],
            shortTitle: "Ask Olea",
            systemImageName: "bubble.left.and.text.bubble.right"
        )

        AppShortcut(
            intent: OpenDocSageIntent(),
            phrases: [
                "Open \(.applicationName)",
                "Start \(.applicationName)"
            ],
            shortTitle: "Open Olea",
            systemImageName: "sparkles"
        )

        AppShortcut(
            intent: FindDocumentsIntent(),
            phrases: [
                "Search \(.applicationName)",
                "Find documents in \(.applicationName)",
                "\(.applicationName) find documents"
            ],
            shortTitle: "Find Documents",
            systemImageName: "doc.text.magnifyingglass"
        )

        // FileDocumentIntent uses two AppEntity parameters; AppShortcut phrases support
        // only a single entity parameter, so it's exposed via Shortcuts.app instead of
        // here. Users can build a custom phrase from the Shortcuts app once.
    }
}
