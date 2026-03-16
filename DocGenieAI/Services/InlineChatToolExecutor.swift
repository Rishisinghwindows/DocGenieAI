import Foundation
import SwiftData
import UIKit

@MainActor
final class InlineChatToolExecutor {
    static let shared = InlineChatToolExecutor()

    private let ocrService = OCRService.shared
    private let pdfToolsService = PDFToolsService.shared
    private let metadataService = FileMetadataService.shared

    private init() {}

    func execute(toolType: String, documentFile: DocumentFile, context: ModelContext) async -> InlineToolResult {
        do {
            switch toolType {
            case "ocr":
                return try await executeOCR(documentFile: documentFile)
            case "summarize":
                return try await executeSummarize(documentFile: documentFile)
            case "compress":
                return try await executeCompress(documentFile: documentFile, context: context)
            case "watermark":
                return try await executeWatermark(documentFile: documentFile, context: context)
            case "rewrite_formal":
                return try await executeTextTransform(documentFile: documentFile, style: .formal)
            case "rewrite_casual":
                return try await executeTextTransform(documentFile: documentFile, style: .casual)
            case "fix_grammar":
                return try await executeTextTransform(documentFile: documentFile, style: .fixGrammar)
            case "bullet_points":
                return try await executeTextTransform(documentFile: documentFile, style: .bullets)
            case "expand":
                return try await executeTextTransform(documentFile: documentFile, style: .expand)
            case "page_numbers":
                return try await executePageNumbers(documentFile: documentFile, context: context)
            case "rotate":
                return try await executeRotate(documentFile: documentFile, context: context)
            case "pdf_to_text":
                return try await executePDFToText(documentFile: documentFile)
            case "pdf_to_image":
                return try await executePDFToImage(documentFile: documentFile, context: context)
            case "doc_to_pdf":
                return try await executeDocToPDF(documentFile: documentFile, context: context)
            default:
                return InlineToolResult(
                    toolType: toolType,
                    success: false,
                    title: "Unknown Tool",
                    content: "Tool type '\(toolType)' is not supported."
                )
            }
        } catch {
            return InlineToolResult(
                toolType: toolType,
                success: false,
                title: "Error",
                content: error.localizedDescription
            )
        }
    }

    private func executeOCR(documentFile: DocumentFile) async throws -> InlineToolResult {
        guard let url = documentFile.fileURL else {
            return InlineToolResult(toolType: "ocr", success: false, title: "File Not Found", content: "The document file could not be located.")
        }
        let text = try await ocrService.extractText(from: url)

        if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return InlineToolResult(
                toolType: "ocr",
                success: true,
                title: "No Text Found",
                content: "No readable text was detected in this document."
            )
        }

        return InlineToolResult(
            toolType: "ocr",
            success: true,
            title: "Text Extracted",
            content: text.trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }

    private func executeSummarize(documentFile: DocumentFile) async throws -> InlineToolResult {
        guard let url = documentFile.fileURL else {
            return InlineToolResult(toolType: "summarize", success: false, title: "File Not Found", content: "The document file could not be located.")
        }
        let text = try await ocrService.extractText(from: url)

        if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return InlineToolResult(
                toolType: "summarize",
                success: false,
                title: "Cannot Summarize",
                content: "Could not extract text from the document to generate a summary."
            )
        }

        let summary = generateSimpleSummary(text)
        return InlineToolResult(
            toolType: "summarize",
            success: true,
            title: "Summary Generated",
            content: summary
        )
    }

    private func executeCompress(documentFile: DocumentFile, context: ModelContext) async throws -> InlineToolResult {
        guard let url = documentFile.fileURL else {
            return InlineToolResult(toolType: "compress", success: false, title: "File Not Found", content: "The document file could not be located.")
        }
        let outputName = "\(documentFile.name)_compressed"
        let result = try await pdfToolsService.compressPDF(from: url, level: .medium, outputName: outputName)

        let metadata = metadataService.extractMetadata(from: result.url)
        let newDoc = DocumentFile(
            name: outputName,
            fileExtension: "pdf",
            relativeFilePath: result.relativePath,
            fileSize: metadata.fileSize,
            pageCount: documentFile.pageCount
        )
        context.insert(newDoc)
        try? context.save()

        let originalSize = documentFile.fileSize
        let newSize = metadata.fileSize
        let reduction = originalSize > 0 ? ((originalSize - newSize) * 100 / originalSize) : 0

        return InlineToolResult(
            toolType: "compress",
            success: true,
            title: "PDF Compressed",
            content: "Reduced by \(reduction)% (\(formatFileSize(originalSize)) → \(formatFileSize(newSize)))",
            outputFileId: newDoc.id.uuidString,
            outputFileName: newDoc.fullFileName,
            originalSize: originalSize,
            compressedSize: newSize
        )
    }

    private func executeWatermark(documentFile: DocumentFile, context: ModelContext) async throws -> InlineToolResult {
        guard let url = documentFile.fileURL else {
            return InlineToolResult(toolType: "watermark", success: false, title: "File Not Found", content: "The document file could not be located.")
        }
        let outputName = "\(documentFile.name)_watermarked"
        let result = try await pdfToolsService.addWatermark(from: url, text: "DocSage", outputName: outputName)

        let metadata = metadataService.extractMetadata(from: result.url)
        let newDoc = DocumentFile(
            name: outputName,
            fileExtension: "pdf",
            relativeFilePath: result.relativePath,
            fileSize: metadata.fileSize,
            pageCount: documentFile.pageCount
        )
        context.insert(newDoc)
        try? context.save()

        return InlineToolResult(
            toolType: "watermark",
            success: true,
            title: "Watermark Added",
            content: "Watermark \"DocSage\" applied to all pages.",
            outputFileId: newDoc.id.uuidString,
            outputFileName: newDoc.fullFileName
        )
    }

    private func generateSimpleSummary(_ text: String) -> String {
        let sentences = text.components(separatedBy: CharacterSet(charactersIn: ".!?"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.count > 20 }

        if sentences.isEmpty {
            return String(text.prefix(500))
        }

        let wordCount = text.split(separator: " ").count
        var lines = ["Document contains approximately \(wordCount) words.", ""]
        lines.append("Key points:")
        for (index, sentence) in sentences.prefix(5).enumerated() {
            lines.append("\(index + 1). \(String(sentence.prefix(150)))")
        }
        return lines.joined(separator: "\n")
    }

    private func executePageNumbers(documentFile: DocumentFile, context: ModelContext) async throws -> InlineToolResult {
        guard let url = documentFile.fileURL else {
            return InlineToolResult(toolType: "page_numbers", success: false, title: "File Not Found", content: "Cannot locate file.")
        }
        let outputName = "\(documentFile.name)_numbered"
        let result = try await pdfToolsService.addPageNumbers(from: url, outputName: outputName)
        let metadata = metadataService.extractMetadata(from: result.url)
        let newDoc = DocumentFile(name: outputName, fileExtension: "pdf", relativeFilePath: result.relativePath, fileSize: metadata.fileSize, pageCount: documentFile.pageCount)
        context.insert(newDoc)
        try? context.save()
        return InlineToolResult(toolType: "page_numbers", success: true, title: "Page Numbers Added", content: "Added page numbers to all pages.", outputFileId: newDoc.id.uuidString, outputFileName: newDoc.fullFileName)
    }

    private func executeRotate(documentFile: DocumentFile, context: ModelContext) async throws -> InlineToolResult {
        guard let url = documentFile.fileURL else {
            return InlineToolResult(toolType: "rotate", success: false, title: "File Not Found", content: "Cannot locate file.")
        }
        let outputName = "\(documentFile.name)_rotated"
        let result = try await pdfToolsService.rotatePDF(from: url, degrees: 90, outputName: outputName)
        let metadata = metadataService.extractMetadata(from: result.url)
        let newDoc = DocumentFile(name: outputName, fileExtension: "pdf", relativeFilePath: result.relativePath, fileSize: metadata.fileSize, pageCount: documentFile.pageCount)
        context.insert(newDoc)
        try? context.save()
        return InlineToolResult(toolType: "rotate", success: true, title: "PDF Rotated", content: "Rotated all pages 90°.", outputFileId: newDoc.id.uuidString, outputFileName: newDoc.fullFileName)
    }

    private func executePDFToText(documentFile: DocumentFile) async throws -> InlineToolResult {
        guard let url = documentFile.fileURL else {
            return InlineToolResult(toolType: "pdf_to_text", success: false, title: "File Not Found", content: "Cannot locate file.")
        }
        let text = try ConverterService.shared.pdfToText(url: url)
        return InlineToolResult(toolType: "pdf_to_text", success: true, title: "Text Extracted", content: text)
    }

    private func executePDFToImage(documentFile: DocumentFile, context: ModelContext) async throws -> InlineToolResult {
        guard let url = documentFile.fileURL else {
            return InlineToolResult(toolType: "pdf_to_image", success: false, title: "File Not Found", content: "Cannot locate file.")
        }
        let results = try ConverterService.shared.pdfToImages(url: url, format: .jpg, outputDir: documentFile.name)
        var newDocs: [DocumentFile] = []
        for imgResult in results {
            let metadata = metadataService.extractMetadata(from: imgResult.url)
            let name = (imgResult.url.lastPathComponent as NSString).deletingPathExtension
            let ext = imgResult.url.pathExtension
            let newDoc = DocumentFile(name: name, fileExtension: ext, relativeFilePath: imgResult.relativePath, fileSize: metadata.fileSize)
            context.insert(newDoc)
            newDocs.append(newDoc)
        }
        try? context.save()
        return InlineToolResult(toolType: "pdf_to_image", success: true, title: "PDF Exported", content: "Exported \(results.count) pages as JPG images.", outputFileId: newDocs.first?.id.uuidString, outputFileName: newDocs.first?.fullFileName)
    }

    private func executeDocToPDF(documentFile: DocumentFile, context: ModelContext) async throws -> InlineToolResult {
        guard let url = documentFile.fileURL else {
            return InlineToolResult(toolType: "doc_to_pdf", success: false, title: "File Not Found", content: "Cannot locate file.")
        }
        let outputName = documentFile.name
        let result = try ConverterService.shared.documentToPDF(url: url, outputName: outputName)
        let metadata = metadataService.extractMetadata(from: result.url)
        let newDoc = DocumentFile(name: outputName, fileExtension: "pdf", relativeFilePath: result.relativePath, fileSize: metadata.fileSize, pageCount: metadata.pageCount)
        context.insert(newDoc)
        try? context.save()
        return InlineToolResult(toolType: "doc_to_pdf", success: true, title: "Converted to PDF", content: "Converted \(documentFile.fullFileName) to PDF.", outputFileId: newDoc.id.uuidString, outputFileName: newDoc.fullFileName)
    }

    private func formatFileSize(_ bytes: Int64) -> String {
        if bytes < 1024 { return "\(bytes) B" }
        if bytes < 1024 * 1024 { return "\(bytes / 1024) KB" }
        return String(format: "%.1f MB", Double(bytes) / (1024.0 * 1024.0))
    }

    // MARK: - Smart Text Actions

    enum TextTransformStyle {
        case formal, casual, fixGrammar, bullets, expand
    }

    private func executeTextTransform(documentFile: DocumentFile, style: TextTransformStyle) async throws -> InlineToolResult {
        guard let url = documentFile.fileURL else {
            return InlineToolResult(toolType: "text_transform", success: false, title: "File Not Found", content: "Cannot locate the file.")
        }
        let rawText = try await ocrService.extractText(from: url)
        guard !rawText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return InlineToolResult(toolType: "text_transform", success: false, title: "No Text", content: "No readable text found.")
        }

        let text = String(rawText.prefix(3000)) // Cap input
        let result: String

        switch style {
        case .formal:
            result = transformToFormal(text)
        case .casual:
            result = transformToCasual(text)
        case .fixGrammar:
            result = fixGrammar(text)
        case .bullets:
            result = toBulletPoints(text)
        case .expand:
            result = expandText(text)
        }

        return InlineToolResult(toolType: "text_transform", success: true, title: "Text Transformed", content: result)
    }

    private func transformToFormal(_ text: String) -> String {
        var result = text
        let replacements: [(String, String)] = [
            ("can't", "cannot"), ("won't", "will not"), ("don't", "do not"),
            ("isn't", "is not"), ("aren't", "are not"), ("wasn't", "was not"),
            ("it's", "it is"), ("i'm", "I am"), ("we're", "we are"),
            ("they're", "they are"), ("you're", "you are"),
            ("gonna", "going to"), ("wanna", "want to"), ("gotta", "got to"),
            ("yeah", "yes"), ("nope", "no"), ("ok", "acceptable"),
            ("hi ", "Dear Sir/Madam, "), ("hey ", "Dear Sir/Madam, "),
        ]
        for (old, new) in replacements {
            result = result.replacingOccurrences(of: old, with: new, options: .caseInsensitive)
        }
        // Capitalize first letter of each sentence
        let sentences = result.components(separatedBy: ". ")
        result = sentences.map { s in
            guard let first = s.first else { return s }
            return first.uppercased() + s.dropFirst()
        }.joined(separator: ". ")
        return result
    }

    private func transformToCasual(_ text: String) -> String {
        var result = text
        let replacements: [(String, String)] = [
            ("cannot", "can't"), ("will not", "won't"), ("do not", "don't"),
            ("is not", "isn't"), ("are not", "aren't"),
            ("Dear Sir/Madam,", "Hey,"), ("Dear ", "Hi "),
            ("Furthermore,", "Also,"), ("However,", "But,"),
            ("In conclusion,", "So basically,"), ("Therefore,", "So,"),
        ]
        for (old, new) in replacements {
            result = result.replacingOccurrences(of: old, with: new, options: .caseInsensitive)
        }
        return result
    }

    private func fixGrammar(_ text: String) -> String {
        var result = text
        // Fix double spaces
        while result.contains("  ") {
            result = result.replacingOccurrences(of: "  ", with: " ")
        }
        // Fix spacing after punctuation
        for punct in [".", ",", "!", "?", ";", ":"] {
            result = result.replacingOccurrences(of: "\(punct) ", with: "\(punct) ")
            // Ensure space after punctuation
            let pattern = "\\\(punct)([A-Za-z])"
            if let regex = try? NSRegularExpression(pattern: pattern) {
                result = regex.stringByReplacingMatches(in: result, range: NSRange(result.startIndex..., in: result), withTemplate: "\(punct) $1")
            }
        }
        // Capitalize first letter of sentences
        let sentences = result.components(separatedBy: ". ")
        result = sentences.map { s in
            let trimmed = s.trimmingCharacters(in: .whitespaces)
            guard let first = trimmed.first else { return s }
            return first.uppercased() + trimmed.dropFirst()
        }.joined(separator: ". ")
        // Fix "i" → "I"
        result = result.replacingOccurrences(of: " i ", with: " I ")
        result = result.replacingOccurrences(of: " i'", with: " I'")
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func toBulletPoints(_ text: String) -> String {
        let sentences = text.components(separatedBy: CharacterSet(charactersIn: ".!?"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.count > 10 }
        if sentences.isEmpty { return text }
        return sentences.map { "• \($0)" }.joined(separator: "\n")
    }

    private func expandText(_ text: String) -> String {
        let sentences = text.components(separatedBy: ". ")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        if sentences.isEmpty { return text }
        var expanded: [String] = []
        for sentence in sentences {
            expanded.append(sentence + ".")
            // Add a connecting phrase between sentences
            let connectors = ["Additionally, ", "Furthermore, ", "Moreover, ", "In this regard, ", "It is worth noting that "]
            if expanded.count < sentences.count {
                expanded.append(connectors[expanded.count % connectors.count])
            }
        }
        return expanded.joined(separator: " ")
    }
}
