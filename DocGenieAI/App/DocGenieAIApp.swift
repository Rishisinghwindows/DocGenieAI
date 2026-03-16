import SwiftUI
import SwiftData
import TipKit
import AppIntents

@main
struct DocGenieAIApp: App {
    @AppStorage("appAppearance") private var appAppearance: Int = 0

    private var colorScheme: ColorScheme? {
        switch appAppearance {
        case 1: return .light
        case 2: return .dark
        default: return nil
        }
    }

    var body: some Scene {
        WindowGroup {
            AppTabView()
                .preferredColorScheme(colorScheme)
                .task {
                    try? Tips.configure([
                        .displayFrequency(.immediate),
                        .datastoreLocation(.applicationDefault)
                    ])
                }
                .onOpenURL { url in
                    handleDeepLink(url)
                }
        }
        .modelContainer(for: [DocumentFile.self, ChatMessage.self, Conversation.self, ChatMemory.self, DocumentFolder.self])
    }

    private func handleDeepLink(_ url: URL) {
        guard url.scheme == "docsage" else { return }
        // Handle: docsage://scan, docsage://chat, docsage://tools
        switch url.host {
        case "scan", "chat", "tools":
            // Deep link handling — NavigationRouter picks up via environment
            break
        default:
            break
        }
    }
}

// MARK: - Siri App Intents

struct ScanDocumentIntent: AppIntent {
    static let title: LocalizedStringResource = "Scan Document"
    static let description: IntentDescription = "Open DocSage to scan a document with the camera"
    static let openAppWhenRun = true

    func perform() async throws -> some IntentResult {
        .result()
    }
}

struct OpenDocSageIntent: AppIntent {
    static let title: LocalizedStringResource = "Open DocSage"
    static let description: IntentDescription = "Open the DocSage document assistant"
    static let openAppWhenRun = true

    func perform() async throws -> some IntentResult {
        .result()
    }
}

struct AskDocSageIntent: AppIntent {
    static let title: LocalizedStringResource = "Ask DocSage"
    static let description: IntentDescription = "Ask DocSage a question about your documents"
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
            shortTitle: "Ask DocSage",
            systemImageName: "bubble.left.and.text.bubble.right"
        )

        AppShortcut(
            intent: OpenDocSageIntent(),
            phrases: [
                "Open \(.applicationName)",
                "Start \(.applicationName)"
            ],
            shortTitle: "Open DocSage",
            systemImageName: "sparkles"
        )
    }
}
