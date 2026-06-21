import SwiftUI

// MARK: - Text Annotation Model

struct TextAnnotation: Identifiable {
    let id = UUID()
    var text: String
    var page: Int
    var position: CGPoint  // Normalized 0-1 coordinates
    var color: Color
    var createdAt: Date = .now
}

// MARK: - Text Note Overlay

struct TextNoteOverlay: View {
    let notes: [TextAnnotation]
    let currentPage: Int
    let onTapNote: (TextAnnotation) -> Void
    let onDeleteNote: (TextAnnotation) -> Void

    private var currentPageNotes: [TextAnnotation] {
        notes.filter { $0.page == currentPage }
    }

    var body: some View {
        GeometryReader { geometry in
            ForEach(currentPageNotes) { note in
                noteIndicator(note)
                    .position(
                        x: note.position.x * geometry.size.width,
                        y: note.position.y * geometry.size.height
                    )
            }
        }
        .allowsHitTesting(true)
    }

    private func noteIndicator(_ note: TextAnnotation) -> some View {
        Image(systemName: "text.bubble.fill")
            .font(.system(size: 24))
            .foregroundStyle(note.color)
            .shadow(color: .black.opacity(0.3), radius: 3, y: 1)
            .onTapGesture {
                HapticManager.light()
                onTapNote(note)
            }
            .onLongPressGesture {
                HapticManager.medium()
                onDeleteNote(note)
            }
    }
}

// MARK: - Text Note Input Sheet

struct TextNoteInputSheet: View {
    @Binding var text: String
    let selectedColor: Color
    let onSave: () -> Void
    let onCancel: () -> Void

    @FocusState private var isFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: AppSpacing.md) {
                HStack(spacing: AppSpacing.sm) {
                    Image(systemName: "text.bubble.fill")
                        .foregroundStyle(selectedColor)
                        .font(.system(size: 20))
                    Text("Add Note")
                        .font(.appH3)
                        .foregroundStyle(Color.appText)
                    Spacer()
                }
                .padding(.horizontal, AppSpacing.md)
                .padding(.top, AppSpacing.md)

                TextEditor(text: $text)
                    .font(.appBody)
                    .foregroundStyle(Color.appText)
                    .scrollContentBackground(.hidden)
                    .padding(AppSpacing.sm)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.appBGCard)
                    )
                    .frame(minHeight: 120)
                    .padding(.horizontal, AppSpacing.md)
                    .focused($isFocused)

                Spacer()
            }
            .background(Color.appBGDark)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onCancel()
                    }
                    .foregroundStyle(Color.appTextMuted)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave()
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.appTextDim : Color.appPrimary)
                    .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear {
                isFocused = true
            }
        }
    }
}

// MARK: - Note Detail Popover

struct TextNoteDetailView: View {
    let note: TextAnnotation
    let onDelete: () -> Void

    private var formattedDate: String {
        note.createdAt.formatted(date: .abbreviated, time: .shortened)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack {
                Image(systemName: "text.bubble.fill")
                    .foregroundStyle(note.color)
                Text("Note")
                    .font(.appH3)
                    .foregroundStyle(Color.appText)
                Spacer()
                Button {
                    HapticManager.medium()
                    onDelete()
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.appDanger)
                }
            }

            Text(note.text)
                .font(.appBody)
                .foregroundStyle(Color.appText)
                .fixedSize(horizontal: false, vertical: true)

            Text(formattedDate)
                .font(.appMicro)
                .foregroundStyle(Color.appTextDim)
        }
        .padding(AppSpacing.md)
        .frame(minWidth: 200, maxWidth: 280)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.appBGCard)
                .shadow(color: .black.opacity(0.2), radius: 8)
        )
    }
}

// MARK: - Notes List Sheet

struct TextNotesListView: View {
    let notes: [TextAnnotation]
    let currentPage: Int
    let onDelete: (TextAnnotation) -> Void
    @Environment(\.dismiss) private var dismiss

    private var currentPageNotes: [TextAnnotation] {
        notes.filter { $0.page == currentPage }
    }

    private var otherNotes: [TextAnnotation] {
        notes.filter { $0.page != currentPage }
    }

    var body: some View {
        NavigationStack {
            List {
                if !currentPageNotes.isEmpty {
                    Section("Page \(currentPage)") {
                        ForEach(currentPageNotes) { note in
                            noteRow(note)
                        }
                    }
                }

                if !otherNotes.isEmpty {
                    Section("Other Pages") {
                        ForEach(otherNotes) { note in
                            noteRow(note)
                        }
                    }
                }

                if notes.isEmpty {
                    Section {
                        HStack {
                            Spacer()
                            VStack(spacing: AppSpacing.sm) {
                                Image(systemName: "text.bubble")
                                    .font(.system(size: 32))
                                    .foregroundStyle(Color.appTextDim)
                                Text("No notes yet")
                                    .font(.appBody)
                                    .foregroundStyle(Color.appTextMuted)
                                Text("Select the note tool and tap on the PDF to add one.")
                                    .font(.appCaption)
                                    .foregroundStyle(Color.appTextDim)
                                    .multilineTextAlignment(.center)
                            }
                            .padding(.vertical, AppSpacing.lg)
                            Spacer()
                        }
                    }
                    .listRowBackground(Color.clear)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.appBGDark)
            .navigationTitle("Notes (\(notes.count))")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(Color.appPrimary)
                }
            }
        }
    }

    private func noteRow(_ note: TextAnnotation) -> some View {
        HStack(spacing: AppSpacing.sm) {
            Image(systemName: "text.bubble.fill")
                .foregroundStyle(note.color)
                .font(.system(size: 16))

            VStack(alignment: .leading, spacing: 2) {
                Text(note.text)
                    .font(.appBody)
                    .foregroundStyle(Color.appText)
                    .lineLimit(2)

                HStack(spacing: AppSpacing.xs) {
                    Text("Page \(note.page)")
                        .font(.appMicro)
                        .foregroundStyle(Color.appTextDim)
                    Text("·")
                        .foregroundStyle(Color.appTextDim)
                    Text(note.createdAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.appMicro)
                        .foregroundStyle(Color.appTextDim)
                }
            }

            Spacer()

            Button {
                HapticManager.medium()
                onDelete(note)
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.appDanger)
            }
        }
        .listRowBackground(Color.appBGCard)
    }
}
