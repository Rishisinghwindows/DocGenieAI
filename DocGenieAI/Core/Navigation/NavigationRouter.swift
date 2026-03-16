import SwiftUI

@MainActor
@Observable
final class NavigationRouter {
    var selectedTab: AppTab = .chat
    var chatPath = NavigationPath()
    var toolsPath = NavigationPath()
    var toolToOpen: ToolItem?

    func navigateToTools() {
        selectedTab = .tools
    }

    func openToolFromAnywhere(_ tool: ToolItem) {
        selectedTab = .tools
        toolToOpen = tool
    }

    func resetCurrentTab() {
        switch selectedTab {
        case .chat: chatPath = NavigationPath()
        case .tools: toolsPath = NavigationPath()
        case .settings: break
        }
    }
}
