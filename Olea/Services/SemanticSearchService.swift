//
//  SemanticSearchService.swift
//  DocGenieAI
//
//  Role: On-device semantic search across the user's document library. Powers
//  the universal "Find anything…" bar at the top of the Inbox tab.
//
//  Approach:
//    1. Per-doc embedding (call `embedding(for:name:)` once at import time;
//       stored as packed Float bytes in `DocumentFile.embedding`).
//    2. At query time, embed the search string, then score every non-vault
//       doc by cosine similarity + keyword boost (so exact substring matches
//       always outrank fuzzy semantic ones).
//    3. Snippet extraction returns the ±80-char window around the best
//       keyword hit, or the AI summary if the query was purely semantic.
//
//  Fallbacks: if `NLEmbedding.sentenceEmbedding(for: .english)` returns nil
//  (locale unsupported), embeddings are skipped and the keyword boost alone
//  drives ranking — so the feature still works, just less smart.
//
//  Locale: today only English embeddings are wired. Extending to additional
//  locales is a constructor change (detect `Locale.current.language` and
//  request the matching embedding family).
//

import Foundation
import NaturalLanguage
import SwiftData

@MainActor
final class SemanticSearchService {
    static let shared = SemanticSearchService()

    /// Dimensionality of the underlying sentence embedding. Stored to validate
    /// packed embeddings before unpacking — guards against model upgrades that
    /// change the vector size between app launches.
    private let dim: Int

    /// Lazy-loaded NLEmbedding instance. Construction is non-trivial (loads
    /// model data), hence the singleton pattern around this service.
    private let model: NLEmbedding?

    private init() {
        let m = NLEmbedding.sentenceEmbedding(for: .english)
        self.model = m
        self.dim = m?.dimension ?? 0
    }

    /// `true` if on-device sentence embeddings are available for the user's
    /// locale. UI can use this to label search as "Smart Search" vs. "Search".
    var isAvailable: Bool { model != nil }

    /// Compute and pack a sentence embedding for storage on a DocumentFile.
    /// Returns `nil` if no model is available — caller should keep keyword fallback.
    func embedding(for ocrText: String, name: String) -> Data? {
        guard let model else { return nil }

        // Use the first ~500 chars + the suggested filename — enough to capture
        // document essence without exhausting the embedding context.
        let head = String(ocrText.prefix(500)).trimmingCharacters(in: .whitespacesAndNewlines)
        let combined = head.isEmpty ? name : "\(name). \(head)"

        guard let vector = model.vector(for: combined) else { return nil }
        return Self.pack(vector)
    }

    /// Search the model context for documents matching the query, ranked by cosine
    /// similarity to the query embedding. Falls back to keyword scoring on documents
    /// without an embedding (e.g. older imports).
    func search(query: String, in modelContext: ModelContext, limit: Int = 20) -> [SearchHit] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        let queryVector = model?.vector(for: trimmed)

        let descriptor = FetchDescriptor<DocumentFile>(
            predicate: #Predicate<DocumentFile> { $0.isInVault == false },
            sortBy: [SortDescriptor(\.importedAt, order: .reverse)]
        )
        guard let docs = try? modelContext.fetch(descriptor) else { return [] }

        let lowerQuery = trimmed.lowercased()

        let hits: [SearchHit] = docs.compactMap { doc in
            // Embedding-based score, if both sides have embeddings
            var score: Double = 0
            if let queryVector,
               let raw = doc.embedding,
               let docVec = Self.unpack(raw, dim: dim) {
                score = max(0, Self.cosine(queryVector, docVec))
            }

            // Layer in keyword boosts so unembedded docs still surface and exact
            // matches always win over fuzzy matches.
            let nameLower = doc.name.lowercased()
            if nameLower.contains(lowerQuery) { score += 0.6 }
            if doc.aiSuggestedName?.lowercased().contains(lowerQuery) == true { score += 0.4 }
            if doc.aiSummary?.lowercased().contains(lowerQuery) == true { score += 0.2 }
            if doc.ocrTextCache?.lowercased().contains(lowerQuery) == true { score += 0.15 }

            guard score > 0.05 else { return nil }

            let snippet = Self.snippet(from: doc.ocrTextCache ?? "", around: lowerQuery, fallbackName: doc.aiSummary ?? doc.name)
            return SearchHit(document: doc, score: score, snippet: snippet)
        }

        return hits.sorted { $0.score > $1.score }.prefix(limit).map { $0 }
    }

    // MARK: - Pack / unpack

    private static func pack(_ floats: [Double]) -> Data {
        var copy = floats.map { Float($0) }
        return copy.withUnsafeBufferPointer { Data(buffer: $0) }
    }

    private static func unpack(_ data: Data, dim: Int) -> [Double]? {
        let count = data.count / MemoryLayout<Float>.size
        guard count == dim, dim > 0 else { return nil }
        return data.withUnsafeBytes { raw -> [Double] in
            let buffer = raw.bindMemory(to: Float.self)
            return buffer.map { Double($0) }
        }
    }

    private static func cosine(_ a: [Double], _ b: [Double]) -> Double {
        guard a.count == b.count, !a.isEmpty else { return 0 }
        var dot: Double = 0, na: Double = 0, nb: Double = 0
        for i in 0..<a.count {
            dot += a[i] * b[i]
            na  += a[i] * a[i]
            nb  += b[i] * b[i]
        }
        let denom = sqrt(na) * sqrt(nb)
        return denom > 0 ? dot / denom : 0
    }

    // MARK: - Snippet extraction

    private static let snippetWindow = 80

    private static func snippet(from ocr: String, around lowerQuery: String, fallbackName: String) -> String {
        let lowerOcr = ocr.lowercased()
        guard let range = lowerOcr.range(of: lowerQuery) else {
            return String(fallbackName.prefix(160))
        }
        let lower = ocr.index(range.lowerBound, offsetBy: -snippetWindow, limitedBy: ocr.startIndex) ?? ocr.startIndex
        let upper = ocr.index(range.upperBound, offsetBy: snippetWindow, limitedBy: ocr.endIndex) ?? ocr.endIndex
        let prefix = lower > ocr.startIndex ? "…" : ""
        let suffix = upper < ocr.endIndex ? "…" : ""
        return prefix + String(ocr[lower..<upper]).replacingOccurrences(of: "\n", with: " ") + suffix
    }
}

struct SearchHit: Identifiable {
    let document: DocumentFile
    let score: Double
    let snippet: String
    var id: UUID { document.id }
}
