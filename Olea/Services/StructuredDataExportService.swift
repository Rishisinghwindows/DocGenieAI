import Foundation
import Contacts

final class StructuredDataExportService: Sendable {
    static let shared = StructuredDataExportService()

    private init() {}

    // MARK: - Receipt CSV Export

    func exportReceiptToCSV(receipt: ReceiptData, fileName: String) throws -> URL {
        var csv = "Item,Amount\n"

        for item in receipt.items {
            // Each item line typically has description and price
            let escaped = item.replacingOccurrences(of: "\"", with: "\"\"")
            csv += "\"\(escaped)\"\n"
        }

        csv += "\n"
        if let subtotal = receipt.subtotal {
            csv += "Subtotal,\(subtotal)\n"
        }
        if let tax = receipt.tax {
            csv += "Tax,\(tax)\n"
        }
        if let total = receipt.total {
            csv += "Total,\(total)\n"
        }

        let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let sanitizedName = fileName
            .replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: "/", with: "_")
        let csvURL = documentsDir.appendingPathComponent("\(sanitizedName).csv")

        try csv.write(to: csvURL, atomically: true, encoding: .utf8)
        return csvURL
    }

    // MARK: - Business Card to Contact

    func exportBusinessCardToContact(card: BusinessCardData) async throws {
        let store = CNContactStore()

        let granted = try await store.requestAccess(for: .contacts)
        guard granted else {
            throw StructuredDataExportError.contactsAccessDenied
        }

        let contact = CNMutableContact()

        if let name = card.name {
            let components = name.split(separator: " ", maxSplits: 1)
            contact.givenName = String(components.first ?? "")
            if components.count > 1 {
                contact.familyName = String(components.last ?? "")
            }
        }

        if let company = card.company {
            contact.organizationName = company
        }

        if let email = card.email {
            contact.emailAddresses = [
                CNLabeledValue(label: CNLabelWork, value: email as NSString)
            ]
        }

        if let phone = card.phone {
            contact.phoneNumbers = [
                CNLabeledValue(label: CNLabelPhoneNumberMain, value: CNPhoneNumber(stringValue: phone))
            ]
        }

        if let website = card.website {
            let urlString = website.hasPrefix("http") ? website : "https://\(website)"
            contact.urlAddresses = [
                CNLabeledValue(label: CNLabelWork, value: urlString as NSString)
            ]
        }

        let saveRequest = CNSaveRequest()
        saveRequest.add(contact, toContainerWithIdentifier: nil)
        try store.execute(saveRequest)
    }

    // MARK: - Clipboard Formatting

    func formatForClipboard(receipt: ReceiptData) -> String {
        var lines: [String] = []
        lines.append("Receipt: \(receipt.vendor)")
        if let date = receipt.date {
            lines.append("Date: \(date)")
        }
        if !receipt.items.isEmpty {
            lines.append("")
            lines.append("Items:")
            for item in receipt.items {
                lines.append("  \(item)")
            }
        }
        lines.append("")
        if let subtotal = receipt.subtotal {
            lines.append("Subtotal: \(subtotal)")
        }
        if let tax = receipt.tax {
            lines.append("Tax: \(tax)")
        }
        if let total = receipt.total {
            lines.append("Total: \(total)")
        }
        return lines.joined(separator: "\n")
    }

    func formatForClipboard(card: BusinessCardData) -> String {
        var lines: [String] = []
        if let name = card.name { lines.append(name) }
        if let company = card.company { lines.append(company) }
        if let email = card.email { lines.append("Email: \(email)") }
        if let phone = card.phone { lines.append("Phone: \(phone)") }
        if let website = card.website { lines.append("Web: \(website)") }
        return lines.joined(separator: "\n")
    }
}

enum StructuredDataExportError: LocalizedError {
    case contactsAccessDenied
    case exportFailed

    var errorDescription: String? {
        switch self {
        case .contactsAccessDenied:
            return "Contacts access was denied. Please enable it in Settings."
        case .exportFailed:
            return "Failed to export the data."
        }
    }
}
