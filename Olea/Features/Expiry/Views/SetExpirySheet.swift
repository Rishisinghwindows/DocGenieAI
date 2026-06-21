import SwiftUI
import SwiftData

struct SetExpirySheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let file: DocumentFile

    @State private var expiryDate: Date
    @State private var reminderDays: Int
    @State private var expiryNote: String
    @State private var hasExpiry: Bool

    private let reminderOptions = [7, 14, 30, 60, 90]

    init(file: DocumentFile) {
        self.file = file
        _expiryDate = State(initialValue: file.expiryDate ?? Calendar.current.date(byAdding: .year, value: 1, to: .now)!)
        _reminderDays = State(initialValue: file.expiryReminderDays ?? 30)
        _expiryNote = State(initialValue: file.expiryNote ?? "")
        _hasExpiry = State(initialValue: file.expiryDate != nil)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: AppSpacing.md) {
                        FileTypeIcon(fileExtension: file.fileExtension)
                        VStack(alignment: .leading, spacing: AppSpacing.xs) {
                            Text(file.fullFileName)
                                .font(.appBody)
                                .foregroundStyle(Color.appText)
                                .lineLimit(1)
                            Text(file.fileSize.formattedFileSize)
                                .font(.appCaption)
                                .foregroundStyle(Color.appTextDim)
                        }
                    }
                    .listRowBackground(Color.appBGCard)
                }

                Section("Expiry Date") {
                    DatePicker(
                        "Expires on",
                        selection: $expiryDate,
                        displayedComponents: .date
                    )
                    .foregroundStyle(Color.appText)
                }
                .listRowBackground(Color.appBGCard)

                Section("Reminder") {
                    Picker("Remind me", selection: $reminderDays) {
                        ForEach(reminderOptions, id: \.self) { days in
                            Text("\(days) days before").tag(days)
                        }
                    }
                    .foregroundStyle(Color.appText)
                }
                .listRowBackground(Color.appBGCard)

                Section("Note") {
                    TextField("e.g. Passport expires", text: $expiryNote)
                        .foregroundStyle(Color.appText)
                }
                .listRowBackground(Color.appBGCard)

                if file.expiryDate != nil {
                    Section {
                        Button("Remove Expiry", role: .destructive) {
                            removeExpiry()
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                    }
                    .listRowBackground(Color.appBGCard)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.appBGDark)
            .navigationTitle("Set Expiry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Color.appTextMuted)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .foregroundStyle(Color.appPrimary)
                        .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func save() {
        file.expiryDate = expiryDate
        file.expiryReminderDays = reminderDays
        file.expiryNote = expiryNote.isEmpty ? nil : expiryNote
        try? modelContext.save()

        let service = ExpiryNotificationService.shared
        service.cancelReminder(for: file)
        service.scheduleReminder(for: file)

        HapticManager.success()
        dismiss()
    }

    private func removeExpiry() {
        file.expiryDate = nil
        file.expiryReminderDays = nil
        file.expiryNote = nil
        try? modelContext.save()

        ExpiryNotificationService.shared.cancelReminder(for: file)

        HapticManager.medium()
        dismiss()
    }
}
