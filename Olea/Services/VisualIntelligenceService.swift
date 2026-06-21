import Foundation
import UIKit
import Vision
#if canImport(FoundationModels)
import FoundationModels
#endif

/// "Ask about this region" — given an image of a PDF page region plus a question
/// intent (explain / translate / define), runs OCR on the region and asks
/// Foundation Models to respond. The OCR text + the user's intent are sent to the
/// on-device model; nothing leaves the device.
@MainActor
final class VisualIntelligenceService {
    static let shared = VisualIntelligenceService()
    private init() {}

    enum Intent: String, CaseIterable, Identifiable {
        case explain, translate, define, summarize

        var id: String { rawValue }

        var label: String {
            switch self {
            case .explain:   return "Explain"
            case .translate: return "Translate"
            case .define:    return "Define"
            case .summarize: return "Summarize"
            }
        }

        var icon: String {
            switch self {
            case .explain:   return "questionmark.bubble"
            case .translate: return "character.bubble"
            case .define:    return "book"
            case .summarize: return "text.badge.star"
            }
        }

        var prompt: String {
            switch self {
            case .explain:
                return "Explain what this passage means in plain language. Cite a key phrase."
            case .translate:
                return "Translate this passage into the user's system language. Preserve formatting."
            case .define:
                return "Define each non-obvious term in this passage."
            case .summarize:
                return "Summarize this passage in 1-2 sentences."
            }
        }
    }

    struct Response {
        var text: String
        var sourceText: String
        var usedFoundationModels: Bool
    }

    /// OCR + AI response for a cropped image of a region.
    func respond(to intent: Intent, in regionImage: UIImage) async -> Response {
        let ocr = await extractText(from: regionImage)
        guard !ocr.isEmpty else {
            return Response(text: "Couldn't read any text in that region. Try selecting a tighter rectangle.", sourceText: "", usedFoundationModels: false)
        }

        #if canImport(FoundationModels)
        if #available(iOS 26, *), case .available = SystemLanguageModel.default.availability {
            if let resp = await ask(intent: intent, sourceText: ocr) {
                return resp
            }
        }
        #endif

        return Response(text: keywordFallback(intent: intent, sourceText: ocr), sourceText: ocr, usedFoundationModels: false)
    }

    // MARK: - OCR

    private func extractText(from image: UIImage) async -> String {
        guard let cgImage = image.cgImage else { return "" }
        return await Task.detached(priority: .userInitiated) {
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
                let observations = request.results as? [VNRecognizedTextObservation] ?? []
                return observations.compactMap { $0.topCandidates(1).first?.string }.joined(separator: "\n")
            } catch {
                return ""
            }
        }.value
    }

    // MARK: - Foundation Models

    #if canImport(FoundationModels)
    @available(iOS 26, *)
    private func ask(intent: Intent, sourceText: String) async -> Response? {
        let session = LanguageModelSession(instructions: """
            You are a helpful tutor responding to a user who long-pressed a region of a document. Be concise, factual, and conversational. Do not invent information.
            """)
        let prompt = """
            User intent: \(intent.prompt)

            Selected text:
            \(sourceText)
            """
        do {
            let response = try await session.respond(to: prompt)
            return Response(text: response.content, sourceText: sourceText, usedFoundationModels: true)
        } catch {
            AppLogger.ai.error("VisualIntelligence FM failed: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }
    #endif

    private func keywordFallback(intent: Intent, sourceText: String) -> String {
        switch intent {
        case .summarize, .explain:
            let firstSentence = sourceText.split(whereSeparator: { ".!?".contains($0) }).first.map(String.init) ?? sourceText
            return "On-device AI isn't available, so here's the leading sentence:\n\n\(firstSentence)"
        case .translate:
            return "On-device translation requires Apple Intelligence (iOS 26+ on a supported device). This text is:\n\n\(sourceText)"
        case .define:
            return "On-device dictionary requires Apple Intelligence. Selected text:\n\n\(sourceText)"
        }
    }
}
