import SwiftUI
import SwiftData
import Contacts
import CoreImage.CIFilterBuiltins

struct DocumentContactsView: View {
    let file: DocumentFile
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var extractedInfo = ContactIntelligenceService.ExtractedContactInfo()
    @State private var contactMatches: [ContactIntelligenceService.ContactMatch] = []
    @State private var isLoading = true
    @State private var hasContactAccess = false
    @State private var errorMessage: String?
    @State private var showSaveSuccess = false
    @State private var showQRSheet = false
    @State private var savedContactName: String?

    private let service = ContactIntelligenceService.shared

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppSpacing.lg) {
                    if isLoading {
                        loadingView
                    } else if let error = errorMessage {
                        errorView(error)
                    } else if extractedInfo.isEmpty {
                        EmptyStateView(
                            icon: "person.crop.rectangle.badge.plus",
                            title: "No Contact Info Found",
                            message: "No names, emails, or phone numbers were detected in this document."
                        )
                        .padding(.top, AppSpacing.xl)
                    } else {
                        contactContent
                    }
                }
                .padding(AppSpacing.md)
            }
            .background(Color.appBGDark)
            .navigationTitle("Detect Contacts")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                        .foregroundStyle(Color.appPrimary)
                }
            }
            .task {
                await analyzeDocument()
            }
            .alert("Contact Saved", isPresented: $showSaveSuccess) {
                Button("OK") {}
            } message: {
                Text("\(savedContactName ?? "Contact") has been added to your contacts.")
            }
            .sheet(isPresented: $showQRSheet) {
                qrCodeSheet
            }
        }
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: AppSpacing.lg) {
            ProgressView()
                .controlSize(.large)
                .tint(Color.appPrimary)

            Text("Analyzing document...")
                .font(.appBody)
                .foregroundStyle(Color.appTextMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 80)
    }

    // MARK: - Error View

    private func errorView(_ message: String) -> some View {
        EmptyStateView(
            icon: "exclamationmark.triangle",
            title: "Analysis Failed",
            message: message
        )
        .padding(.top, AppSpacing.xl)
    }

    // MARK: - Contact Content

    private var contactContent: some View {
        VStack(spacing: AppSpacing.lg) {
            // Matched contacts section
            if !contactMatches.isEmpty {
                matchedContactsSection
            }

            // Extracted info section
            extractedInfoSection

            // Action buttons
            actionButtonsSection
        }
    }

    // MARK: - Matched Contacts Section

    private var matchedContactsSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Label("Matched Contacts", systemImage: "person.crop.circle.badge.checkmark")
                .font(.appH3)
                .foregroundStyle(Color.appText)

            ForEach(Array(contactMatches.enumerated()), id: \.element.id) { index, match in
                AppCard(style: .glass) {
                    HStack(spacing: AppSpacing.md) {
                        contactAvatar(for: match.contact)

                        VStack(alignment: .leading, spacing: AppSpacing.xs) {
                            Text(match.displayName)
                                .font(.appBody)
                                .foregroundStyle(Color.appText)
                                .lineLimit(1)

                            if !match.contact.organizationName.isEmpty {
                                Text(match.contact.organizationName)
                                    .font(.appCaption)
                                    .foregroundStyle(Color.appTextMuted)
                                    .lineLimit(1)
                            }
                        }

                        Spacer()

                        matchTypeBadge(match.matchType)
                    }
                }
                .staggeredAppear(index: index)
            }

            // Link all matched contacts button
            if !contactMatches.isEmpty {
                SecondaryButton(title: "Link All to Document", icon: "link") {
                    linkMatchedContacts()
                }
            }
        }
    }

    // MARK: - Extracted Info Section

    private var extractedInfoSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Label("Extracted Information", systemImage: "text.magnifyingglass")
                .font(.appH3)
                .foregroundStyle(Color.appText)

            AppCard {
                VStack(alignment: .leading, spacing: AppSpacing.md) {
                    if !extractedInfo.names.isEmpty {
                        infoRow(icon: "person", label: "Names", values: extractedInfo.names)
                    }
                    if !extractedInfo.organizations.isEmpty {
                        infoRow(icon: "building.2", label: "Organizations", values: extractedInfo.organizations)
                    }
                    if !extractedInfo.emails.isEmpty {
                        infoRow(icon: "envelope", label: "Emails", values: extractedInfo.emails)
                    }
                    if !extractedInfo.phones.isEmpty {
                        infoRow(icon: "phone", label: "Phones", values: extractedInfo.phones)
                    }
                    if !extractedInfo.urls.isEmpty {
                        infoRow(icon: "globe", label: "URLs", values: extractedInfo.urls)
                    }
                    if !extractedInfo.addresses.isEmpty {
                        infoRow(icon: "mappin", label: "Addresses", values: extractedInfo.addresses)
                    }
                }
            }
        }
    }

    // MARK: - Action Buttons Section

    private var actionButtonsSection: some View {
        VStack(spacing: AppSpacing.md) {
            if hasContactAccess {
                PrimaryButton(title: "Save as New Contact", icon: "person.badge.plus") {
                    saveAsNewContact()
                }

                SecondaryButton(title: "Generate QR Code", icon: "qrcode") {
                    HapticManager.light()
                    showQRSheet = true
                }
            } else {
                PrimaryButton(title: "Grant Contact Access", icon: "lock.open") {
                    Task { await requestContactAccess() }
                }

                Text("Contact access is needed to match and save contacts.")
                    .font(.appCaption)
                    .foregroundStyle(Color.appTextMuted)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.top, AppSpacing.sm)
    }

    // MARK: - QR Code Sheet

    private var qrCodeSheet: some View {
        NavigationStack {
            VStack(spacing: AppSpacing.lg) {
                Spacer()

                if let qrImage = generateQRCode() {
                    Image(uiImage: qrImage)
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 250, height: 250)
                        .clipShape(RoundedRectangle(cornerRadius: AppCornerRadius.lg))
                        .shadow(color: Color.appPrimary.opacity(0.3), radius: 12)
                } else {
                    EmptyStateView(
                        icon: "qrcode",
                        title: "QR Generation Failed",
                        message: "Could not generate a QR code for this contact info."
                    )
                }

                Text("Scan to add contact")
                    .font(.appBody)
                    .foregroundStyle(Color.appTextMuted)

                if let name = extractedInfo.names.first {
                    Text(name)
                        .font(.appH2)
                        .foregroundStyle(Color.appText)
                }

                Spacer()
            }
            .frame(maxWidth: .infinity)
            .background(Color.appBGDark)
            .navigationTitle("Contact QR")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { showQRSheet = false }
                        .foregroundStyle(Color.appPrimary)
                }
            }
        }
    }

    // MARK: - Helper Views

    private func contactAvatar(for contact: CNContact) -> some View {
        Group {
            if let imageData = contact.thumbnailImageData, let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 44, height: 44)
                    .clipShape(Circle())
            } else {
                ZStack {
                    Circle()
                        .fill(Color.appPrimary.opacity(0.15))
                        .frame(width: 44, height: 44)

                    Text(contactInitials(for: contact))
                        .font(.appBody)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.appPrimary)
                }
            }
        }
    }

    private func contactInitials(for contact: CNContact) -> String {
        let first = contact.givenName.prefix(1)
        let last = contact.familyName.prefix(1)
        let initials = "\(first)\(last)"
        return initials.isEmpty ? "?" : initials.uppercased()
    }

    private func matchTypeBadge(_ type: String) -> some View {
        Text(type.capitalized)
            .font(.appMicro)
            .fontWeight(.medium)
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(badgeColor(for: type), in: Capsule())
    }

    private func badgeColor(for type: String) -> Color {
        switch type {
        case "email": return .appSuccess
        case "phone": return .appAccent
        case "name": return .appPrimary
        default: return .appTextMuted
        }
    }

    private func infoRow(icon: String, label: String, values: [String]) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Label(label, systemImage: icon)
                .font(.appCaption)
                .foregroundStyle(Color.appTextMuted)

            ForEach(values, id: \.self) { value in
                Text(value)
                    .font(.appBody)
                    .foregroundStyle(Color.appText)
                    .textSelection(.enabled)
            }
        }
    }

    // MARK: - Actions

    private func analyzeDocument() async {
        isLoading = true
        defer { isLoading = false }

        // Check contact access
        hasContactAccess = service.isAuthorized
        if !hasContactAccess {
            hasContactAccess = await service.requestAccess()
        }

        // Get text content
        let text: String
        if let cached = file.ocrTextCache, !cached.isEmpty {
            text = cached
        } else if let url = file.fileURL {
            do {
                text = try await OCRService.shared.extractText(from: url)
                file.ocrTextCache = text
                try? modelContext.save()
            } catch {
                errorMessage = "Could not extract text: \(error.localizedDescription)"
                return
            }
        } else {
            errorMessage = "Document file not found."
            return
        }

        // Extract contact info
        extractedInfo = service.extractContactInfo(from: text)

        // Find matching contacts
        if hasContactAccess {
            contactMatches = service.findMatchingContacts(for: extractedInfo)
        }

        HapticManager.success()
    }

    private func requestContactAccess() async {
        hasContactAccess = await service.requestAccess()
        if hasContactAccess {
            contactMatches = service.findMatchingContacts(for: extractedInfo)
            HapticManager.success()
        } else {
            HapticManager.error()
        }
    }

    private func saveAsNewContact() {
        do {
            let contact = try service.createContact(from: extractedInfo)
            let name = "\(contact.givenName) \(contact.familyName)".trimmingCharacters(in: .whitespaces)
            savedContactName = name.isEmpty ? "Contact" : name

            // Link the contact to the document
            var identifiers = file.contactIdentifiers?.split(separator: ",").map(String.init) ?? []
            if !identifiers.contains(contact.identifier) {
                identifiers.append(contact.identifier)
                file.contactIdentifiers = identifiers.joined(separator: ",")
                try? modelContext.save()
            }

            showSaveSuccess = true
            HapticManager.success()
        } catch {
            errorMessage = "Failed to save contact: \(error.localizedDescription)"
            HapticManager.error()
        }
    }

    private func linkMatchedContacts() {
        var identifiers = file.contactIdentifiers?.split(separator: ",").map(String.init) ?? []
        for match in contactMatches {
            if !identifiers.contains(match.contact.identifier) {
                identifiers.append(match.contact.identifier)
            }
        }
        file.contactIdentifiers = identifiers.joined(separator: ",")
        try? modelContext.save()
        HapticManager.success()
    }

    private func generateQRCode() -> UIImage? {
        guard let data = service.generateVCardQRData(for: extractedInfo) else { return nil }
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        filter.setValue(data, forKey: "inputMessage")
        filter.setValue("M", forKey: "inputCorrectionLevel")

        guard let outputImage = filter.outputImage else { return nil }
        let scale = 250.0 / outputImage.extent.width
        let scaledImage = outputImage.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        guard let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}
