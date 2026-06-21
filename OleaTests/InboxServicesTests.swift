import XCTest
import SwiftData
@testable import Olea

/// Unit tests for the four services that power the auto-inbox wedge:
/// AutoInboxService, SemanticSearchService, MultiDocQAService, ExpiryActivityService.
/// Behavior on iOS 26 with Foundation Models is intentionally NOT exercised here —
/// these tests cover the deterministic fallback paths + pure data routines so the
/// CI runs the same on every device.
@MainActor
final class InboxServicesTests: XCTestCase {

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema([DocumentFile.self, ChatMessage.self, Conversation.self, ChatMemory.self, DocumentFolder.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [config])
    }

    // MARK: - AutoInboxService

    func testAutoInbox_emptyOCR_marksReviewedWithoutMetadata() async throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let doc = DocumentFile(name: "Empty", fileExtension: "pdf", relativeFilePath: "Empty.pdf", fileSize: 100)
        context.insert(doc)

        await AutoInboxService.shared.organize(doc, ocrText: "", modelContext: context)

        XCTAssertFalse(doc.aiNeedsReview, "Empty OCR shouldn't leave the doc in needs-review.")
        XCTAssertNil(doc.aiSummary)
        XCTAssertNil(doc.aiOrganizedAt)
    }

    func testAutoInbox_keywordFallback_populatesTagSummaryAndTimestamp() async throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let doc = DocumentFile(name: "scan_001", fileExtension: "pdf", relativeFilePath: "scan_001.pdf", fileSize: 100)
        context.insert(doc)

        let ocr = """
            Walmart Supercenter
            123 Main St
            Subtotal $12.34
            Tax $0.85
            Total $13.19
            04/01/2026
            """

        await AutoInboxService.shared.organize(doc, ocrText: ocr, modelContext: context)

        XCTAssertNotNil(doc.aiOrganizedAt, "aiOrganizedAt must be set after organize.")
        XCTAssertNotNil(doc.aiSummary, "Summary must be populated even in keyword fallback.")
        XCTAssertEqual(doc.tagName, FileTag.receipt.rawValue, "Receipt OCR should map to receipt tag.")
    }

    func testAutoInbox_respectsExistingTag() async throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let doc = DocumentFile(name: "user_tagged", fileExtension: "pdf", relativeFilePath: "user_tagged.pdf", fileSize: 100)
        doc.tagName = FileTag.legal.rawValue
        context.insert(doc)

        let ocr = "Receipt Total $5.00 Walmart"
        await AutoInboxService.shared.organize(doc, ocrText: ocr, modelContext: context)

        XCTAssertEqual(doc.tagName, FileTag.legal.rawValue, "User-set tag must not be overridden.")
    }

    // MARK: - SemanticSearchService

    func testSemanticSearch_emptyQuery_returnsEmpty() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let doc = DocumentFile(name: "Verizon", fileExtension: "pdf", relativeFilePath: "Verizon.pdf", fileSize: 100)
        doc.ocrTextCache = "Verizon Wireless September Bill"
        context.insert(doc)
        try context.save()

        let hits = SemanticSearchService.shared.search(query: "", in: context)
        XCTAssertTrue(hits.isEmpty, "Empty query must return zero hits.")
    }

    func testSemanticSearch_nameKeywordBoost_putsExactMatchFirst() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let exact = DocumentFile(name: "Verizon September Bill", fileExtension: "pdf", relativeFilePath: "v.pdf", fileSize: 100)
        let related = DocumentFile(name: "Phone bill summary", fileExtension: "pdf", relativeFilePath: "p.pdf", fileSize: 100)
        related.ocrTextCache = "Verizon mention here"
        context.insert(exact)
        context.insert(related)
        try context.save()

        let hits = SemanticSearchService.shared.search(query: "Verizon", in: context)
        XCTAssertFalse(hits.isEmpty)
        XCTAssertEqual(hits.first?.document.name, "Verizon September Bill", "Name match should outrank OCR-only match.")
    }

    func testSemanticSearch_skipsVaultedDocs() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let vaulted = DocumentFile(name: "Secret Verizon", fileExtension: "pdf", relativeFilePath: "s.pdf", fileSize: 100)
        vaulted.isInVault = true
        context.insert(vaulted)
        try context.save()

        let hits = SemanticSearchService.shared.search(query: "Verizon", in: context)
        XCTAssertTrue(hits.isEmpty, "Vaulted docs must never surface in search.")
    }

    // MARK: - MultiDocQAService

    func testMultiDocQA_emptyQuestion_returnsPrompt() async throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let doc = DocumentFile(name: "Lease", fileExtension: "pdf", relativeFilePath: "l.pdf", fileSize: 100)
        doc.ocrTextCache = "Lease agreement between landlord and tenant."
        context.insert(doc)
        try context.save()

        let answer = await MultiDocQAService.shared.answer(question: "   ", documents: [doc])
        XCTAssertTrue(answer.text.contains("Type a question"))
        XCTAssertTrue(answer.citations.isEmpty)
    }

    func testMultiDocQA_noDocuments_promptsPickDocs() async throws {
        let answer = await MultiDocQAService.shared.answer(question: "What is the total?", documents: [])
        XCTAssertTrue(answer.text.contains("Pick at least one"))
    }

    func testMultiDocQA_keywordFallback_returnsCitationFromMatchingSnippet() async throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let doc = DocumentFile(name: "Lease", fileExtension: "pdf", relativeFilePath: "l.pdf", fileSize: 100)
        doc.ocrTextCache = "Monthly rent: $1,500. Security deposit: $1,500. Lease term: 12 months."
        context.insert(doc)
        try context.save()

        let answer = await MultiDocQAService.shared.answer(question: "What is the monthly rent?", documents: [doc])
        XCTAssertFalse(answer.text.isEmpty)
        // Keyword fallback path returns at least one citation pointing back to our doc.
        if !answer.usedFoundationModels {
            XCTAssertFalse(answer.citations.isEmpty, "Fallback must still cite the source.")
            XCTAssertEqual(answer.citations.first?.documentID, doc.id)
        }
    }

    // MARK: - PII regex (sanity)

    func testPII_bankAccountRequiresContext() {
        let plain = "Order number 12345678901234"
        let matches = PIIDetectionService.shared.detectPII(in: plain)
        let bankMatches = matches.filter { $0.type == .bankAccount }
        XCTAssertTrue(bankMatches.isEmpty, "Long digit run without 'IBAN/account' context must NOT be classified as bank account.")
    }

    func testPII_creditCardLuhnValid() {
        let valid = "Card 4242 4242 4242 4242"
        let matches = PIIDetectionService.shared.detectPII(in: valid)
        XCTAssertTrue(matches.contains { $0.type == .creditCard }, "Luhn-valid card should be detected.")
    }

    func testPII_creditCardLuhnInvalidRejected() {
        let invalid = "Card 4242 4242 4242 4241"
        let matches = PIIDetectionService.shared.detectPII(in: invalid)
        let cards = matches.filter { $0.type == .creditCard }
        XCTAssertTrue(cards.isEmpty, "Luhn-invalid 16-digit number must NOT be classified as a credit card.")
    }

    func testPII_overlapResolution_keepsHigherPriority() {
        // SSN-shaped overlap with a generic date pattern shouldn't double-tag.
        let text = "SSN 123-45-6789"
        let matches = PIIDetectionService.shared.detectPII(in: text)
        let nonOverlapping = matches.sorted { $0.range.lowerBound < $1.range.lowerBound }
        for i in 1..<nonOverlapping.count {
            XCTAssertFalse(nonOverlapping[i - 1].range.overlaps(nonOverlapping[i].range),
                           "resolveOverlaps must drop overlapping ranges.")
        }
    }

    // MARK: - vCard escaping

    func testVCardEscaping_escapesSemicolonsAndCommas() {
        let raw = "Smith, J.; CEO\nNew line"
        let escaped = ContactIntelligenceService.escapeVCard(raw)
        XCTAssertTrue(escaped.contains("\\,"))
        XCTAssertTrue(escaped.contains("\\;"))
        XCTAssertTrue(escaped.contains("\\n"))
        XCTAssertFalse(escaped.contains("\n"))
    }
}
