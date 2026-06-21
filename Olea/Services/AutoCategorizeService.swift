import Foundation

@MainActor
final class AutoCategorizeService {
    static let shared = AutoCategorizeService()
    private init() {}

    struct Categorization {
        var suggestedTag: FileTag?
        var contentType: ScanContentType
        var confidence: Double // 0-1
        var suggestedName: String? // Better filename if detectable
    }

    func categorize(ocrText: String, fileName: String) -> Categorization {
        let contentType = ScanContentType.classify(ocrText: ocrText)
        let lower = ocrText.lowercased()

        var tag: FileTag?
        var confidence: Double = 0.5
        var suggestedName: String?

        // Map content type to tag
        switch contentType {
        case .receipt:
            tag = .receipt
            confidence = 0.8
            // Try to extract vendor name for better filename
            let receipt = ScanContentType.parseReceipt(ocrText: ocrText)
            if !receipt.vendor.isEmpty && receipt.vendor != "Unknown" {
                suggestedName = "Receipt - \(receipt.vendor)"
                if let date = receipt.date { suggestedName! += " \(date)" }
            }
        case .businessCard:
            tag = .personal
            confidence = 0.7
            let card = ScanContentType.parseBusinessCard(ocrText: ocrText)
            if let name = card.name { suggestedName = "Business Card - \(name)" }
        case .letter:
            // Check if it's legal
            let legalKeywords = ["hereby", "whereas", "pursuant", "jurisdiction", "liability",
                                 "indemnify", "arbitration", "amendment", "termination", "governing law"]
            let legalCount = legalKeywords.filter { lower.contains($0) }.count
            if legalCount >= 2 {
                tag = .legal
                confidence = 0.75
            } else {
                tag = .personal
                confidence = 0.5
            }
        case .form:
            // Check for invoice-specific keywords
            let invoiceKeywords = ["invoice", "bill to", "due date", "payment terms", "po number", "purchase order"]
            if invoiceKeywords.filter({ lower.contains($0) }).count >= 2 {
                tag = .invoice
                confidence = 0.8
            } else {
                tag = .work
                confidence = 0.5
            }
        case .textHeavy:
            // Classify based on content keywords
            let workKeywords = ["meeting", "project", "deadline", "quarterly", "revenue",
                                "stakeholder", "deliverable", "milestone", "budget", "report"]
            let legalKeywords = ["contract", "agreement", "party", "clause", "section",
                                 "terms", "conditions", "warranty", "indemnification"]
            let invoiceKeywords = ["invoice", "amount due", "bill", "payment", "subtotal", "total"]

            let workScore = workKeywords.filter { lower.contains($0) }.count
            let legalScore = legalKeywords.filter { lower.contains($0) }.count
            let invoiceScore = invoiceKeywords.filter { lower.contains($0) }.count

            if invoiceScore >= 2 { tag = .invoice; confidence = 0.7 }
            else if legalScore >= 2 { tag = .legal; confidence = 0.7 }
            else if workScore >= 2 { tag = .work; confidence = 0.6 }
            else { tag = .personal; confidence = 0.3 }
        default:
            tag = nil
            confidence = 0.2
        }

        return Categorization(suggestedTag: tag, contentType: contentType, confidence: confidence, suggestedName: suggestedName)
    }
}
