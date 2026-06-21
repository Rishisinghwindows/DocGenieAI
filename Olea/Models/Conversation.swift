import SwiftData
import Foundation

// MARK: - Chat Memory (Persistent across conversations)

@Model
final class ChatMemory {
    @Attribute(.unique) var id: UUID
    var content: String
    var category: String // "preference", "fact", "context"
    var createdAt: Date
    var lastUsedAt: Date
    var useCount: Int

    init(content: String, category: String = "fact") {
        self.id = UUID()
        self.content = content
        self.category = category
        self.createdAt = .now
        self.lastUsedAt = .now
        self.useCount = 0
    }
}

@Model
final class Conversation {
    @Attribute(.unique) var id: UUID
    var title: String
    var createdAt: Date
    var updatedAt: Date
    var isPinned: Bool = false

    @Relationship(deleteRule: .cascade, inverse: \ChatMessage.conversation)
    var messages: [ChatMessage]?

    init(title: String = "New Chat") {
        self.id = UUID()
        self.title = title
        self.createdAt = .now
        self.updatedAt = .now
        self.isPinned = false
    }
}
