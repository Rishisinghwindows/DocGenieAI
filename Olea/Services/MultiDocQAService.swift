//
//  MultiDocQAService.swift
//  DocGenieAI
//
//  Role: NotebookLM-style multi-document Q&A. Given a question + a set of
//  documents, returns a single grounded answer with structured citations
//  linking back to the source documents (so users can verify before trusting).
//
//  Pipeline:
//    1. `rankSnippets` — for each doc, find the 400-char window whose
//       NLEmbedding cosine similarity to the question is highest. Falls back
//       to query-term frequency if embeddings aren't available.
//    2. `buildContext` — concatenate top-K (default 6) snippets with [N] tags
//       so the model can cite back by index.
//    3. Foundation Models call — `@Generable GeneratedAnswer { text, [citations] }`
//       forces structured output; the model cannot hallucinate a free-form
//       answer outside the schema.
//    4. Resolve citation indices back to DocumentFile metadata for the UI.
//
//  Why structured citations matter: this is the only design that makes
//  multi-doc Q&A trustworthy. Without source-doc attribution, users can't
//  verify the answer and the AI feels like a black box.
//

import Foundation
import SwiftData
import NaturalLanguage
#if canImport(FoundationModels)
import FoundationModels
#endif

@MainActor
final class MultiDocQAService {
    static let shared = MultiDocQAService()
    private init() {}

    // MARK: - Public types

    /// One synthesized answer + the supporting citations. UI renders each
    /// citation as a tappable chip that opens the source document.
    struct Answer {
        var text: String
        var citations: [Citation]
        /// `true` if Foundation Models was used (iOS 26+ + supported device).
        /// `false` indicates the keyword-extraction fallback path.
        var usedFoundationModels: Bool
    }

    /// One verifiable citation back to a source document. The `pageHint` is
    /// best-effort — the model is asked but not required to return it, and we
    /// don't currently use it for navigation. Reserved for future "jump to
    /// page" deep linking.
    struct Citation: Identifiable {
        let id = UUID()
        let documentID: UUID
        let documentName: String
        let snippet: String
        let pageHint: Int?
    }

    // MARK: - Public API

    /// Answer a question grounded in the supplied documents. Streams nothing today —
    /// returns a single Answer when complete. Callers should display a progress UI.
    func answer(question: String, documents: [DocumentFile]) async -> Answer {
        let trimmed = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return Answer(text: "Type a question above.", citations: [], usedFoundationModels: false)
        }
        guard !documents.isEmpty else {
            return Answer(text: "Pick at least one document to ask about.", citations: [], usedFoundationModels: false)
        }

        // Step 1: rank document snippets by relevance to the question.
        let scored = rankSnippets(question: trimmed, documents: documents)

        // Step 2: build a compact context that fits the model window.
        let context = buildContext(snippets: scored)

        #if canImport(FoundationModels)
        if #available(iOS 26, *), case .available = SystemLanguageModel.default.availability {
            if let answer = await answerWithFM(question: trimmed, context: context, documents: documents) {
                return answer
            }
        }
        #endif

        return answerKeyword(question: trimmed, scored: scored)
    }

    // MARK: - Snippet ranking

    /// One snippet per document, picked as the highest-similarity 400-char window
    /// to the question. If embeddings aren't available, returns the first 400 chars.
    private struct ScoredSnippet {
        let document: DocumentFile
        let snippet: String
        let score: Double
    }

    private func rankSnippets(question: String, documents: [DocumentFile]) -> [ScoredSnippet] {
        let model = NLEmbedding.sentenceEmbedding(for: .english)
        let qVec = model?.vector(for: question)

        var scored: [ScoredSnippet] = []
        for doc in documents {
            let ocr = doc.ocrTextCache ?? ""
            guard !ocr.isEmpty else {
                scored.append(ScoredSnippet(document: doc, snippet: doc.aiSummary ?? doc.name, score: 0))
                continue
            }
            let (snippet, score) = bestWindow(text: ocr, query: question, queryVector: qVec, embedder: model)
            scored.append(ScoredSnippet(document: doc, snippet: snippet, score: score))
        }
        return scored.sorted { $0.score > $1.score }
    }

    private func bestWindow(text: String, query: String, queryVector: [Double]?, embedder: NLEmbedding?) -> (String, Double) {
        let windowSize = 400
        let stride = 200
        guard text.count > windowSize else { return (text, 0.5) }

        var bestSnippet = String(text.prefix(windowSize))
        var bestScore = -1.0

        var index = text.startIndex
        while index < text.endIndex {
            let end = text.index(index, offsetBy: windowSize, limitedBy: text.endIndex) ?? text.endIndex
            let window = String(text[index..<end])

            var score = 0.0
            if let qVec = queryVector, let docVec = embedder?.vector(for: window) {
                score = Self.cosine(qVec, docVec)
            } else {
                // keyword fallback: count of query terms present
                let qTerms = query.lowercased().split(separator: " ").map(String.init)
                let lowerWindow = window.lowercased()
                score = Double(qTerms.filter { lowerWindow.contains($0) }.count) / max(1, Double(qTerms.count))
            }

            if score > bestScore {
                bestScore = score
                bestSnippet = window
            }

            guard let next = text.index(index, offsetBy: stride, limitedBy: text.endIndex), next < text.endIndex else { break }
            index = next
        }
        return (bestSnippet, max(0, bestScore))
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

    // MARK: - Context builder

    /// Build the context block sent to Foundation Models. Each document gets a
    /// header with its index (used for citation back-references) and a snippet.
    private func buildContext(snippets: [ScoredSnippet]) -> String {
        // Cap total context to keep within Foundation Models' window. ~6 docs is
        // a safe ceiling at 400 chars each (≈2.4k chars + headers).
        let capped = snippets.prefix(6)
        var lines: [String] = []
        for (i, item) in capped.enumerated() {
            let header = "[\(i + 1)] \(item.document.aiSuggestedName ?? item.document.name)"
            let cleaned = item.snippet.replacingOccurrences(of: "\n", with: " ")
            lines.append("\(header)\n\(cleaned)")
        }
        return lines.joined(separator: "\n\n")
    }

    // MARK: - Foundation Models path

    #if canImport(FoundationModels)
    @available(iOS 26, *)
    @Generable
    struct GeneratedAnswer {
        @Guide(description: "A 2-4 sentence factual answer to the user's question. Reference only the supplied documents.")
        var text: String

        @Guide(description: "List of source citations. Each citation index must match a [N] block from the context. Snippet should quote the exact relevant phrase from that document.")
        var citations: [GeneratedCitation]
    }

    @available(iOS 26, *)
    @Generable
    struct GeneratedCitation {
        @Guide(description: "1-based index of the source document, matching the [N] header in the context block.")
        var sourceIndex: Int

        @Guide(description: "The exact phrase from the source that supports the answer. Max 200 chars.")
        var snippet: String
    }

    @available(iOS 26, *)
    private func answerWithFM(question: String, context: String, documents: [DocumentFile]) async -> Answer? {
        let session = LanguageModelSession(instructions: """
            You answer questions strictly from the supplied documents. If the answer isn't in the documents, say so. Always cite the specific [N] source you used.
            """)

        let prompt = """
            Question: \(question)

            Documents:
            \(context)
            """

        do {
            let response = try await session.respond(to: prompt, generating: GeneratedAnswer.self)
            let g = response.content

            // Resolve citation indices back to DocumentFile metadata.
            let resolved: [Citation] = g.citations.compactMap { gc in
                let zeroIdx = gc.sourceIndex - 1
                guard documents.indices.contains(zeroIdx) else { return nil }
                let doc = documents[zeroIdx]
                return Citation(
                    documentID: doc.id,
                    documentName: doc.aiSuggestedName ?? doc.name,
                    snippet: gc.snippet,
                    pageHint: nil
                )
            }
            return Answer(text: g.text, citations: resolved, usedFoundationModels: true)
        } catch {
            AppLogger.ai.error("MultiDocQA FM failed: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }
    #endif

    // MARK: - Keyword fallback

    private func answerKeyword(question: String, scored: [ScoredSnippet]) -> Answer {
        let top = scored.prefix(3)
        guard !top.isEmpty else {
            return Answer(text: "On-device AI isn't available on this device, and no documents matched your question.", citations: [], usedFoundationModels: false)
        }
        let preview = top.first?.snippet ?? ""
        let text = """
            On-device AI isn't available on this device, so I can't synthesize an answer. Here's the closest passage I found:

            "\(preview.prefix(280))"
            """
        let citations: [Citation] = top.map { item in
            Citation(documentID: item.document.id,
                     documentName: item.document.aiSuggestedName ?? item.document.name,
                     snippet: String(item.snippet.prefix(200)),
                     pageHint: nil)
        }
        return Answer(text: text, citations: citations, usedFoundationModels: false)
    }
}
