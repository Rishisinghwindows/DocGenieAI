import Foundation

enum AppTab: String, CaseIterable, Identifiable {
    case chat
    case tools
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .chat: return "Chat"
        case .tools: return "Tools"
        case .settings: return "Settings"
        }
    }

    var systemImage: String {
        switch self {
        case .chat: return "bubble.left.and.bubble.right"
        case .tools: return "wrench.and.screwdriver"
        case .settings: return "gearshape"
        }
    }
}
