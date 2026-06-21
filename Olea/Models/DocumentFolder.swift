import SwiftData
import SwiftUI
import Foundation

@Model
final class DocumentFolder {
    @Attribute(.unique) var id: UUID
    var name: String
    var colorHex: String
    var iconName: String
    var createdAt: Date
    var parentFolderId: UUID?

    @Transient var color: Color {
        Color(hex: colorHex) ?? .appPrimary
    }

    init(name: String, colorHex: String = "#6366F1", iconName: String = "folder.fill", parentFolderId: UUID? = nil) {
        self.id = UUID()
        self.name = name
        self.colorHex = colorHex
        self.iconName = iconName
        self.createdAt = Date()
        self.parentFolderId = parentFolderId
    }
}

extension Color {
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")
        guard hexSanitized.count == 6 else { return nil }
        var rgbValue: UInt64 = 0
        Scanner(string: hexSanitized).scanHexInt64(&rgbValue)
        self.init(
            red: Double((rgbValue & 0xFF0000) >> 16) / 255.0,
            green: Double((rgbValue & 0x00FF00) >> 8) / 255.0,
            blue: Double(rgbValue & 0x0000FF) / 255.0
        )
    }
}
