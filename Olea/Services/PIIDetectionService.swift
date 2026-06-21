import Foundation

final class PIIDetectionService: Sendable {
    static let shared = PIIDetectionService()
    private init() {}

    enum PIIType: String, CaseIterable, Sendable {
        case ssn = "SSN"
        case creditCard = "Credit Card"
        case email = "Email"
        case phone = "Phone"
        case address = "Address"
        case dateOfBirth = "Date of Birth"
        case driverLicense = "Driver License"
        case passport = "Passport Number"
        case bankAccount = "Bank Account"
        case ipAddress = "IP Address"

        var icon: String {
            switch self {
            case .ssn: return "number.circle.fill"
            case .creditCard: return "creditcard.fill"
            case .email: return "envelope.fill"
            case .phone: return "phone.fill"
            case .address: return "mappin.circle.fill"
            case .dateOfBirth: return "calendar.circle.fill"
            case .driverLicense: return "car.fill"
            case .passport: return "airplane.circle.fill"
            case .bankAccount: return "building.columns.fill"
            case .ipAddress: return "network"
            }
        }

        var color: String {
            switch self {
            case .ssn: return "appDanger"
            case .creditCard: return "appDanger"
            case .email: return "appWarning"
            case .phone: return "appWarning"
            case .address: return "appAccent"
            case .dateOfBirth: return "appPrimary"
            case .driverLicense: return "appDanger"
            case .passport: return "appDanger"
            case .bankAccount: return "appDanger"
            case .ipAddress: return "appWarning"
            }
        }

        // Higher value = stronger / more specific match. Used to break overlap ties.
        var priority: Int {
            switch self {
            case .ssn: return 100
            case .creditCard: return 95
            case .passport: return 90
            case .driverLicense: return 85
            case .bankAccount: return 80
            case .dateOfBirth: return 75
            case .email: return 70
            case .phone: return 65
            case .address: return 60
            case .ipAddress: return 50
            }
        }
    }

    struct PIIMatch: Sendable {
        let type: PIIType
        let value: String
        let range: Range<String.Index>
    }

    func detectPII(in text: String) -> [PIIMatch] {
        var matches: [PIIMatch] = []

        // SSN: XXX-XX-XXXX
        let ssnPattern = #"\b\d{3}-\d{2}-\d{4}\b"#
        matches += findPattern(ssnPattern, type: .ssn, in: text)

        // Credit card: 13–19 digits possibly grouped by space or dash. Validated with Luhn.
        let ccPattern = #"\b(?:\d[ \-]?){12,18}\d\b"#
        matches += findPattern(ccPattern, type: .creditCard, in: text) { value in
            let digits = value.filter(\.isNumber)
            return (13...19).contains(digits.count) && Self.passesLuhn(digits)
        }

        // Date of birth: MM/DD/YYYY, MM-DD-YYYY (1900-2099)
        let dobPattern = #"\b(?:0[1-9]|1[0-2])[/\-](?:0[1-9]|[12]\d|3[01])[/\-](?:19|20)\d{2}\b"#
        matches += findPattern(dobPattern, type: .dateOfBirth, in: text)

        // Driver license: require contextual prefix to avoid matching every short alphanumeric code.
        // Common phrases: "DL", "DL#", "Driver License", "License No"
        let dlPattern = #"(?i)(?:driver(?:'s)?\s+licen[sc]e|DL\s*#?|licen[sc]e\s*(?:no|number|#))[:\s]*([A-Z]{1,2}\d{4,8})\b"#
        matches += findCapturedPattern(dlPattern, type: .driverLicense, in: text, captureGroup: 1)

        // Passport: require contextual prefix.
        let passportPattern = #"(?i)passport(?:\s*(?:no|number|#))?[:\s]*([A-Z]\d{8})\b"#
        matches += findCapturedPattern(passportPattern, type: .passport, in: text, captureGroup: 1)

        // Bank account / IBAN: only with a clear prefix to avoid matching every long number.
        let bankPattern = #"(?i)\b(?:iban|account(?:\s*(?:no|number|#))?|acct(?:\s*(?:no|number|#))?)[:\s]*([A-Z0-9]{8,34})\b"#
        matches += findCapturedPattern(bankPattern, type: .bankAccount, in: text, captureGroup: 1)

        // IP v4 with octet validation
        let ipPattern = #"\b(?:(?:25[0-5]|2[0-4]\d|[01]?\d{1,2})\.){3}(?:25[0-5]|2[0-4]\d|[01]?\d{1,2})\b"#
        matches += findPattern(ipPattern, type: .ipAddress, in: text)

        // Use NSDataDetector for emails, phones, addresses
        let detectorTypes: NSTextCheckingResult.CheckingType = [.phoneNumber, .link, .address]
        if let detector = try? NSDataDetector(types: detectorTypes.rawValue) {
            let nsRange = NSRange(text.startIndex..., in: text)
            for m in detector.matches(in: text, range: nsRange) {
                guard let range = Range(m.range, in: text) else { continue }
                let value = String(text[range])
                switch m.resultType {
                case .phoneNumber:
                    matches.append(PIIMatch(type: .phone, value: value, range: range))
                case .link:
                    if let url = m.url, url.scheme == "mailto" {
                        let emailValue = value.hasPrefix("mailto:") ? String(value.dropFirst(7)) : value
                        matches.append(PIIMatch(type: .email, value: emailValue, range: range))
                    }
                case .address:
                    matches.append(PIIMatch(type: .address, value: value, range: range))
                default:
                    break
                }
            }
        }

        // Email regex (NSDataDetector misses bare emails without mailto: scheme)
        let emailPattern = #"[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}"#
        matches += findPattern(emailPattern, type: .email, in: text)

        return resolveOverlaps(matches)
    }

    private func findPattern(
        _ pattern: String,
        type: PIIType,
        in text: String,
        validate: ((String) -> Bool)? = nil
    ) -> [PIIMatch] {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let nsRange = NSRange(text.startIndex..., in: text)
        return regex.matches(in: text, range: nsRange).compactMap { result in
            guard let range = Range(result.range, in: text) else { return nil }
            let value = String(text[range])
            if let validate, !validate(value) { return nil }
            return PIIMatch(type: type, value: value, range: range)
        }
    }

    private func findCapturedPattern(
        _ pattern: String,
        type: PIIType,
        in text: String,
        captureGroup: Int
    ) -> [PIIMatch] {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let nsRange = NSRange(text.startIndex..., in: text)
        return regex.matches(in: text, range: nsRange).compactMap { result in
            guard captureGroup < result.numberOfRanges,
                  let range = Range(result.range(at: captureGroup), in: text) else { return nil }
            return PIIMatch(type: type, value: String(text[range]), range: range)
        }
    }

    /// Drop overlapping matches, keeping the higher-priority type. Output is sorted by lower bound.
    private func resolveOverlaps(_ matches: [PIIMatch]) -> [PIIMatch] {
        // Sort: lower bound asc, then priority desc, then range length desc
        let sorted = matches.sorted { a, b in
            if a.range.lowerBound != b.range.lowerBound {
                return a.range.lowerBound < b.range.lowerBound
            }
            if a.type.priority != b.type.priority {
                return a.type.priority > b.type.priority
            }
            return a.value.count > b.value.count
        }

        var kept: [PIIMatch] = []
        for match in sorted {
            if let last = kept.last, last.range.overlaps(match.range) {
                // Conflict: keep whichever has higher priority, falling back to longer span
                if match.type.priority > last.type.priority ||
                    (match.type.priority == last.type.priority && match.value.count > last.value.count) {
                    kept.removeLast()
                    kept.append(match)
                }
            } else {
                kept.append(match)
            }
        }
        return kept
    }

    /// Redact PII from text by replacing matched regions with [TYPE REDACTED].
    /// Caller is expected to pass non-overlapping matches (use resolveOverlaps if unsure).
    func redactText(_ text: String, matches: [PIIMatch]) -> String {
        var result = text
        // Process in reverse order so earlier indices remain valid after replacement
        let nonOverlapping = resolveOverlaps(matches)
        for match in nonOverlapping.sorted(by: { $0.range.lowerBound > $1.range.lowerBound }) {
            result.replaceSubrange(match.range, with: "[\(match.type.rawValue.uppercased()) REDACTED]")
        }
        return result
    }

    /// Mask a PII value for display (e.g. "123-45-6789" -> "***-**-6789")
    func maskValue(_ value: String, type: PIIType) -> String {
        switch type {
        case .ssn:
            return "***-**-" + String(value.suffix(4))
        case .creditCard:
            let digits = value.filter(\.isNumber)
            return "**** **** **** " + String(digits.suffix(4))
        case .email:
            let parts = value.split(separator: "@", maxSplits: 1)
            if parts.count == 2 {
                let local = parts[0]
                let prefix = local.prefix(1)
                return "\(prefix)***@\(parts[1])"
            }
            return "***"
        case .phone:
            return "***" + String(value.suffix(4))
        case .bankAccount:
            return "****" + String(value.suffix(4))
        default:
            let visibleCount = min(3, value.count)
            return String(value.prefix(visibleCount)) + String(repeating: "*", count: max(0, value.count - visibleCount))
        }
    }

    // MARK: - Luhn algorithm for credit-card validation

    static func passesLuhn(_ digits: String) -> Bool {
        let nums = digits.compactMap { $0.wholeNumberValue }
        guard nums.count >= 13 else { return false }
        var sum = 0
        for (i, d) in nums.reversed().enumerated() {
            if i % 2 == 1 {
                let doubled = d * 2
                sum += (doubled > 9) ? doubled - 9 : doubled
            } else {
                sum += d
            }
        }
        return sum % 10 == 0
    }
}
