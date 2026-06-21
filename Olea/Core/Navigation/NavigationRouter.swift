import SwiftUI

@MainActor
@Observable
final class NavigationRouter {
    var selectedTab: AppTab = .inbox
    var inboxPath = NavigationPath()
    var filesPath = NavigationPath()
    var toolsPath = NavigationPath()
    var chatPath = NavigationPath()
    var toolToOpen: ToolItem?
    /// Set by external entry points (Spotlight tap, future deep links) when a
    /// specific document should be opened. `FilesTabView` observes this and
    /// pushes the matching DocumentFile onto its navigation stack, then clears
    /// the ID so the same tap can fire again later.
    var pendingFileIDToOpen: UUID?

    func openDocument(id: UUID) {
        selectedTab = .files
        pendingFileIDToOpen = id
    }

    func navigateToTools() {
        selectedTab = .tools
    }

    func navigateToFiles() {
        selectedTab = .files
    }

    func navigateToChat() {
        selectedTab = .chat
    }

    func openToolFromAnywhere(_ tool: ToolItem) {
        selectedTab = .tools
        toolToOpen = tool
    }

    func resetCurrentTab() {
        switch selectedTab {
        case .inbox: inboxPath = NavigationPath()
        case .files: filesPath = NavigationPath()
        case .tools: toolsPath = NavigationPath()
        case .chat: chatPath = NavigationPath()
        case .settings: break
        }
    }
}
