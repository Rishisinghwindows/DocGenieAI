//
//  FormAutofillService.swift
//  DocGenieAI
//
//  Role: Smart Form Autofill. Given a fillable PDF (real AcroForm widgets,
//  not a scanned image), reads every form field, cross-references the user's
//  document library via SemanticSearchService, and asks Foundation Models to
//  suggest a value per field — each with a confidence score and source-doc
//  citation so the user can verify before signing.
//
//  This is the Apple-Intelligence demo feature: it uses multi-doc personal
//  context + structured @Generable output in a way no competitor (Adobe Scan,
//  PDF Expert, GoodNotes) currently does.
//
//  Architecture:
//    1. `extractFields(from:)`     — walks the PDF, emits PDFFormField metadata.
//    2. `SemanticSearchService`    — finds the top-K library docs whose
//                                     content matches the form's field labels.
//    3. Foundation Models call     — @Generable batch prompt returns one
//                                     suggestion per field (or empty value).
//    4. `savedFilledPDF(...)`      — writes accepted values back into the
//                                     AcroForm via PDFAnnotation.setValue.
//
//  Conservatism: the prompt instructs the model to return an empty value
//  rather than guess. Unfilled fields surface in a separate "Couldn't find"
//  section so the user always knows what they still need to handle by hand.
//
//  Limitations (v1): only true AcroForm PDFs are supported. Scanned forms
//  (image-only PDFs) return an empty result and a "this PDF has no fillable
//  fields" message. v2 will use VNRecognizeDocumentRequest (iOS 26) to detect
//  form regions in scanned images.
//

import Foundation
import PDFKit
import SwiftData
#if canImport(FoundationModels)
import FoundationModels
#endif

@MainActor
final class FormAutofillService {
    static let shared = FormAutofillService()
    private init() {}

    // MARK: - Public types

    /// One fillable widget on a PDF page. Detected via `PDFAnnotation.type == "Widget"`.
    /// `label` is the human-readable name from the PDF's `/TU` (tooltip) or
    /// `/T` (technical name) dictionary key; `name` is the technical name we
    /// use to write the value back.
    struct PDFFormField: Identifiable, Hashable {
        let id = UUID()
        let name: String              // The internal AcroForm field name (used for write-back)
        let label: String             // Best-effort human label (TU dict, then T, then name)
        let kind: Kind
        let pageIndex: Int
        let bounds: CGRect            // Field rect on its page, in PDF coords

        enum Kind: String, Sendable { case text, choice, checkbox, signature, button, unknown }
    }

    struct FieldSuggestion: Identifiable, Hashable {
        let id = UUID()
        let field: PDFFormField
        var value: String              // Editable by the user before saving
        let confidence: Double
        let sourceDocumentID: UUID?
        let sourceDocumentName: String?
        let reasoning: String         // 1-line "why we suggested this"
        var isAccepted: Bool = true
    }

    struct AnalysisResult {
        let pdfURL: URL
        let suggestions: [FieldSuggestion]
        let unfilledFields: [PDFFormField]   // Fields the AI couldn't fill
        let usedFoundationModels: Bool
    }

    // MARK: - Analyze

    /// Read fields from the PDF, build context from the library, ask the model.
    func analyze(pdfURL: URL, modelContext: ModelContext) async throws -> AnalysisResult {
        // 1. Enumerate form fields
        let fields = try extractFields(from: pdfURL)
        guard !fields.isEmpty else {
            return AnalysisResult(pdfURL: pdfURL, suggestions: [], unfilledFields: [], usedFoundationModels: false)
        }

        // 2. Build context from the user's library: top-K docs whose semantic
        //    profile matches the field labels we're trying to fill.
        let contextQuery = fields.map(\.label).joined(separator: " ")
        let libraryHits = SemanticSearchService.shared.search(query: contextQuery, in: modelContext, limit: 8)
        let contextDocs = libraryHits.map(\.document)

        // 3. Ask the model.
        #if canImport(FoundationModels)
        if #available(iOS 26, *), case .available = SystemLanguageModel.default.availability {
            if let result = await analyzeWithFM(fields: fields, contextDocs: contextDocs, pdfURL: pdfURL) {
                return result
            }
        }
        #endif

        // Keyword fallback: regex / pattern match common field names against
        // the OCR cache of the top-ranked doc. Useful so the feature isn't
        // dead on iOS <26 or unsupported devices.
        return keywordFallback(fields: fields, contextDocs: contextDocs, pdfURL: pdfURL)
    }

    // MARK: - Save

    /// Write accepted suggestions back into the PDF's AcroForm fields and save
    /// to a new file. Returns the URL of the filled PDF.
    func savedFilledPDF(originalURL: URL, suggestions: [FieldSuggestion], to destination: URL) throws -> URL {
        guard let pdf = PDFDocument(url: originalURL) else {
            throw AutofillError.cannotOpenPDF
        }

        let accepted = suggestions.filter(\.isAccepted)
        for sug in accepted {
            guard let page = pdf.page(at: sug.field.pageIndex) else { continue }
            for annot in page.annotations where annot.widgetFieldType != nil {
                let name = annot.fieldName ?? ""
                guard name == sug.field.name else { continue }
                annot.setValue(sug.value, forAnnotationKey: PDFAnnotationKey.widgetValue)
            }
        }

        guard pdf.write(to: destination) else {
            throw AutofillError.writeFailed
        }
        return destination
    }

    // MARK: - Field extraction

    private func extractFields(from url: URL) throws -> [PDFFormField] {
        guard let pdf = PDFDocument(url: url) else { throw AutofillError.cannotOpenPDF }
        var out: [PDFFormField] = []
        for pageIndex in 0..<pdf.pageCount {
            guard let page = pdf.page(at: pageIndex) else { continue }
            for annot in page.annotations {
                // Only AcroForm widget annotations are fillable. Filter out
                // freetext, highlight, ink, etc.
                guard annot.type == "Widget" else { continue }
                let widgetType = annot.widgetFieldType

                let name = annot.fieldName ?? "unnamed_\(out.count)"
                let label: String
                if let tu = annot.value(forAnnotationKey: PDFAnnotationKey(rawValue: "TU")) as? String, !tu.isEmpty {
                    label = tu
                } else if let t = annot.value(forAnnotationKey: PDFAnnotationKey(rawValue: "T")) as? String, !t.isEmpty {
                    label = t
                } else {
                    label = name
                }
                let kind = Self.kind(for: widgetType, control: annot.widgetControlType)
                out.append(PDFFormField(name: name, label: label, kind: kind, pageIndex: pageIndex, bounds: annot.bounds))
            }
        }
        return out
    }

    private static func kind(
        for widgetType: PDFAnnotationWidgetSubtype,
        control: PDFWidgetControlType
    ) -> PDFFormField.Kind {
        // PDFAnnotationWidgetSubtype is non-frozen across iOS versions, so we
        // route through raw values to keep the switch exhaustive.
        if widgetType == .text { return .text }
        if widgetType == .choice { return .choice }
        if widgetType == .signature { return .signature }
        if widgetType == .button {
            // PDFKit collapses button + checkbox + radio into .button; the
            // widgetControlType distinguishes them.
            switch control {
            case .checkBoxControl: return .checkbox
            case .pushButtonControl: return .button
            case .radioButtonControl: return .checkbox
            case .unknownControl: return .button
            @unknown default: return .button
            }
        }
        return .unknown
    }

    // MARK: - Foundation Models path

    #if canImport(FoundationModels)
    @available(iOS 26, *)
    @Generable
    struct GeneratedSuggestionBatch {
        @Guide(description: "One suggestion per form field. Use exact field name from the prompt. Empty value means 'unknown — do not fill'. Always include a source index that maps to the [N] document tag in the prompt, or 0 if none.")
        var suggestions: [GeneratedSuggestion]
    }

    @available(iOS 26, *)
    @Generable
    struct GeneratedSuggestion {
        @Guide(description: "Exact field name from the PDF (lowercase, no spaces stripped).")
        var fieldName: String

        @Guide(description: "The value to fill the field with. Empty string if you can't determine it from the library context.")
        var value: String

        @Guide(description: "Confidence 0.0 - 1.0. Use 0.9+ only when you saw the exact value in a source document.")
        var confidence: Double

        @Guide(description: "1-based [N] index of the source document you used. 0 if none.")
        var sourceIndex: Int

        @Guide(description: "One short sentence explaining how you derived the value.")
        var reasoning: String
    }

    @available(iOS 26, *)
    private func analyzeWithFM(
        fields: [PDFFormField],
        contextDocs: [DocumentFile],
        pdfURL: URL
    ) async -> AnalysisResult? {
        let session = LanguageModelSession(instructions: """
            You autofill PDF forms by pulling the user's information from their existing documents. For each field, find a matching value in the provided library context. If you can't find a confident match, return an empty value rather than guessing — the user will fix unfilled fields by hand.

            Be conservative: a 0.5 confidence "maybe" is much worse than an empty value the user fills themselves.
            """)

        // Build context block: each doc gets a [N] header so the model can cite back.
        var contextLines: [String] = []
        for (i, doc) in contextDocs.prefix(6).enumerated() {
            let label = doc.aiSuggestedName ?? doc.name
            let body = (doc.ocrTextCache ?? "").prefix(800)
            contextLines.append("[\(i + 1)] \(label)\n\(body)")
        }
        let contextBlock = contextLines.joined(separator: "\n\n---\n\n")

        let fieldsBlock = fields.map { f in
            "- \(f.name)  [\(f.kind.rawValue)]  label: \(f.label)"
        }.joined(separator: "\n")

        let prompt = """
            Fields to fill:
            \(fieldsBlock)

            Library context:
            \(contextBlock)

            Return one suggestion per field using the exact field name above.
            """

        do {
            let response = try await session.respond(to: prompt, generating: GeneratedSuggestionBatch.self)
            let resolved = response.content.suggestions.map { gen in
                resolve(gen: gen, fields: fields, contextDocs: contextDocs)
            }.compactMap { $0 }

            // Anything we got back becomes a suggestion; anything we didn't
            // (model dropped some fields) becomes "unfilled".
            let suggestedFieldNames = Set(resolved.map(\.field.name))
            let unfilled = fields.filter { !suggestedFieldNames.contains($0.name) }
            return AnalysisResult(pdfURL: pdfURL, suggestions: resolved, unfilledFields: unfilled, usedFoundationModels: true)
        } catch {
            AppLogger.ai.error("FormAutofill FM failed: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    @available(iOS 26, *)
    private func resolve(gen: GeneratedSuggestion, fields: [PDFFormField], contextDocs: [DocumentFile]) -> FieldSuggestion? {
        // Match by exact name first; fall back to case-insensitive.
        let field = fields.first(where: { $0.name == gen.fieldName })
            ?? fields.first(where: { $0.name.caseInsensitiveCompare(gen.fieldName) == .orderedSame })
        guard let field else { return nil }

        // Trim and reject obvious noise.
        let trimmed = gen.value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        guard gen.confidence >= 0.3 else { return nil }

        let sourceDoc: DocumentFile? = {
            let zeroIdx = gen.sourceIndex - 1
            return contextDocs.indices.contains(zeroIdx) ? contextDocs[zeroIdx] : nil
        }()

        return FieldSuggestion(
            field: field,
            value: trimmed,
            confidence: min(1.0, max(0, gen.confidence)),
            sourceDocumentID: sourceDoc?.id,
            sourceDocumentName: sourceDoc?.aiSuggestedName ?? sourceDoc?.name,
            reasoning: gen.reasoning
        )
    }
    #endif

    // MARK: - Keyword fallback
    //
    // No on-device LLM available — try simple semantic guesses against the
    // top OCR'd doc. Covers ~30% of common form fields (name, email, phone,
    // address) so the feature isn't completely dead.

    private func keywordFallback(
        fields: [PDFFormField],
        contextDocs: [DocumentFile],
        pdfURL: URL
    ) -> AnalysisResult {
        var suggestions: [FieldSuggestion] = []
        let ocrCorpus = contextDocs.compactMap { $0.ocrTextCache }.joined(separator: "\n")

        for field in fields where field.kind == .text {
            let label = field.label.lowercased() + " " + field.name.lowercased()
            if let guess = guess(for: label, in: ocrCorpus) {
                suggestions.append(FieldSuggestion(
                    field: field,
                    value: guess.value,
                    confidence: guess.confidence,
                    sourceDocumentID: contextDocs.first?.id,
                    sourceDocumentName: contextDocs.first?.aiSuggestedName ?? contextDocs.first?.name,
                    reasoning: guess.reasoning
                ))
            }
        }

        let filled = Set(suggestions.map(\.field.name))
        let unfilled = fields.filter { !filled.contains($0.name) }
        return AnalysisResult(pdfURL: pdfURL, suggestions: suggestions, unfilledFields: unfilled, usedFoundationModels: false)
    }

    private struct Guess { let value: String; let confidence: Double; let reasoning: String }

    private func guess(for label: String, in corpus: String) -> Guess? {
        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.phoneNumber.rawValue
                                            | NSTextCheckingResult.CheckingType.link.rawValue
                                            | NSTextCheckingResult.CheckingType.address.rawValue)
        let range = NSRange(corpus.startIndex..., in: corpus)

        if label.contains("email") {
            if let match = detector?.matches(in: corpus, range: range).first(where: { $0.url?.scheme == "mailto" }),
               let mailto = match.url?.absoluteString.replacingOccurrences(of: "mailto:", with: "") {
                return Guess(value: mailto, confidence: 0.7, reasoning: "Found an email in your library.")
            }
        }
        if label.contains("phone") || label.contains("tel") || label.contains("mobile") {
            if let match = detector?.matches(in: corpus, range: range).first(where: { $0.resultType == .phoneNumber }),
               let phone = match.phoneNumber {
                return Guess(value: phone, confidence: 0.7, reasoning: "Found a phone number in your library.")
            }
        }
        if label.contains("address") || label.contains("street") {
            if let match = detector?.matches(in: corpus, range: range).first(where: { $0.resultType == .address }),
               let bounds = Range(match.range, in: corpus) {
                let value = String(corpus[bounds])
                return Guess(value: value, confidence: 0.6, reasoning: "Found an address in your library.")
            }
        }
        return nil
    }

    // MARK: - Errors

    enum AutofillError: LocalizedError {
        case cannotOpenPDF
        case noFormFields
        case writeFailed

        var errorDescription: String? {
            switch self {
            case .cannotOpenPDF: return "Couldn't open the PDF. Make sure it's a fillable form, not a scanned image."
            case .noFormFields: return "This PDF has no fillable fields. Try a form with text boxes you can tap."
            case .writeFailed: return "Couldn't save the filled PDF."
            }
        }
    }
}
