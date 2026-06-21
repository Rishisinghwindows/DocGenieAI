//
//  SmartIntents.swift
//  DocGenieAI
//
//  Role: AppIntents-level surface for Siri / Spotlight / Shortcuts integration.
//  Exposes DocumentFile and DocumentFolder as AppEntities so the system can
//  autocomplete them in voice commands, and ships two concrete intents:
//
//    • FindDocumentsIntent  — search the library by name + OCR content
//    • FileDocumentIntent   — move a doc into a folder
//
//  Why AppEntity vs. plain AppIntent string args: AppShortcuts can only
//  reference one entity parameter per phrase, but the EntityQuery /
//  EntityStringQuery support gives Siri rich autocomplete from the user's
//  actual document library — "Find the lease from 2024" surfaces real
//  matches in Spotlight as you type.
//
//  Concurrency: intents run on @MainActor because they read SwiftData. They
//  use SharedModelContainer (NOT a parallel container) to avoid the
//  corruption class described in SharedModelContainer.swift.
//

import AppIntents
import SwiftData
import Foundation

// MARK: - Document AppEntity

struct DocumentEntity: AppEntity, Identifiable {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Document")
    static let defaultQuery = DocumentEntityQuery()

    let id: UUID
    let name: String
    let fileExtension: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "\(name).\(fileExtension)"
        )
    }
}

struct DocumentEntityQuery: EntityQuery {
    func entities(for identifiers: [DocumentEntity.ID]) async throws -> [DocumentEntity] {
        try await SmartIntentStore.shared.documents(matchingIDs: identifiers)
    }

    func suggestedEntities() async throws -> [DocumentEntity] {
        try await SmartIntentStore.shared.recentDocuments(limit: 10)
    }
}

extension DocumentEntityQuery: EntityStringQuery {
    func entities(matching string: String) async throws -> [DocumentEntity] {
        try await SmartIntentStore.shared.documents(matchingName: string, limit: 10)
    }
}

// MARK: - Folder AppEntity

struct FolderEntity: AppEntity, Identifiable {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Folder")
    static let defaultQuery = FolderEntityQuery()

    let id: UUID
    let name: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }
}

struct FolderEntityQuery: EntityQuery {
    func entities(for identifiers: [FolderEntity.ID]) async throws -> [FolderEntity] {
        try await SmartIntentStore.shared.folders(matchingIDs: identifiers)
    }

    func suggestedEntities() async throws -> [FolderEntity] {
        try await SmartIntentStore.shared.allFolders()
    }
}

extension FolderEntityQuery: EntityStringQuery {
    func entities(matching string: String) async throws -> [FolderEntity] {
        try await SmartIntentStore.shared.folders(matchingName: string)
    }
}

// MARK: - Intents

/// "Find my Verizon bill" — searches by name + OCR cache.
struct FindDocumentsIntent: AppIntent {
    static let title: LocalizedStringResource = "Find Documents"
    static let description = IntentDescription(
        "Search your DocSage library by file name or content.",
        categoryName: "Documents"
    )
    static let openAppWhenRun = false

    @Parameter(title: "Query")
    var query: String

    func perform() async throws -> some IntentResult & ReturnsValue<[DocumentEntity]> & ProvidesDialog {
        let matches = try await SmartIntentStore.shared.searchDocuments(query: query, limit: 5)
        let dialog: IntentDialog
        if matches.isEmpty {
            dialog = IntentDialog("No documents matched \"\(query)\".")
        } else if matches.count == 1 {
            dialog = IntentDialog("Found \(matches[0].name).")
        } else {
            let names = matches.prefix(3).map(\.name).joined(separator: ", ")
            dialog = IntentDialog("Found \(matches.count) documents: \(names).")
        }
        return .result(value: matches, dialog: dialog)
    }
}

/// "File the latest scan in Taxes 2026" — moves a doc into a folder.
struct FileDocumentIntent: AppIntent {
    static let title: LocalizedStringResource = "File Document"
    static let description = IntentDescription(
        "Move a document into one of your folders.",
        categoryName: "Documents"
    )
    static let openAppWhenRun = false

    @Parameter(title: "Document")
    var document: DocumentEntity

    @Parameter(title: "Folder")
    var folder: FolderEntity

    func perform() async throws -> some IntentResult & ProvidesDialog {
        try await SmartIntentStore.shared.fileDocument(documentID: document.id, into: folder.id)
        return .result(dialog: "Moved \(document.name) to \(folder.name).")
    }
}

// MARK: - Backing store

/// Bridges AppIntents (which run outside the main app process) to the SwiftData store.
@MainActor
final class SmartIntentStore {
    static let shared = SmartIntentStore()
    private init() {}

    private func context() throws -> ModelContext {
        ModelContext(SharedModelContainer.shared)
    }

    func recentDocuments(limit: Int) async throws -> [DocumentEntity] {
        let ctx = try context()
        var descriptor = FetchDescriptor<DocumentFile>(
            sortBy: [SortDescriptor(\.lastOpenedAt, order: .reverse), SortDescriptor(\.importedAt, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        let files = try ctx.fetch(descriptor)
        return files.map { DocumentEntity(id: $0.id, name: $0.name, fileExtension: $0.fileExtension) }
    }

    func documents(matchingIDs ids: [UUID]) async throws -> [DocumentEntity] {
        let ctx = try context()
        let descriptor = FetchDescriptor<DocumentFile>(predicate: #Predicate { ids.contains($0.id) })
        return try ctx.fetch(descriptor).map { DocumentEntity(id: $0.id, name: $0.name, fileExtension: $0.fileExtension) }
    }

    func documents(matchingName name: String, limit: Int) async throws -> [DocumentEntity] {
        guard !name.isEmpty else { return [] }
        let ctx = try context()
        let descriptor = FetchDescriptor<DocumentFile>(
            predicate: #Predicate { $0.name.localizedStandardContains(name) },
            sortBy: [SortDescriptor(\.importedAt, order: .reverse)]
        )
        var clamped = descriptor
        clamped.fetchLimit = limit
        return try ctx.fetch(clamped).map { DocumentEntity(id: $0.id, name: $0.name, fileExtension: $0.fileExtension) }
    }

    /// Full search: matches name OR cached OCR text. Sorted by recency.
    func searchDocuments(query: String, limit: Int) async throws -> [DocumentEntity] {
        guard !query.isEmpty else { return [] }
        let ctx = try context()
        let descriptor = FetchDescriptor<DocumentFile>(
            sortBy: [SortDescriptor(\.importedAt, order: .reverse)]
        )
        let all = try ctx.fetch(descriptor)
        let lower = query.lowercased()
        let scored: [(DocumentFile, Int)] = all.compactMap { file in
            var score = 0
            if file.name.lowercased().contains(lower) { score += 10 }
            if let cache = file.ocrTextCache?.lowercased(), cache.contains(lower) { score += 5 }
            return score > 0 ? (file, score) : nil
        }
        return scored
            .sorted { $0.1 > $1.1 }
            .prefix(limit)
            .map { DocumentEntity(id: $0.0.id, name: $0.0.name, fileExtension: $0.0.fileExtension) }
    }

    func allFolders() async throws -> [FolderEntity] {
        let ctx = try context()
        let descriptor = FetchDescriptor<DocumentFolder>(sortBy: [SortDescriptor(\.name)])
        return try ctx.fetch(descriptor).map { FolderEntity(id: $0.id, name: $0.name) }
    }

    func folders(matchingIDs ids: [UUID]) async throws -> [FolderEntity] {
        let ctx = try context()
        let descriptor = FetchDescriptor<DocumentFolder>(predicate: #Predicate { ids.contains($0.id) })
        return try ctx.fetch(descriptor).map { FolderEntity(id: $0.id, name: $0.name) }
    }

    func folders(matchingName name: String) async throws -> [FolderEntity] {
        guard !name.isEmpty else { return try await allFolders() }
        let ctx = try context()
        let descriptor = FetchDescriptor<DocumentFolder>(
            predicate: #Predicate { $0.name.localizedStandardContains(name) },
            sortBy: [SortDescriptor(\.name)]
        )
        return try ctx.fetch(descriptor).map { FolderEntity(id: $0.id, name: $0.name) }
    }

    func fileDocument(documentID: UUID, into folderID: UUID) async throws {
        let ctx = try context()
        let docDescriptor = FetchDescriptor<DocumentFile>(predicate: #Predicate { $0.id == documentID })
        let folderDescriptor = FetchDescriptor<DocumentFolder>(predicate: #Predicate { $0.id == folderID })
        guard let document = try ctx.fetch(docDescriptor).first else { throw IntentStoreError.documentNotFound }
        guard try ctx.fetch(folderDescriptor).first != nil else { throw IntentStoreError.folderNotFound }
        document.folderID = folderID
        try ctx.save()
    }
}

private enum IntentStoreError: Error, LocalizedError {
    case unavailable
    case documentNotFound
    case folderNotFound

    var errorDescription: String? {
        switch self {
        case .unavailable: return "DocSage data store unavailable."
        case .documentNotFound: return "That document was not found."
        case .folderNotFound: return "That folder was not found."
        }
    }
}
