import SwiftUI

struct StructuredDataView: View {
    let file: DocumentFile
    @Environment(\.dismiss) private var dismiss

    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var contentType: ScanContentType?
    @State private var receiptData: ReceiptData?
    @State private var businessCardData: BusinessCardData?
    @State private var showSuccess = false
    @State private var successMessage = ""
    @State private var showShareSheet = false
    @State private var shareURL: URL?

    private let exportService = StructuredDataExportService.shared

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBGDark.ignoresSafeArea()

                if isLoading {
                    loadingView
                } else if let errorMessage {
                    errorView(errorMessage)
                } else if showSuccess {
                    successView
                } else {
                    contentView
                }
            }
            .navigationTitle("Extracted Data")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                        .foregroundStyle(Color.appTextMuted)
                }
            }
            .sheet(isPresented: $showShareSheet) {
                if let shareURL {
                    ActivityView(activityItems: [shareURL])
                }
            }
            .confettiOnComplete(showSuccess)
        }
        .task {
            await extractData()
        }
    }

    // MARK: - Loading

    private var loadingView: some View {
        VStack(spacing: AppSpacing.lg) {
            ProgressView()
                .tint(Color.appPrimary)
                .scaleEffect(1.2)
            Text("Extracting structured data...")
                .font(.appBody)
                .foregroundStyle(Color.appTextMuted)
        }
    }

    // MARK: - Error

    private func errorView(_ message: String) -> some View {
        EmptyStateView(
            icon: "exclamationmark.triangle",
            title: "Extraction Failed",
            message: message
        )
        .padding(AppSpacing.lg)
    }

    // MARK: - Success

    private var successView: some View {
        VStack(spacing: AppSpacing.lg) {
            AnimatedCheckmark()
            Text(successMessage)
                .font(.appH3)
                .foregroundStyle(Color.appText)
                .multilineTextAlignment(.center)
        }
        .padding(AppSpacing.xl)
    }

    // MARK: - Content

    @ViewBuilder
    private var contentView: some View {
        ScrollView {
            VStack(spacing: AppSpacing.md) {
                // Header card
                headerCard
                    .staggeredAppear(index: 0)

                if let receipt = receiptData {
                    receiptView(receipt)
                } else if let card = businessCardData {
                    businessCardView(card)
                }

                // Export actions
                exportActionsView
                    .staggeredAppear(index: 3)
            }
            .padding(AppSpacing.md)
        }
    }

    // MARK: - Header

    private var headerCard: some View {
        AppCard {
            HStack(spacing: AppSpacing.md) {
                Image(systemName: contentType?.displayIcon ?? "doc")
                    .font(.system(size: 28))
                    .foregroundStyle(Color.appPrimary)
                    .frame(width: 48, height: 48)
                    .background(Color.appPrimary.opacity(0.12), in: RoundedRectangle(cornerRadius: AppCornerRadius.sm))

                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text(contentType?.displayLabel ?? "Document")
                        .font(.appH3)
                        .foregroundStyle(Color.appText)
                    Text(file.fullFileName)
                        .font(.appCaption)
                        .foregroundStyle(Color.appTextMuted)
                        .lineLimit(1)
                }

                Spacer()
            }
        }
    }

    // MARK: - Receipt View

    private func receiptView(_ receipt: ReceiptData) -> some View {
        VStack(spacing: AppSpacing.md) {
            // Vendor & Date
            AppCard {
                VStack(spacing: AppSpacing.sm) {
                    dataRow(label: "Vendor", value: receipt.vendor, icon: "storefront")
                    if let date = receipt.date {
                        Divider().overlay(Color.appBGDark)
                        dataRow(label: "Date", value: date, icon: "calendar")
                    }
                }
            }
            .staggeredAppear(index: 1)

            // Line Items
            if !receipt.items.isEmpty {
                AppCard {
                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        Label("Items", systemImage: "list.bullet")
                            .font(.appCaption)
                            .foregroundStyle(Color.appTextMuted)

                        ForEach(Array(receipt.items.enumerated()), id: \.offset) { _, item in
                            Text(item)
                                .font(.appBody)
                                .foregroundStyle(Color.appText)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            if item != receipt.items.last {
                                Divider().overlay(Color.appBGDark)
                            }
                        }
                    }
                }
                .staggeredAppear(index: 2)
            }

            // Totals
            AppCard {
                VStack(spacing: AppSpacing.sm) {
                    if let subtotal = receipt.subtotal {
                        dataRow(label: "Subtotal", value: subtotal, icon: "sum")
                    }
                    if let tax = receipt.tax {
                        Divider().overlay(Color.appBGDark)
                        dataRow(label: "Tax", value: tax, icon: "percent")
                    }
                    if let total = receipt.total {
                        Divider().overlay(Color.appBGDark)
                        HStack {
                            Label("Total", systemImage: "dollarsign.circle.fill")
                                .font(.appH3)
                                .foregroundStyle(Color.appText)
                            Spacer()
                            Text(total)
                                .font(.appH2)
                                .foregroundStyle(Color.appSuccess)
                                .fontWeight(.bold)
                        }
                    }
                }
            }
            .staggeredAppear(index: 3)
        }
    }

    // MARK: - Business Card View

    private func businessCardView(_ card: BusinessCardData) -> some View {
        VStack(spacing: AppSpacing.md) {
            AppCard {
                VStack(spacing: AppSpacing.sm) {
                    if let name = card.name {
                        dataRow(label: "Name", value: name, icon: "person.fill")
                    }
                    if let company = card.company {
                        Divider().overlay(Color.appBGDark)
                        dataRow(label: "Company", value: company, icon: "building.2.fill")
                    }
                }
            }
            .staggeredAppear(index: 1)

            AppCard {
                VStack(spacing: AppSpacing.sm) {
                    if let email = card.email {
                        Button {
                            if let url = URL(string: "mailto:\(email)") {
                                UIApplication.shared.open(url)
                            }
                        } label: {
                            tappableDataRow(label: "Email", value: email, icon: "envelope.fill")
                        }
                    }

                    if let phone = card.phone {
                        if card.email != nil {
                            Divider().overlay(Color.appBGDark)
                        }
                        Button {
                            let cleaned = phone.replacingOccurrences(of: " ", with: "")
                                .replacingOccurrences(of: "-", with: "")
                                .replacingOccurrences(of: "(", with: "")
                                .replacingOccurrences(of: ")", with: "")
                            if let url = URL(string: "tel:\(cleaned)") {
                                UIApplication.shared.open(url)
                            }
                        } label: {
                            tappableDataRow(label: "Phone", value: phone, icon: "phone.fill")
                        }
                    }

                    if let website = card.website {
                        Divider().overlay(Color.appBGDark)
                        Button {
                            let urlString = website.hasPrefix("http") ? website : "https://\(website)"
                            if let url = URL(string: urlString) {
                                UIApplication.shared.open(url)
                            }
                        } label: {
                            tappableDataRow(label: "Website", value: website, icon: "globe")
                        }
                    }
                }
            }
            .staggeredAppear(index: 2)
        }
    }

    // MARK: - Data Row Helpers

    private func dataRow(label: String, value: String, icon: String) -> some View {
        HStack {
            Label(label, systemImage: icon)
                .font(.appCaption)
                .foregroundStyle(Color.appTextMuted)
            Spacer()
            Text(value)
                .font(.appBody)
                .foregroundStyle(Color.appText)
                .multilineTextAlignment(.trailing)
        }
    }

    private func tappableDataRow(label: String, value: String, icon: String) -> some View {
        HStack {
            Label(label, systemImage: icon)
                .font(.appCaption)
                .foregroundStyle(Color.appTextMuted)
            Spacer()
            HStack(spacing: AppSpacing.xs) {
                Text(value)
                    .font(.appBody)
                    .foregroundStyle(Color.appAccent)
                    .multilineTextAlignment(.trailing)
                Image(systemName: "chevron.right")
                    .font(.appMicro)
                    .foregroundStyle(Color.appTextDim)
            }
        }
    }

    // MARK: - Export Actions

    private var exportActionsView: some View {
        VStack(spacing: AppSpacing.sm) {
            Text("Export")
                .font(.appCaption)
                .foregroundStyle(Color.appTextMuted)
                .frame(maxWidth: .infinity, alignment: .leading)

            if receiptData != nil {
                PrimaryButton(title: "Export as CSV", icon: "tablecells") {
                    exportCSV()
                }
            }

            HStack(spacing: AppSpacing.sm) {
                SecondaryButton(title: "Copy", icon: "doc.on.doc") {
                    copyToClipboard()
                }

                SecondaryButton(title: "Share", icon: "square.and.arrow.up") {
                    shareData()
                }
            }

            if businessCardData != nil {
                PrimaryButton(title: "Add to Contacts", icon: "person.crop.circle.badge.plus") {
                    Task { await addToContacts() }
                }
            }
        }
    }

    // MARK: - Data Extraction

    private func extractData() async {
        do {
            guard let url = file.fileURL else {
                errorMessage = "File not found."
                isLoading = false
                return
            }

            let ocrText: String
            if let cached = file.ocrTextCache, !cached.isEmpty {
                ocrText = cached
            } else {
                ocrText = try await OCRService.shared.extractText(from: url)
                file.ocrTextCache = ocrText
            }

            let type = ScanContentType.classify(ocrText: ocrText)
            contentType = type

            switch type {
            case .receipt:
                receiptData = ScanContentType.parseReceipt(ocrText: ocrText)
            case .businessCard:
                businessCardData = ScanContentType.parseBusinessCard(ocrText: ocrText)
            default:
                // For other types, attempt receipt parse as fallback
                receiptData = ScanContentType.parseReceipt(ocrText: ocrText)
            }

            withAnimation(.easeOut(duration: 0.3)) {
                isLoading = false
            }
        } catch {
            errorMessage = error.localizedDescription
            withAnimation { isLoading = false }
        }
    }

    // MARK: - Export Actions

    private func exportCSV() {
        guard let receipt = receiptData else { return }
        do {
            let url = try exportService.exportReceiptToCSV(
                receipt: receipt,
                fileName: file.name
            )
            HapticManager.success()
            showSuccessState("CSV exported successfully")
            // Set share URL for potential sharing
            shareURL = url
        } catch {
            HapticManager.error()
            errorMessage = error.localizedDescription
        }
    }

    private func copyToClipboard() {
        let text: String
        if let receipt = receiptData {
            text = exportService.formatForClipboard(receipt: receipt)
        } else if let card = businessCardData {
            text = exportService.formatForClipboard(card: card)
        } else {
            return
        }

        UIPasteboard.general.string = text
        HapticManager.success()
        showSuccessState("Copied to clipboard")
    }

    private func shareData() {
        if let receipt = receiptData {
            // Try to create a temporary CSV for sharing
            if let url = try? exportService.exportReceiptToCSV(receipt: receipt, fileName: file.name) {
                shareURL = url
                showShareSheet = true
            }
        } else if let card = businessCardData {
            let text = exportService.formatForClipboard(card: card)
            // Write text to a temp file for sharing
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("\(file.name)_contact.txt")
            try? text.write(to: tempURL, atomically: true, encoding: .utf8)
            shareURL = tempURL
            showShareSheet = true
        }
    }

    private func addToContacts() async {
        guard let card = businessCardData else { return }
        do {
            try await exportService.exportBusinessCardToContact(card: card)
            await MainActor.run {
                HapticManager.success()
                showSuccessState("Contact saved")
            }
        } catch {
            await MainActor.run {
                HapticManager.error()
                errorMessage = error.localizedDescription
            }
        }
    }

    private func showSuccessState(_ message: String) {
        successMessage = message
        withAnimation(.easeInOut(duration: 0.3)) {
            showSuccess = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            dismiss()
        }
    }
}
