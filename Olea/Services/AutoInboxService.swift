//
//  AutoInboxService.swift
//  DocGenieAI
//
//  Role: The "magic" engine behind the Inbox tab. After every document import,
//  this service reads the OCR text, asks Apple's Foundation Models to derive
//  structured metadata (tag, suggested filename, content type, expiry, summary),
//  computes a semantic embedding for search, and writes everything back onto the
//  DocumentFile. Users see one card per organized doc with one-tap correction.
//
//  iOS 26+: Foundation Models @Generable structured output.
//  iOS <26 / Apple-Intelligence-ineligible devices: keyword classifier fallback
//  via AutoCategorizeService so the feature degrades gracefully rather than dying.
//
//  Threading: @MainActor. Called from FileImportService after OCR completes.
//

import Foundation
import SwiftData
#if canImport(FoundationModels)
import FoundationModels
#endif

@MainActor
final class AutoInboxService {
    /// Singleton because there is exactly one inbox per app session, and the
    /// (lazy) Foundation Models LanguageModelSession is expensive to construct.
    static let shared = AutoInboxService()
    private init() {}

    /// Result of running a doc through the inbox pipeline. Mirrored onto the
    /// `DocumentFile` (ai* fields) by `organize(_:ocrText:modelContext:)`.
    struct InboxResult {
        var tag: FileTag?
        var suggestedName: String?
        var summary: String
        /// Free-form content-type bucket: receipt, invoice, letter, contract,
        /// id, form, statement, other. Mirrors `DocumentFile.aiContentType`.
        var contentType: String
        var expiryDate: Date?
        /// 0.0–1.0. Anything below 0.5 should surface as "needs review" in UI.
        var confidence: Double
    }

    /// Process the OCR text of a freshly-imported document and derive structured
    /// metadata. Writes the result to the DocumentFile in place. Safe to call from
    /// background tasks; uses on-device only — no network.
    func organize(_ document: DocumentFile, ocrText: String, modelContext: ModelContext) async {
        guard !ocrText.isEmpty else {
            document.aiNeedsReview = false
            return
        }

        let result = await derive(ocrText: ocrText, currentName: document.name)

        document.aiSummary = result.summary
        document.aiSuggestedName = result.suggestedName
        document.aiContentType = result.contentType
        document.aiOrganizedAt = .now
        document.aiNeedsReview = true

        // Apply tag only if the user hasn't already set one
        if document.tagName == nil, let tag = result.tag {
            document.tagName = tag.rawValue
        }

        // Apply expiry only if the user hasn't already set one and we found a date
        if document.expiryDate == nil, let expiry = result.expiryDate {
            document.expiryDate = expiry
        }

        // Compute embedding for semantic search
        document.embedding = SemanticSearchService.shared.embedding(for: ocrText, name: document.aiSuggestedName ?? document.name)

        try? modelContext.save()
        AppLogger.ai.info("AutoInbox organized \(document.name, privacy: .public) → \(result.contentType, privacy: .public)/\(result.tag?.rawValue ?? "untagged", privacy: .public) (conf \(result.confidence, format: .fixed(precision: 2)))")
    }

    /// Bulk re-process: organize every doc that doesn't yet have aiOrganizedAt.
    /// Used when the user upgrades to a build that supports AutoInbox, or after a
    /// tap of "Organize my library" in Settings.
    func organizeBacklog(modelContext: ModelContext, limit: Int = 100) async {
        let predicate = #Predicate<DocumentFile> { $0.aiOrganizedAt == nil && $0.isInVault == false }
        var descriptor = FetchDescriptor<DocumentFile>(predicate: predicate, sortBy: [SortDescriptor(\.importedAt, order: .reverse)])
        descriptor.fetchLimit = limit
        guard let backlog = try? modelContext.fetch(descriptor) else { return }
        for doc in backlog {
            let ocr = doc.ocrTextCache ?? ""
            await organize(doc, ocrText: ocr, modelContext: modelContext)
        }
    }

    // MARK: - Derive

    private func derive(ocrText: String, currentName: String) async -> InboxResult {
        #if canImport(FoundationModels)
        if #available(iOS 26, *), case .available = SystemLanguageModel.default.availability {
            if let result = await deriveFM(ocrText: ocrText, currentName: currentName) {
                return result
            }
        }
        #endif
        return deriveKeyword(ocrText: ocrText, currentName: currentName)
    }

    // MARK: - Foundation Models path

    #if canImport(FoundationModels)
    @available(iOS 26, *)
    @Generable
    struct InboxClassification {
        @Guide(description: "One of: work, personal, invoice, receipt, legal, archive")
        var tag: String

        @Guide(description: "A short, human-readable filename without extension. Use the format 'Document Type - Key Identifier - Date' when possible. E.g. 'Verizon Bill - July 2026', 'Lease - 123 Main St - Jan 2024'. Max 60 chars.")
        var suggestedName: String

        @Guide(description: "A 1-2 sentence factual summary of what the document is and what it contains. No marketing language.")
        var summary: String

        @Guide(description: "One of: receipt, invoice, letter, contract, id, form, statement, other")
        var contentType: String

        @Guide(description: "If the document mentions an expiration, due date, or end date, emit it as YYYY-MM-DD. Otherwise empty string.")
        var expiryDate: String

        @Guide(description: "Confidence 0.0-1.0 that the classification is correct based on the available text.")
        var confidence: Double
    }

    @available(iOS 26, *)
    private func deriveFM(ocrText: String, currentName: String) async -> InboxResult? {
        let session = LanguageModelSession(instructions: """
            You are an inbox-organizer for a document app. Given OCR text from a scanned or imported document, return structured metadata. Be precise; if you cannot tell, use 'archive' tag and 'other' content type with low confidence rather than guessing.
            """)

        // Cap the prompt — Foundation Models has a context limit and we only need
        // enough to classify, not the whole doc.
        let snippet = String(ocrText.prefix(3500))
        let prompt = """
            Original filename: \(currentName)
            OCR text:
            \(snippet)
            """

        do {
            let response = try await session.respond(to: prompt, generating: InboxClassification.self)
            let cls = response.content
            return InboxResult(
                tag: FileTag(rawValue: cls.tag.capitalized),
                suggestedName: cls.suggestedName.trimmingCharacters(in: .whitespacesAndNewlines),
                summary: cls.summary,
                contentType: cls.contentType,
                expiryDate: ISODateParser.yyyyMMdd.date(from: cls.expiryDate),
                confidence: cls.confidence
            )
        } catch {
            AppLogger.ai.error("AutoInbox FM call failed: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }
    #endif

    // MARK: - Keyword fallback

    private func deriveKeyword(ocrText: String, currentName: String) -> InboxResult {
        let categorization = AutoCategorizeService.shared.categorize(ocrText: ocrText, fileName: currentName)
        let summary = makeKeywordSummary(ocrText: ocrText, contentType: categorization.contentType)
        return InboxResult(
            tag: categorization.suggestedTag,
            suggestedName: categorization.suggestedName,
            summary: summary,
            contentType: contentTypeKey(for: categorization.contentType),
            expiryDate: nil,
            confidence: categorization.confidence
        )
    }

    private func makeKeywordSummary(ocrText: String, contentType: ScanContentType) -> String {
        let lines = ocrText.split(separator: "\n").prefix(3).joined(separator: " ")
        let snippet = String(lines.prefix(120))
        return "\(contentType.displayLabel). \(snippet)"
    }

    private func contentTypeKey(for type: ScanContentType) -> String {
        switch type {
        case .receipt: return "receipt"
        case .businessCard: return "id"
        case .letter: return "letter"
        case .form: return "form"
        case .textHeavy: return "other"
        default: return "other"
        }
    }
}

// MARK: - ISO date helper

private enum ISODateParser {
    static let yyyyMMdd: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "UTC")
        return f
    }()
}
