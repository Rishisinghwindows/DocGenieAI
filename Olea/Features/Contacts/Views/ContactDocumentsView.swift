import SwiftUI
import SwiftData
import Contacts

struct ContactDocumentsView: View {
    let contact: CNContact
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \DocumentFile.importedAt, order: .reverse) private var allFiles: [DocumentFile]

    @State private var isSearching = true

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppSpacing.lg) {
                    // Contact header
                    contactHeader

                    if isSearching {
                        loadingView
                    } else if linkedDocuments.isEmpty {
                        EmptyStateView(
                            icon: "doc.text.magnifyingglass",
                            title: "No Documents Found",
                            message: "No documents are linked to or mention \(displayName)."
                        )
                        .padding(.top, AppSpacing.lg)
                    } else {
                        documentsSection
                    }
                }
                .padding(AppSpacing.md)
            }
            .background(Color.appBGDark)
            .navigationTitle("Contact Documents")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                        .foregroundStyle(Color.appPrimary)
                }
            }
            .task {
                // Brief delay to allow UI to render
                try? await Task.sleep(for: .milliseconds(100))
                isSearching = false
            }
        }
    }

    // MARK: - Contact Header

    private var contactHeader: some View {
        AppCard(style: .glass) {
            HStack(spacing: AppSpacing.md) {
                contactAvatar
                    .frame(width: 56, height: 56)

                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text(displayName)
                        .font(.appH2)
                        .foregroundStyle(Color.appText)

                    if !contact.organizationName.isEmpty {
                        Text(contact.organizationName)
                            .font(.appBody)
                            .foregroundStyle(Color.appTextMuted)
                    }

                    Text("\(linkedDocuments.count) document\(linkedDocuments.count == 1 ? "" : "s") found")
                        .font(.appCaption)
                        .foregroundStyle(Color.appTextDim)
                }

                Spacer()
            }
        }
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: AppSpacing.md) {
            ProgressView()
                .controlSize(.regular)
                .tint(Color.appPrimary)

            Text("Searching documents...")
                .font(.appCaption)
                .foregroundStyle(Color.appTextMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 40)
    }

    // MARK: - Documents Section

    private var documentsSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Label("Linked Documents", systemImage: "doc.on.doc")
                .font(.appH3)
                .foregroundStyle(Color.appText)

            ForEach(Array(linkedDocuments.enumerated()), id: \.element.id) { index, file in
                NavigationLink(value: file) {
                    documentRow(file: file)
                }
                .staggeredAppear(index: index)
            }
        }
        .navigationDestination(for: DocumentFile.self) { file in
            DocumentViewerRouter(file: file)
        }
    }

    // MARK: - Document Row

    private func documentRow(file: DocumentFile) -> some View {
        AppCard {
            HStack(spacing: AppSpacing.md) {
                FileTypeIcon(fileExtension: file.fileExtension)

                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text(file.fullFileName)
                        .font(.appBody)
                        .foregroundStyle(Color.appText)
                        .lineLimit(1)

                    HStack(spacing: AppSpacing.sm) {
                        Text(file.fileSize.formattedFileSize)
                            .font(.appCaption)
                            .foregroundStyle(Color.appTextDim)

                        Text(file.importedAt.relativeDisplay)
                            .font(.appCaption)
                            .foregroundStyle(Color.appTextDim)
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.appCaption)
                    .foregroundStyle(Color.appTextDim)
            }
        }
    }

    // MARK: - Contact Avatar

    private var contactAvatar: some View {
        Group {
            if let imageData = contact.thumbnailImageData, let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .clipShape(Circle())
            } else {
                ZStack {
                    Circle()
                        .fill(Color.appPrimary.opacity(0.15))

                    Text(contactInitials)
                        .font(.appH2)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.appPrimary)
                }
            }
        }
    }

    // MARK: - Computed Properties

    private var displayName: String {
        let full = "\(contact.givenName) \(contact.familyName)".trimmingCharacters(in: .whitespaces)
        return full.isEmpty ? contact.organizationName : full
    }

    private var contactInitials: String {
        let first = contact.givenName.prefix(1)
        let last = contact.familyName.prefix(1)
        let initials = "\(first)\(last)"
        return initials.isEmpty ? "?" : initials.uppercased()
    }

    /// Documents linked by identifier or containing contact info in OCR text
    private var linkedDocuments: [DocumentFile] {
        let identifier = contact.identifier
        let searchTerms = buildSearchTerms()

        return allFiles.filter { file in
            // Check explicit link via contactIdentifiers
            if let ids = file.contactIdentifiers {
                let linkedIDs = ids.split(separator: ",").map(String.init)
                if linkedIDs.contains(identifier) {
                    return true
                }
            }

            // Check OCR text for contact name, email, or phone
            guard let ocrText = file.ocrTextCache?.lowercased(), !ocrText.isEmpty else {
                return false
            }

            for term in searchTerms {
                if ocrText.contains(term.lowercased()) {
                    return true
                }
            }

            return false
        }
    }

    private func buildSearchTerms() -> [String] {
        var terms: [String] = []

        // Full name
        let fullName = "\(contact.givenName) \(contact.familyName)".trimmingCharacters(in: .whitespaces)
        if fullName.count > 2 {
            terms.append(fullName)
        }

        // Emails
        for email in contact.emailAddresses {
            terms.append(email.value as String)
        }

        // Phone numbers
        for phone in contact.phoneNumbers {
            let digits = phone.value.stringValue.filter { $0.isNumber }
            if digits.count >= 7 {
                terms.append(digits)
            }
        }

        return terms
    }
}
