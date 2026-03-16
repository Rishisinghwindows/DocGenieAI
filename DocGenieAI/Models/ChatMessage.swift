import SwiftData
import Foundation

@Model
final class ChatMessage {
    @Attribute(.unique) var id: UUID
    var content: String
    var role: String // "user", "assistant", "system"
    var timestamp: Date
    var conversationId: UUID
    var toolBadge: String? // e.g. "Scanner", "Merge PDF"
    var actionsJSON: String?
    var messageType: String = ""        // "", "documentCard", "processing", "toolResult"
    var documentFileId: String = ""     // UUID string of linked DocumentFile
    var resultDataJSON: String = ""     // JSON payload for tool results
    var inlineToolType: String = ""     // "ocr", "summarize", "compress", "watermark"

    var conversation: Conversation?

    @Transient var isUser: Bool {
        role == "user"
    }

    @Transient var isAssistant: Bool {
        role == "assistant"
    }

    @Transient private var _cachedActions: [ChatAction]?
    @Transient private var _cachedActionsJSON: String?

    @Transient var actions: [ChatAction] {
        if let cached = _cachedActions, _cachedActionsJSON == actionsJSON {
            return cached
        }
        guard let json = actionsJSON, let data = json.data(using: .utf8) else { return [] }
        let decoded = (try? JSONDecoder().decode([ChatAction].self, from: data)) ?? []
        _cachedActions = decoded
        _cachedActionsJSON = actionsJSON
        return decoded
    }

    /// Creates a lightweight ChatMessage for passing conversation history to AI providers.
    /// Not inserted into SwiftData — used only as a transient in-memory object.
    static func makeTransient(content: String, role: String) -> ChatMessage {
        // Use a dummy conversation ID; this message is never persisted
        let msg = ChatMessage(transientContent: content, role: role)
        return msg
    }

    /// Private init for transient (non-persisted) messages
    private init(transientContent: String, role: String) {
        self.id = UUID()
        self.content = transientContent
        self.role = role
        self.timestamp = .now
        self.conversationId = UUID()
        self.conversation = nil
        self.toolBadge = nil
        self.messageType = ""
        self.documentFileId = ""
        self.resultDataJSON = ""
        self.inlineToolType = ""
    }

    init(
        content: String,
        role: String,
        conversation: Conversation,
        toolBadge: String? = nil,
        actions: [ChatAction] = [],
        messageType: String = "",
        documentFileId: String = "",
        resultDataJSON: String = "",
        inlineToolType: String = ""
    ) {
        self.id = UUID()
        self.content = content
        self.role = role
        self.timestamp = .now
        self.conversationId = conversation.id
        self.conversation = conversation
        self.toolBadge = toolBadge
        self.messageType = messageType
        self.documentFileId = documentFileId
        self.resultDataJSON = resultDataJSON
        self.inlineToolType = inlineToolType
        if !actions.isEmpty, let data = try? JSONEncoder().encode(actions) {
            self.actionsJSON = String(data: data, encoding: .utf8)
        }
    }
}
