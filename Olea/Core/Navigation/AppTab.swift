import Foundation

enum AppTab: String, CaseIterable, Identifiable {
    case inbox
    case files
    case tools
    case chat
    case settings

    var id: String { rawValue }

    /// Localized title. Backed by entries in `Localizable.xcstrings` — when
    /// the system locale doesn't have a translation, the English source string
    /// (the key itself) is returned, so we never display a missing-key marker.
    var title: String {
        switch self {
        case .inbox: return String(localized: "Inbox", comment: "Inbox tab label")
        case .files: return String(localized: "Files", comment: "Files tab label")
        case .tools: return String(localized: "Tools", comment: "Tools tab label")
        case .chat: return String(localized: "Ask", comment: "Chat tab label")
        case .settings: return String(localized: "Settings", comment: "Settings tab label")
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
