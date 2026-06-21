import Foundation

struct ReceiptData {
    var vendor: String = ""
    var date: String?
    var items: [String] = []
    var subtotal: String?
    var tax: String?
    var total: String?

    var formattedSummary: String {
        var lines = ["**Receipt from \(vendor)**"]
        if let date { lines.append("Date: \(date)") }
        if !items.isEmpty {
            lines.append("\nItems:")
            for item in items.prefix(8) { lines.append("  • \(item)") }
        }
        if let subtotal { lines.append("\nSubtotal: \(subtotal)") }
        if let tax { lines.append("Tax: \(tax)") }
        if let total { lines.append("**Total: \(total)**") }
        return lines.joined(separator: "\n")
    }
}

struct BusinessCardData {
    var name: String?
    var company: String?
    var email: String?
    var phone: String?
    var website: String?

    var formattedSummary: String {
        var lines: [String] = []
        if let name { lines.append("**\(name)**") }
        if let company { lines.append(company) }
        if let email { lines.append("Email: \(email)") }
        if let phone { lines.append("Phone: \(phone)") }
        if let website { lines.append("Web: \(website)") }
        return lines.joined(separator: "\n")
    }
}

enum ScanContentType: String {
    case receipt
    case businessCard
    case letter
    case form
    case textHeavy
    case imageHeavy
    case unknown

    static func classify(ocrText: String) -> ScanContentType {
        let lower = ocrText.lowercased()
        let wordCount = ocrText.split(separator: " ").count

        // Business card: short text with contact patterns
        let cardKeywords = ["@", "tel:", "tel ", "phone:", "mobile:", "fax:",
                            "www.", ".com", ".org", ".net", "linkedin"]
        let emailPattern = #"[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}"#
        let hasEmail = ocrText.range(of: emailPattern, options: .regularExpression) != nil
        let phonePattern = #"[\+]?[\d\s\-\(\)]{7,15}"#
        let hasPhone = ocrText.range(of: phonePattern, options: .regularExpression) != nil
        // Business cards: short text, no form keywords, has contact info
        let formIndicators = ["name:", "date:", "address:", "please fill", "form", "signature"]
        let hasFormFields = formIndicators.filter({ lower.contains($0) }).count >= 2
        if wordCount < 40 && !hasFormFields && (hasEmail || hasPhone) && cardKeywords.filter({ lower.contains($0) }).count >= 1 {
            return .businessCard
        }

        let receiptKeywords = ["total", "subtotal", "tax", "receipt", "invoice",
                               "payment", "amount due", "balance", "$", "price"]
        if receiptKeywords.filter({ lower.contains($0) }).count >= 3 { return .receipt }

        let formKeywords = ["name:", "date:", "address:", "signature", "phone:",
                            "email:", "[ ]", "[x]", "please fill", "form"]
        if formKeywords.filter({ lower.contains($0) }).count >= 3 { return .form }

        let letterKeywords = ["dear ", "sincerely", "regards", "to whom",
                              "re:", "subject:"]
        if letterKeywords.filter({ lower.contains($0) }).count >= 2 { return .letter }

        if wordCount > 50 { return .textHeavy }
        if wordCount < 10 { return .imageHeavy }

        return .unknown
    }

    // MARK: - Receipt Parser

    static func parseReceipt(ocrText: String) -> ReceiptData {
        var receipt = ReceiptData()
        let lines = ocrText.components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespaces) }

        // Vendor name — usually first non-empty line
        receipt.vendor = lines.first { !$0.isEmpty && $0.count > 2 } ?? "Unknown"

        // Date
        let datePattern = #"\d{1,2}[/\-\.]\d{1,2}[/\-\.]\d{2,4}"#
        if let range = ocrText.range(of: datePattern, options: .regularExpression) {
            receipt.date = String(ocrText[range])
        }

        // Amounts — find lines with currency
        let amountPattern = #"\$[\d,]+\.?\d{0,2}"#
        let amounts = (try? ocrText.matches(of: Regex(amountPattern)).map { String(ocrText[$0.range]) }) ?? []
        if let last = amounts.last { receipt.total = last }
        if amounts.count >= 2 { receipt.subtotal = amounts[amounts.count - 2] }

        // Tax
        if let taxLine = lines.first(where: { $0.lowercased().contains("tax") }) {
            if let range = taxLine.range(of: amountPattern, options: .regularExpression) {
                receipt.tax = String(taxLine[range])
            }
        }

        // Items — lines between header and total that look like items
        for line in lines {
            let l = line.lowercased()
            if !l.isEmpty && l.count > 3
                && !l.contains("total") && !l.contains("subtotal") && !l.contains("tax")
                && !l.contains("change") && !l.contains("payment")
                && line.range(of: amountPattern, options: .regularExpression) != nil {
                receipt.items.append(line)
            }
        }

        return receipt
    }

    // MARK: - Business Card Parser

    static func parseBusinessCard(ocrText: String) -> BusinessCardData {
        var card = BusinessCardData()
        let lines = ocrText.components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }

        // Email
        let emailPattern = #"[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}"#
        if let range = ocrText.range(of: emailPattern, options: .regularExpression) {
            card.email = String(ocrText[range])
        }

        // Phone
        let phonePattern = #"[\+]?[\d\s\-\(\)]{7,15}"#
        let phones = (try? ocrText.matches(of: Regex(phonePattern)).map { String(ocrText[$0.range]).trimmingCharacters(in: .whitespaces) }.filter { $0.count >= 7 }) ?? []
        card.phone = phones.first

        // Name — usually the first or largest text line (heuristic: first line that isn't a company)
        if let firstLine = lines.first, !firstLine.contains("@") && !firstLine.contains("www") {
            card.name = firstLine
        }

        // Company — second line or line with Inc/LLC/Ltd
        for line in lines.dropFirst() {
            let l = line.lowercased()
            if l.contains("inc") || l.contains("llc") || l.contains("ltd") || l.contains("corp") || l.contains("co.") {
                card.company = line
                break
            }
        }
        if card.company == nil && lines.count >= 2 {
            let second = lines[1]
            if !second.contains("@") && second.range(of: phonePattern, options: .regularExpression) == nil {
                card.company = second
            }
        }

        // Website
        let urlPattern = #"(?:www\.)?[a-zA-Z0-9-]+\.[a-zA-Z]{2,}(?:/\S*)?"#
        if let range = ocrText.range(of: urlPattern, options: .regularExpression) {
            card.website = String(ocrText[range])
        }

        return card
    }

    var displayLabel: String {
        switch self {
        case .receipt: return "Receipt / Invoice"
        case .businessCard: return "Business Card"
        case .letter: return "Letter / Correspondence"
        case .form: return "Form / Application"
        case .textHeavy: return "Text Document"
        case .imageHeavy: return "Image / Photo"
        case .unknown: return "Document"
        }
    }

    var displayIcon: String {
        switch self {
        case .receipt: return "creditcard"
        case .businessCard: return "person.crop.rectangle"
        case .letter: return "envelope"
        case .form: return "doc.text"
        case .textHeavy: return "doc.plaintext"
        case .imageHeavy: return "photo"
        case .unknown: return "doc"
        }
    }

    /// Generate a brief auto-summary from OCR text based on content type
    func generateAutoSummary(ocrText: String) -> String {
        let wordCount = ocrText.split(separator: " ").count
        let sentences = ocrText.components(separatedBy: CharacterSet(charactersIn: ".!?\n"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.count > 10 }

        switch self {
        case .businessCard:
            let card = ScanContentType.parseBusinessCard(ocrText: ocrText)
            return card.formattedSummary

        case .receipt:
            var summary = "This looks like a **\(displayLabel)**."
            // Try to find total amount
            if let amountRange = ocrText.range(of: #"\$[\d,]+\.?\d*"#, options: .regularExpression) {
                let amount = String(ocrText[amountRange])
                summary += " Amount found: **\(amount)**."
            }
            summary += " \(wordCount) words detected."
            if let firstLine = sentences.first {
                summary += "\n\n> \(String(firstLine.prefix(120)))..."
            }
            return summary

        case .letter:
            var summary = "This looks like a **\(displayLabel)** with ~\(wordCount) words."
            if let firstLine = sentences.first {
                summary += "\n\n> \(String(firstLine.prefix(150)))"
            }
            return summary

        case .form:
            var summary = "This looks like a **\(displayLabel)**."
            let fieldCount = ocrText.components(separatedBy: ":").count - 1
            if fieldCount > 1 {
                summary += " Found approximately \(fieldCount) fields."
            }
            summary += " \(wordCount) words detected."
            return summary

        case .textHeavy:
            var summary = "**\(displayLabel)** — ~\(wordCount) words detected."
            if sentences.count >= 2 {
                summary += "\n\nKey content:"
                for sentence in sentences.prefix(3) {
                    summary += "\n- \(String(sentence.prefix(120)))"
                }
            }
            return summary

        case .imageHeavy:
            return "This appears to be mostly an **image** with minimal text (\(wordCount) words)."

        case .unknown:
            var summary = "Scanned **document** — \(wordCount) words detected."
            if let firstLine = sentences.first {
                summary += "\n\n> \(String(firstLine.prefix(150)))"
            }
            return summary
        }
    }

    var suggestedActions: [(toolType: String, label: String, icon: String)] {
        switch self {
        case .businessCard:
            return [
                ("ocr", "Extract Contact", "person.crop.rectangle"),
                ("summarize", "Summary", "doc.text.magnifyingglass"),
            ]
        case .receipt:
            return [
                ("ocr", "Extract Details", "text.viewfinder"),
                ("summarize", "Full Summary", "doc.text.magnifyingglass"),
                ("compress", "Compress PDF", "arrow.down.doc"),
            ]
        case .letter:
            return [
                ("ocr", "Extract Text", "text.viewfinder"),
                ("summarize", "Full Summary", "doc.text.magnifyingglass"),
                ("compress", "Compress PDF", "arrow.down.doc"),
            ]
        case .form:
            return [
                ("ocr", "Extract Fields", "text.viewfinder"),
                ("compress", "Compress PDF", "arrow.down.doc"),
                ("watermark", "Add Watermark", "drop.triangle"),
            ]
        case .textHeavy:
            return [
                ("ocr", "Extract Text", "text.viewfinder"),
                ("summarize", "Full Summary", "doc.text.magnifyingglass"),
                ("compress", "Compress PDF", "arrow.down.doc"),
            ]
        case .imageHeavy:
            return [
                ("compress", "Compress PDF", "arrow.down.doc"),
                ("watermark", "Add Watermark", "drop.triangle"),
            ]
        case .unknown:
            return [
                ("ocr", "Extract Text", "text.viewfinder"),
                ("summarize", "Full Summary", "doc.text.magnifyingglass"),
                ("compress", "Compress PDF", "arrow.down.doc"),
            ]
        }
    }
}
