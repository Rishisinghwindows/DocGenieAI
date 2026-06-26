//
//  SpotlightIndexingService.swift
//  Olea
//
//  Role: Indexes every non-vault document into CoreSpotlight so users can find
//  Olea content from iOS system search — Spotlight, Lock Screen search, and
//  Siri Suggestions — without opening the app first.
//
//  Privacy contract:
//    • Vault documents are NEVER indexed. The Vault is the one surface where
//      the user explicitly opted into "this is private" — leaking a vault doc
//      title or OCR snippet into Spotlight would break that promise.
//    • The toggle `spotlightIndexingEnabled` (Settings → Privacy) lets users
//      opt out entirely. When flipped off we eagerly call `clearAll()`.
//
//  Payload per item (CSSearchableItemAttributeSet):
//    • title              = DocumentFile.aiSuggestedName ?? name
//    • contentDescription = first 800 chars of OCR or aiSummary
//    • keywords           = [tag, category, aiContentType, fileExtension]
//    • thumbnailURL       = file URL (Spotlight will render PDFKit/Image thumb)
//    • contentType        = UTType (best-effort from extension)
//
//  Item identifier = DocumentFile.id.uuidString. Tap handler in OleaApp reads
//  this back via NSUserActivity and asks the router to open the file.
//
//  Bulk reindex:
//    First launch after enabling the feature (or after the schema bump), we
//    rebuild the entire index in one batch. Bump `SpotlightIndexingService
//    .schemaVersion` whenever the payload structure changes to force a one-
//    time rebuild on existing installs.
//

import Foundation
import CoreSpotlight
import UniformTypeIdentifiers

@MainActor
final class SpotlightIndexingService {
    static let shared = SpotlightIndexingService()
    private init() {}

    static let domainIdentifier = "com.olea.documents"
    static let defaultsEnabledKey = "spotlightIndexingEnabled"
    static let defaultsBulkVersionKey = "spotlightBulkIndexedSchemaVersion"
    /// Bump when the indexed payload structure changes — forces a one-time
    /// bulk rebuild on next launch for existing users.
    static let schemaVersion = 1

    var isEnabled: Bool {
        // Default to true. Stored explicitly only if the user toggles off.
        let defaults = UserDefaults.standard
        if defaults.object(forKey: Self.defaultsEnabledKey) == nil { return true }
        return defaults.bool(forKey: Self.defaultsEnabledKey)
    }

    // MARK: - Single-item lifecycle

    /// Index (or refresh) a single document. Safe to call repeatedly — the
    /// existing item is replaced atomically.
    func index(_ doc: DocumentFile) {
        guard isEnabled else { return }
        guard !doc.isInVault else {
            // Belt-and-suspenders: also explicitly remove in case it was
            // indexed prior to being moved into the vault.
            remove(id: doc.id)
            return
        }
        let item = makeItem(for: doc)
        // Capture the ID up front so the @Sendable completion closure doesn't
        // capture the non-Sendable DocumentFile across the actor boundary.
        let docID = doc.id.uuidString
        CSSearchableIndex.default().indexSearchableItems([item]) { error in
            if let error {
                AppLogger.ui.error("Spotlight index failed for \(docID, privacy: .public): \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    /// Remove a document from the index. Safe to call for IDs that were never
    /// indexed (no-op).
    func remove(id: UUID) {
        CSSearchableIndex.default().deleteSearchableItems(withIdentifiers: [id.uuidString]) { error in
            if let error {
                AppLogger.ui.error("Spotlight remove failed for \(id.uuidString, privacy: .public): \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    // MARK: - Bulk operations

    /// Index every non-vault document in one batch. Called on first launch
    /// after the schema version bumps, and from the Settings "Rebuild Index"
    /// button.
    func bulkReindex(_ docs: [DocumentFile]) {
        guard isEnabled else { return }
        let items = docs
            .filter { !$0.isInVault }
            .map(makeItem(for:))
        guard !items.isEmpty else { return }
        // Snapshot the actor-isolated statics into locals so the @Sendable
        // closure doesn't have to hop back onto the main actor to read them.
        let schemaVersion = Self.schemaVersion
        let versionKey = Self.defaultsBulkVersionKey
        CSSearchableIndex.default().indexSearchableItems(items) { error in
            if let error {
                AppLogger.ui.error("Spotlight bulk reindex failed: \(error.localizedDescription, privacy: .public)")
            } else {
                UserDefaults.standard.set(schemaVersion, forKey: versionKey)
            }
        }
    }

    /// Wipe every Olea-owned item out of Spotlight. Used when the user turns
    /// indexing off in Settings or to recover from a bad batch.
    func clearAll() {
        let versionKey = Self.defaultsBulkVersionKey
        CSSearchableIndex.default().deleteSearchableItems(withDomainIdentifiers: [Self.domainIdentifier]) { error in
            if let error {
                AppLogger.ui.error("Spotlight clearAll failed: \(error.localizedDescription, privacy: .public)")
            } else {
                UserDefaults.standard.removeObject(forKey: versionKey)
            }
        }
    }

    /// Returns true if the persisted schema version matches the current build,
    /// i.e. no bulk rebuild is needed. Caller is responsible for actually
    /// running the rebuild and waiting on completion.
    var hasCompletedBulkIndex: Bool {
        UserDefaults.standard.integer(forKey: Self.defaultsBulkVersionKey) == Self.schemaVersion
    }

    // MARK: - Item construction

    private func makeItem(for doc: DocumentFile) -> CSSearchableItem {
        let contentType = UTType(filenameExtension: doc.fileExtension) ?? .data
        let attrs = CSSearchableItemAttributeSet(contentType: contentType)

        let displayTitle = doc.aiSuggestedName?.isEmpty == false ? doc.aiSuggestedName! : doc.name
        attrs.title = displayTitle
        attrs.displayName = displayTitle

        if let summary = doc.aiSummary, !summary.isEmpty {
            attrs.contentDescription = summary
        } else if let ocr = doc.ocrTextCache, !ocr.isEmpty {
            attrs.contentDescription = String(ocr.prefix(800))
        }

        var keywords: [String] = []
        if let tag = doc.tagName { keywords.append(tag) }
        if let aiType = doc.aiContentType { keywords.append(aiType) }
        keywords.append(doc.category.rawValue)
        keywords.append(doc.fileExtension)
        attrs.keywords = keywords

        if let url = doc.fileURL {
            // PDFKit/Image renders the thumbnail from the URL for free.
            attrs.thumbnailURL = url
            attrs.contentURL = url
        }

        attrs.contentCreationDate = doc.originalCreatedAt ?? doc.importedAt

        if let expiry = doc.expiryDate {
            // Spotlight surfaces "expires soon" content higher in Siri Suggestions.
            attrs.dueDate = expiry
        }

        return CSSearchableItem(
            uniqueIdentifier: doc.id.uuidString,
            domainIdentifier: Self.domainIdentifier,
            attributeSet: attrs
        )
    }
}
