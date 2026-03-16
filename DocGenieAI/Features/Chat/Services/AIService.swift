import Foundation
import SwiftData
#if canImport(FoundationModels)
import FoundationModels
#endif

@MainActor
@Observable
final class AIService {
    static let shared = AIService()

    enum AIBackend: String {
        case foundationModels
        case keywordMatching
    }

    private(set) var activeBackend: AIBackend
    private let provider: any AIResponseProvider

    var isOnDeviceAIAvailable: Bool {
        activeBackend == .foundationModels
    }

    private init() {
        #if canImport(FoundationModels)
        if #available(iOS 26, *) {
            let model = SystemLanguageModel.default
            if case .available = model.availability {
                let fmProvider = FoundationModelsProvider()
                self.provider = fmProvider
                self.activeBackend = .foundationModels
                return
            }
        }
        #endif
        self.provider = KeywordMatchingProvider()
        self.activeBackend = .keywordMatching
    }

    func generateResponse(for input: String, conversationHistory: [ChatMessage], memories: [ChatMemory] = []) async throws -> AIResponse {
        // Enrich input with memories if available
        let enrichedInput = memories.isEmpty ? input : enrichWithMemories(input, memories: memories)
        return try await provider.generateResponse(for: enrichedInput, conversationHistory: conversationHistory)
    }

    func streamResponse(
        for input: String,
        conversationHistory: [ChatMessage],
        memories: [ChatMemory] = [],
        onPartialUpdate: @MainActor @Sendable (String) -> Void
    ) async throws -> AIResponse {
        let enrichedInput = memories.isEmpty ? input : enrichWithMemories(input, memories: memories)
        return try await provider.streamResponse(
            for: enrichedInput,
            conversationHistory: conversationHistory,
            onPartialUpdate: onPartialUpdate
        )
    }

    var supportsStreaming: Bool { provider.supportsStreaming }

    func resetSession() { provider.resetSession() }

    private func enrichWithMemories(_ input: String, memories: [ChatMemory]) -> String {
        let memoryBlock = memories
            .sorted { $0.lastUsedAt > $1.lastUsedAt }
            .prefix(10)
            .map { "- \($0.content)" }
            .joined(separator: "\n")
        return "[User context from memory]\n\(memoryBlock)\n[End context]\n\nUser message: \(input)"
    }
}

// MARK: - Memory Service

@MainActor
@Observable
final class MemoryService {
    static let shared = MemoryService()
    private init() {}

    /// Extract potential memories from a conversation turn
    func extractMemories(userMessage: String, aiResponse: String) -> [String] {
        var memories: [String] = []
        let lower = userMessage.lowercased()

        // Detect preferences
        let preferencePatterns = [
            "i prefer", "i like", "i always", "i usually", "my favorite",
            "please always", "don't ", "never ", "i want you to",
        ]
        for pattern in preferencePatterns {
            if lower.contains(pattern) {
                memories.append("User preference: \(userMessage)")
                break
            }
        }

        // Detect facts about the user
        let factPatterns = [
            "my name is", "i work at", "i'm a", "i am a", "my company",
            "my email", "my phone", "i live in", "my job",
        ]
        for pattern in factPatterns {
            if lower.contains(pattern) {
                memories.append("User fact: \(userMessage)")
                break
            }
        }

        // Detect "remember this" explicit requests
        if lower.contains("remember") || lower.contains("keep in mind") || lower.contains("note that") {
            memories.append("User asked to remember: \(userMessage)")
        }

        return memories
    }

    /// Save a memory to SwiftData
    func saveMemory(_ content: String, category: String = "fact", context: ModelContext) {
        // Deduplicate — don't save if similar memory exists
        let existing = (try? context.fetch(FetchDescriptor<ChatMemory>())) ?? []
        let isDuplicate = existing.contains { $0.content.lowercased() == content.lowercased() }
        guard !isDuplicate else { return }

        // Limit total memories to 50 — evict oldest
        if existing.count >= 50 {
            if let oldest = existing.sorted(by: { $0.lastUsedAt < $1.lastUsedAt }).first {
                context.delete(oldest)
            }
        }

        let memory = ChatMemory(content: content, category: category)
        context.insert(memory)
        try? context.save()
    }

    /// Fetch all memories sorted by relevance (most used + most recent)
    func fetchMemories(context: ModelContext) -> [ChatMemory] {
        let descriptor = FetchDescriptor<ChatMemory>(
            sortBy: [SortDescriptor(\.lastUsedAt, order: .reverse)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    /// Delete a specific memory
    func deleteMemory(_ memory: ChatMemory, context: ModelContext) {
        context.delete(memory)
        try? context.save()
    }

    /// Clear all memories
    func clearAllMemories(context: ModelContext) {
        let all = fetchMemories(context: context)
        for memory in all { context.delete(memory) }
        try? context.save()
    }
}
