import SwiftUI
import SwiftData

@MainActor
@Observable
final class AIDocumentViewModel {
    var isProcessing = false
    var didComplete = false
    var errorMessage: String?
    var showError = false
    var resultText: String?
    var resultFileName: String?

    var extractedDocumentText: String?
    var chatMessages: [(role: String, content: String)] = []

    private let ocrService = OCRService.shared
    private let converterService = ConverterService.shared

    // MARK: - Summarize

    func summarizePDF(url: URL) {
        isProcessing = true
        Task { @MainActor in
            defer { isProcessing = false }
            do {
                let text = try await ocrService.extractText(from: url)

                if AIService.shared.isOnDeviceAIAvailable {
                    let prompt = "Summarize the following document in 3-5 key bullet points. Be concise and clear:\n\n\(String(text.prefix(4000)))"
                    let response = try await AIService.shared.generateResponse(for: prompt, conversationHistory: [])
                    resultText = response.text
                } else {
                    resultText = generateBasicSummary(text: text)
                }
                didComplete = true
                UsageManager.shared.trackToolUse()
                HapticManager.success()
            } catch {
                errorMessage = error.localizedDescription
                showError = true
                HapticManager.error()
            }
        }
    }

    // MARK: - Ask PDF

    func loadDocument(url: URL) {
        isProcessing = true
        Task { @MainActor in
            defer { isProcessing = false }
            do {
                extractedDocumentText = try await ocrService.extractText(from: url)
                chatMessages.append((role: "assistant", content: "Document loaded. Ask me anything about it."))
            } catch {
                errorMessage = error.localizedDescription
                showError = true
                HapticManager.error()
            }
        }
    }

    func askQuestion(_ question: String) {
        guard let docText = extractedDocumentText else { return }
        chatMessages.append((role: "user", content: question))
        isProcessing = true

        Task { @MainActor in
            defer { isProcessing = false }
            do {
                if AIService.shared.isOnDeviceAIAvailable {
                    // Build conversation history so multi-turn Q&A retains context
                    let history = chatMessages.dropLast().map { msg in
                        ChatMessage.makeTransient(content: msg.content, role: msg.role)
                    }
                    let prompt = """
                    Based on this document content, answer the question concisely.

                    Document (excerpt):
                    \(String(docText.prefix(3000)))

                    Question: \(question)
                    """
                    let response = try await AIService.shared.generateResponse(for: prompt, conversationHistory: history)
                    chatMessages.append((role: "assistant", content: response.text))
                } else {
                    let results = searchKeywords(question: question, in: docText)
                    chatMessages.append((role: "assistant", content: results))
                }
            } catch {
                chatMessages.append((role: "assistant", content: "Sorry, I couldn't process your question. \(error.localizedDescription)"))
            }
        }
    }

    // MARK: - Translate

    func translatePDF(url: URL, targetLanguage: String) {
        isProcessing = true
        Task { @MainActor in
            defer { isProcessing = false }
            do {
                let text = try await ocrService.extractText(from: url)

                guard AIService.shared.isOnDeviceAIAvailable else {
                    errorMessage = "Translation requires on-device AI (iOS 26+)."
                    showError = true
                    return
                }

                var translated = ""
                let chunks = text.chunked(maxLength: 2000)
                for chunk in chunks {
                    let prompt = "Translate the following text to \(targetLanguage). Only output the translation, nothing else:\n\n\(chunk)"
                    let response = try await AIService.shared.generateResponse(for: prompt, conversationHistory: [])
                    translated += response.text + "\n\n"
                }

                resultText = translated.trimmingCharacters(in: .whitespacesAndNewlines)
                didComplete = true
                UsageManager.shared.trackToolUse()
                HapticManager.success()
            } catch {
                errorMessage = error.localizedDescription
                showError = true
                HapticManager.error()
            }
        }
    }

    // MARK: - Save

    func saveResultAsText(outputName: String, context: ModelContext) {
        guard let text = resultText else { return }
        isProcessing = true
        defer { isProcessing = false }
        do {
            let result = try converterService.saveTextFile(text: text, outputName: outputName)
            let metadata = FileMetadataService.shared.extractMetadata(from: result.url)
            let docFile = DocumentFile(
                name: (result.url.lastPathComponent as NSString).deletingPathExtension,
                fileExtension: "txt",
                relativeFilePath: result.relativePath,
                fileSize: metadata.fileSize
            )
            context.insert(docFile)
            try context.save()
            resultFileName = docFile.fullFileName
            HapticManager.success()
        } catch {
            errorMessage = error.localizedDescription
            showError = true
            HapticManager.error()
        }
    }

    func reset() {
        isProcessing = false
        didComplete = false
        errorMessage = nil
        showError = false
        resultText = nil
        resultFileName = nil
        chatMessages = []
        extractedDocumentText = nil
    }

    // MARK: - Helpers

    private func generateBasicSummary(text: String) -> String {
        let words = text.split(separator: " ")
        let lines = text.components(separatedBy: .newlines).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        let firstParagraph = String(text.prefix(500))
        return """
        Document Statistics:
        \u{2022} Word count: \(words.count)
        \u{2022} Line count: \(lines.count)
        \u{2022} Character count: \(text.count)

        Preview:
        \(firstParagraph)\(text.count > 500 ? "..." : "")
        """
    }

    private func searchKeywords(question: String, in text: String) -> String {
        let keywords = question.lowercased().split(separator: " ").filter { $0.count > 3 }
        let sentences = text.components(separatedBy: ". ")
        let matches = sentences.filter { sentence in
            keywords.contains { sentence.lowercased().contains($0) }
        }.prefix(5)

        if matches.isEmpty {
            return "No relevant sections found. Try different keywords."
        }
        return "Relevant excerpts:\n\n" + matches.joined(separator: "\n\n")
    }
}

private extension String {
    /// Splits text into chunks at sentence boundaries (`. `, `! `, `? `, or newlines)
    /// to avoid cutting mid-word or mid-sentence during translation.
    func chunked(maxLength: Int) -> [String] {
        guard count > maxLength else { return [self] }
        var chunks: [String] = []
        var current = startIndex
        while current < endIndex {
            let remaining = distance(from: current, to: endIndex)
            if remaining <= maxLength {
                chunks.append(String(self[current...]))
                break
            }
            let candidateEnd = index(current, offsetBy: maxLength, limitedBy: endIndex) ?? endIndex
            // Search backwards for a sentence boundary
            var splitAt = candidateEnd
            let searchRange = current..<candidateEnd
            let sentenceEnders: [String] = [". ", "! ", "? ", "\n"]
            for ender in sentenceEnders {
                if let range = self[searchRange].range(of: ender, options: .backwards) {
                    let candidate = range.upperBound
                    if candidate > splitAt || splitAt == candidateEnd {
                        splitAt = candidate
                    }
                }
            }
            // Pick the best split point (latest sentence boundary found)
            let bestSplit: String.Index
            if splitAt != candidateEnd {
                bestSplit = splitAt
            } else {
                // No sentence boundary found — split at last space
                if let spaceRange = self[searchRange].range(of: " ", options: .backwards) {
                    bestSplit = spaceRange.upperBound
                } else {
                    bestSplit = candidateEnd
                }
            }
            chunks.append(String(self[current..<bestSplit]))
            current = bestSplit
        }
        return chunks
    }
}
