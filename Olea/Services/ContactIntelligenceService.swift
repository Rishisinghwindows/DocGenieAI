import Foundation
import Contacts
import NaturalLanguage

@MainActor
final class ContactIntelligenceService {
    static let shared = ContactIntelligenceService()
    private let store = CNContactStore()
    private init() {}

    struct ExtractedContactInfo {
        var names: [String] = []
        var organizations: [String] = []
        var emails: [String] = []
        var phones: [String] = []
        var addresses: [String] = []
        var urls: [String] = []

        var isEmpty: Bool {
            names.isEmpty && organizations.isEmpty && emails.isEmpty && phones.isEmpty && addresses.isEmpty && urls.isEmpty
        }

        var allValues: [String] {
            names + organizations + emails + phones + urls
        }
    }

    struct ContactMatch: Identifiable {
        let id: String
        let contact: CNContact
        let matchType: String // "name", "email", "phone"
        let matchedValue: String

        init(contact: CNContact, matchType: String, matchedValue: String) {
            self.id = contact.identifier
            self.contact = contact
            self.matchType = matchType
            self.matchedValue = matchedValue
        }

        var displayName: String {
            let full = "\(contact.givenName) \(contact.familyName)".trimmingCharacters(in: .whitespaces)
            return full.isEmpty ? contact.organizationName : full
        }
    }

    // MARK: - Extract contact entities from any text using NLTagger + NSDataDetector

    func extractContactInfo(from text: String) -> ExtractedContactInfo {
        var info = ExtractedContactInfo()

        // NLTagger for names and organizations
        let tagger = NLTagger(tagSchemes: [.nameType])
        tagger.string = text
        let options: NLTagger.Options = [.omitPunctuation, .omitWhitespace]
        tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .nameType, options: options) { tag, range in
            if let tag = tag {
                let value = String(text[range]).trimmingCharacters(in: .whitespacesAndNewlines)
                guard value.count > 1 else { return true }
                switch tag {
                case .personalName:
                    if !info.names.contains(value) {
                        info.names.append(value)
                    }
                case .organizationName:
                    if !info.organizations.contains(value) {
                        info.organizations.append(value)
                    }
                default: break
                }
            }
            return true
        }

        // Merge consecutive name tokens into full names
        info.names = mergeConsecutiveNames(from: text, names: info.names)

        // NSDataDetector for structured data
        let types: NSTextCheckingResult.CheckingType = [.phoneNumber, .link, .address]
        if let detector = try? NSDataDetector(types: types.rawValue) {
            let matches = detector.matches(in: text, range: NSRange(text.startIndex..., in: text))
            for match in matches {
                guard let range = Range(match.range, in: text) else { continue }
                let value = String(text[range])
                switch match.resultType {
                case .phoneNumber:
                    let phone = match.phoneNumber ?? value
                    if !info.phones.contains(phone) {
                        info.phones.append(phone)
                    }
                case .link:
                    if let url = match.url {
                        if url.scheme == "mailto" {
                            let email = url.absoluteString.replacingOccurrences(of: "mailto:", with: "")
                            if !info.emails.contains(email) {
                                info.emails.append(email)
                            }
                        } else {
                            let urlStr = url.absoluteString
                            if !info.urls.contains(urlStr) {
                                info.urls.append(urlStr)
                            }
                        }
                    }
                case .address:
                    if !info.addresses.contains(value) {
                        info.addresses.append(value)
                    }
                default: break
                }
            }
        }

        // Also extract emails via regex (NSDataDetector can miss some)
        let emailPattern = #"[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}"#
        if let regex = try? NSRegularExpression(pattern: emailPattern) {
            let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
            for match in matches {
                if let range = Range(match.range, in: text) {
                    let email = String(text[range])
                    if !info.emails.contains(email) {
                        info.emails.append(email)
                    }
                }
            }
        }

        return info
    }

    // MARK: - Merge consecutive name tokens

    private func mergeConsecutiveNames(from text: String, names: [String]) -> [String] {
        guard names.count > 1 else { return names }

        var merged: [String] = []
        var used = Set<Int>()

        for i in 0..<names.count {
            guard !used.contains(i) else { continue }
            var fullName = names[i]

            // Check if the next name token appears immediately after in the original text
            for j in (i + 1)..<names.count {
                guard !used.contains(j) else { continue }
                let combined = fullName + " " + names[j]
                if text.contains(combined) {
                    fullName = combined
                    used.insert(j)
                } else {
                    break
                }
            }

            used.insert(i)
            merged.append(fullName)
        }

        return merged
    }

    // MARK: - Match extracted info against iOS Contacts

    func findMatchingContacts(for info: ExtractedContactInfo) -> [ContactMatch] {
        var matches: [ContactMatch] = []
        let keysToFetch: [CNKeyDescriptor] = [
            CNContactGivenNameKey as CNKeyDescriptor,
            CNContactFamilyNameKey as CNKeyDescriptor,
            CNContactOrganizationNameKey as CNKeyDescriptor,
            CNContactEmailAddressesKey as CNKeyDescriptor,
            CNContactPhoneNumbersKey as CNKeyDescriptor,
            CNContactThumbnailImageDataKey as CNKeyDescriptor,
            CNContactIdentifierKey as CNKeyDescriptor
        ]

        // Search by name
        for name in info.names {
            guard name.count > 2 else { continue }
            if let contacts = try? store.unifiedContacts(matching: CNContact.predicateForContacts(matchingName: name), keysToFetch: keysToFetch) {
                for c in contacts {
                    matches.append(ContactMatch(contact: c, matchType: "name", matchedValue: name))
                }
            }
        }

        // Search by organization
        for org in info.organizations {
            guard org.count > 2 else { continue }
            if let contacts = try? store.unifiedContacts(matching: CNContact.predicateForContacts(matchingName: org), keysToFetch: keysToFetch) {
                for c in contacts {
                    matches.append(ContactMatch(contact: c, matchType: "name", matchedValue: org))
                }
            }
        }

        // Search by email
        for email in info.emails {
            if let contacts = try? store.unifiedContacts(matching: CNContact.predicateForContacts(matchingEmailAddress: email), keysToFetch: keysToFetch) {
                for c in contacts {
                    matches.append(ContactMatch(contact: c, matchType: "email", matchedValue: email))
                }
            }
        }

        // Search by phone
        for phone in info.phones {
            let phoneValue = CNPhoneNumber(stringValue: phone)
            if let contacts = try? store.unifiedContacts(matching: CNContact.predicateForContacts(matching: phoneValue), keysToFetch: keysToFetch) {
                for c in contacts {
                    matches.append(ContactMatch(contact: c, matchType: "phone", matchedValue: phone))
                }
            }
        }

        // Deduplicate by contact identifier
        var seen = Set<String>()
        return matches.filter { seen.insert($0.contact.identifier).inserted }
    }

    // MARK: - Request contact access

    func requestAccess() async -> Bool {
        do {
            return try await store.requestAccess(for: .contacts)
        } catch {
            return false
        }
    }

    // MARK: - Check authorization status

    var isAuthorized: Bool {
        CNContactStore.authorizationStatus(for: .contacts) == .authorized
    }

    // MARK: - Create a new contact from extracted info

    func createContact(from info: ExtractedContactInfo) throws -> CNContact {
        let contact = CNMutableContact()

        if let name = info.names.first {
            let parts = name.split(separator: " ", maxSplits: 1)
            contact.givenName = String(parts.first ?? "")
            if parts.count > 1 { contact.familyName = String(parts.last ?? "") }
        }
        if let org = info.organizations.first {
            contact.organizationName = org
        }
        for email in info.emails {
            contact.emailAddresses.append(CNLabeledValue(label: CNLabelWork, value: email as NSString))
        }
        for phone in info.phones {
            contact.phoneNumbers.append(CNLabeledValue(label: CNLabelPhoneNumberMain, value: CNPhoneNumber(stringValue: phone)))
        }
        for url in info.urls {
            contact.urlAddresses.append(CNLabeledValue(label: CNLabelWork, value: url as NSString))
        }

        let saveRequest = CNSaveRequest()
        saveRequest.add(contact, toContainerWithIdentifier: nil)
        try store.execute(saveRequest)
        return contact
    }

    // MARK: - Generate vCard string

    func generateVCard(for info: ExtractedContactInfo) -> String {
        // RFC 6350: lines end with CRLF, special chars ( \ , ; \n ) escaped in TEXT values.
        let crlf = "\r\n"
        var vcard = "BEGIN:VCARD\(crlf)VERSION:3.0\(crlf)"
        if let name = info.names.first {
            vcard += "FN:\(Self.escapeVCard(name))\(crlf)"
            let parts = name.split(separator: " ", maxSplits: 1)
            let first = String(parts.first ?? "")
            let last = parts.count > 1 ? String(parts.last ?? "") : ""
            vcard += "N:\(Self.escapeVCard(last));\(Self.escapeVCard(first));;;\(crlf)"
        }
        if let org = info.organizations.first {
            vcard += "ORG:\(Self.escapeVCard(org))\(crlf)"
        }
        for email in info.emails {
            vcard += "EMAIL;TYPE=WORK:\(Self.escapeVCard(email))\(crlf)"
        }
        for phone in info.phones {
            vcard += "TEL;TYPE=WORK:\(Self.escapeVCard(phone))\(crlf)"
        }
        for url in info.urls {
            vcard += "URL:\(Self.escapeVCard(url))\(crlf)"
        }
        vcard += "END:VCARD\(crlf)"
        return vcard
    }

    /// Escape characters that have special meaning in vCard TEXT values per RFC 6350.
    static func escapeVCard(_ value: String) -> String {
        var escaped = ""
        escaped.reserveCapacity(value.count)
        for ch in value {
            switch ch {
            case "\\": escaped += "\\\\"
            case ",":  escaped += "\\,"
            case ";":  escaped += "\\;"
            case "\n": escaped += "\\n"
            case "\r": continue
            default:   escaped.append(ch)
            }
        }
        return escaped
    }

    // MARK: - Generate vCard QR code data

    func generateVCardQRData(for info: ExtractedContactInfo) -> Data? {
        return generateVCard(for: info).data(using: .utf8)
    }

    // MARK: - Fetch contact by identifier

    func fetchContact(identifier: String) -> CNContact? {
        let keysToFetch: [CNKeyDescriptor] = [
            CNContactGivenNameKey as CNKeyDescriptor,
            CNContactFamilyNameKey as CNKeyDescriptor,
            CNContactOrganizationNameKey as CNKeyDescriptor,
            CNContactEmailAddressesKey as CNKeyDescriptor,
            CNContactPhoneNumbersKey as CNKeyDescriptor,
            CNContactThumbnailImageDataKey as CNKeyDescriptor,
            CNContactIdentifierKey as CNKeyDescriptor
        ]
        return try? store.unifiedContact(withIdentifier: identifier, keysToFetch: keysToFetch)
    }
}
