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
