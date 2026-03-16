import SwiftData
import SwiftUI
import Foundation

enum FileTag: String, CaseIterable, Identifiable {
    case work = "Work"
    case personal = "Personal"
    case invoice = "Invoice"
    case receipt = "Receipt"
    case legal = "Legal"
    case archive = "Archive"

    var id: String { rawValue }

    var color: Color {
        switch self {
        case .work: return .blue
        case .personal: return .green
        case .invoice: return .orange
        case .receipt: return .yellow
        case .legal: return .red
        case .archive: return .gray
        }
    }

    var icon: String {
        switch self {
        case .work: return "briefcase"
        case .personal: return "person"
        case .invoice: return "doc.text"
        case .receipt: return "receipt"
        case .legal: return "scale.3d"
        case .archive: return "archivebox"
        }
    }
}

@Model
final class DocumentFile {
    @Attribute(.unique) var id: UUID
    var name: String
    var fileExtension: String
    var relativeFilePath: String
    var fileSize: Int64
    var pageCount: Int?
    var importedAt: Date
    var originalCreatedAt: Date?
    var originalModifiedAt: Date?
    var lastOpenedAt: Date?
    var isFavorite: Bool
    var tagName: String?
    var ocrTextCache: String?
    var folderID: UUID?
    var expiryDate: Date?
    var expiryReminderDays: Int?
    var expiryNote: String?
    var isInVault: Bool = false

    @Transient var isExpired: Bool {
        guard let expiryDate else { return false }
        return expiryDate < Date.now
    }

    @Transient var isExpiringSoon: Bool {
        guard let expiryDate, !isExpired else { return false }
        let reminderDays = expiryReminderDays ?? 30
        let threshold = Calendar.current.date(byAdding: .day, value: reminderDays, to: Date.now) ?? Date.now
        return expiryDate <= threshold
    }

    @Transient var daysUntilExpiry: Int? {
        guard let expiryDate else { return nil }
        return Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: Date.now), to: Calendar.current.startOfDay(for: expiryDate)).day
    }

    @Transient var tag: FileTag? {
        guard let tagName else { return nil }
        return FileTag(rawValue: tagName)
    }

    @Transient var category: FileCategory {
        FileCategory.from(extension: fileExtension)
    }

    @Transient var viewerType: ViewerType {
        ViewerType.from(extension: fileExtension)
    }

    @Transient var fullFileName: String {
        "\(name).\(fileExtension)"
    }

    @Transient var fileURL: URL? {
        guard let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        return documentsDir.appendingPathComponent(relativeFilePath)
    }

    init(
        name: String,
        fileExtension: String,
        relativeFilePath: String,
        fileSize: Int64,
        pageCount: Int? = nil,
        importedAt: Date = .now,
        originalCreatedAt: Date? = nil,
        originalModifiedAt: Date? = nil,
        isFavorite: Bool = false
    ) {
        self.id = UUID()
        self.name = name
        self.fileExtension = fileExtension
        self.relativeFilePath = relativeFilePath
        self.fileSize = fileSize
        self.pageCount = pageCount
        self.importedAt = importedAt
        self.originalCreatedAt = originalCreatedAt
        self.originalModifiedAt = originalModifiedAt
        self.isFavorite = isFavorite
    }
}
