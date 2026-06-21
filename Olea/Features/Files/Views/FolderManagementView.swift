import SwiftUI
import SwiftData

struct FolderManagementView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \DocumentFolder.createdAt, order: .reverse) private var folders: [DocumentFolder]

    @State private var showCreateDialog = false
    @State private var newFolderName = ""
    @State private var selectedColorHex = "#6366F1"
    @State private var selectedIcon = "folder.fill"
    @State private var editingFolder: DocumentFolder?
    @State private var editName = ""

    var body: some View {
        NavigationStack {
            Group {
                if folders.isEmpty && !showCreateDialog {
                    EmptyStateView(
                        icon: "folder.badge.plus",
                        title: "No Folders Yet",
                        message: "Create folders to organize your documents.",
                        buttonTitle: "Create Folder",
                        action: { showCreateDialog = true }
                    )
                } else {
                    List {
                        ForEach(folders) { folder in
                            HStack(spacing: AppSpacing.md) {
                                Circle()
                                    .fill(folder.color)
                                    .frame(width: 12, height: 12)

                                Image(systemName: folder.iconName)
                                    .font(.appBody)
                                    .foregroundStyle(folder.color)
                                    .frame(width: 24)

                                Text(folder.name)
                                    .font(.appBody)
                                    .foregroundStyle(Color.appText)
                                    .lineLimit(1)

                                Spacer()

                                Text(folder.createdAt.relativeDisplay)
                                    .font(.appCaption)
                                    .foregroundStyle(Color.appTextDim)
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                HapticManager.selection()
                                editingFolder = folder
                                editName = folder.name
                            }
                            .listRowBackground(Color.appBGCard)
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    deleteFolder(folder)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                            .contextMenu {
                                Button {
                                    editingFolder = folder
                                    editName = folder.name
                                } label: {
                                    Label("Rename", systemImage: "pencil")
                                }
                                Button(role: .destructive) {
                                    deleteFolder(folder)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                    .scrollContentBackground(.hidden)
                }
            }
            .background(Color.appBGDark)
            .navigationTitle("Folders")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(Color.appPrimary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        HapticManager.light()
                        resetCreateForm()
                        showCreateDialog = true
                    } label: {
                        Image(systemName: "plus")
                            .foregroundStyle(Color.appPrimary)
                    }
                }
            }
            .alert("New Folder", isPresented: $showCreateDialog) {
                TextField("Folder name", text: $newFolderName)
                Button("Cancel", role: .cancel) {}
                Button("Create") { createFolder() }
                    .disabled(newFolderName.trimmingCharacters(in: .whitespaces).isEmpty)
            } message: {
                Text("Enter a name for the new folder.")
            }
            .alert("Rename Folder", isPresented: Binding(
                get: { editingFolder != nil },
                set: { if !$0 { editingFolder = nil } }
            )) {
                TextField("Folder name", text: $editName)
                Button("Cancel", role: .cancel) { editingFolder = nil }
                Button("Save") { renameFolder() }
                    .disabled(editName.trimmingCharacters(in: .whitespaces).isEmpty)
            } message: {
                Text("Enter a new name for this folder.")
            }
        }
    }

    private func resetCreateForm() {
        newFolderName = ""
        selectedColorHex = "#6366F1"
        selectedIcon = "folder.fill"
    }

    private func createFolder() {
        let trimmed = newFolderName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        let folder = DocumentFolder(name: trimmed, colorHex: selectedColorHex, iconName: selectedIcon)
        modelContext.insert(folder)
        try? modelContext.save()
        HapticManager.success()
        resetCreateForm()
    }

    private func renameFolder() {
        guard let folder = editingFolder else { return }
        let trimmed = editName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        folder.name = trimmed
        try? modelContext.save()
        HapticManager.success()
        editingFolder = nil
    }

    private func deleteFolder(_ folder: DocumentFolder) {
        modelContext.delete(folder)
        try? modelContext.save()
        HapticManager.medium()
    }
}
