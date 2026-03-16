import SwiftUI

struct FileActionsMenu: View {
    let file: DocumentFile
    let onAction: (FileRowAction) -> Void

    var body: some View {
        Menu {
            Button {
                onAction(.rename)
            } label: {
                Label("Rename", systemImage: "pencil")
            }

            Button {
                onAction(.toggleFavorite)
            } label: {
                Label(
                    file.isFavorite ? "Remove Favorite" : "Add to Favorites",
                    systemImage: file.isFavorite ? "star.slash" : "star"
                )
            }

            Button {
                onAction(.share)
            } label: {
                Label("Share", systemImage: "square.and.arrow.up")
            }

            Button {
                onAction(.info)
            } label: {
                Label("Info", systemImage: "info.circle")
            }

            Button {
                onAction(.moveToFolder)
            } label: {
                Label("Move to Folder", systemImage: "folder")
            }

            Button {
                onAction(.setExpiry)
            } label: {
                Label("Set Expiry", systemImage: "calendar.badge.clock")
            }

            Button {
                onAction(.extractData)
            } label: {
                Label("Extract Data", systemImage: "tablecells")
            }

            Button {
                onAction(.moveToVault)
            } label: {
                Label("Move to Vault", systemImage: "lock.shield")
            }

            Menu {
                ForEach(FileTag.allCases) { tag in
                    Button {
                        onAction(.setTag(tag))
                    } label: {
                        Label(tag.rawValue, systemImage: file.tagName == tag.rawValue ? "checkmark.circle.fill" : tag.icon)
                    }
                }
                if file.tagName != nil {
                    Divider()
                    Button {
                        onAction(.setTag(nil))
                    } label: {
                        Label("Remove Tag", systemImage: "xmark.circle")
                    }
                }
            } label: {
                Label("Tag", systemImage: "tag")
            }

            Divider()

            Button(role: .destructive) {
                onAction(.delete)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.appBody)
                .foregroundStyle(Color.appTextMuted)
                .frame(width: 44, height: 44)
        }
        .accessibilityLabel("File actions for \(file.fullFileName)")
        .accessibilityHint("Double tap for rename, share, delete, and more")
    }
}
