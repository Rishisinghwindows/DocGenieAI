import Foundation

enum AppTab: String, CaseIterable, Identifiable {
    case inbox
    case files
    case tools
    case chat
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .inbox: return "Inbox"
        case .files: return "Files"
        case .tools: return "Tools"
        case .chat: return "Ask"
        case .settings: return "Settings"
        }
    }

    var systemImage: String {
        switch self {
        case .inbox: return "tray.full.fill"
        case .files: return "folder.fill"
        case .tools: return "wrench.and.screwdriver.fill"
        case .chat: return "sparkles"
        case .settings: return "gearshape"
        }
    }
}
