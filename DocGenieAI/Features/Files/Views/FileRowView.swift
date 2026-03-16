import SwiftUI
import ImageIO

struct FileRowView: View {
    let file: DocumentFile
    let onAction: (FileRowAction) -> Void
    @State private var thumbnail: UIImage?

    var body: some View {
        HStack(spacing: AppSpacing.md) {
            if let thumbnail {
                Image(uiImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 40, height: 40)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .shadow(color: Color.appPrimary.opacity(0.15), radius: 4)
            } else {
                FileTypeIcon(fileExtension: file.fileExtension)
                    .shadow(color: Color.appPrimary.opacity(0.15), radius: 4)
            }

            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text(file.fullFileName)
                    .font(.appBody)
                    .foregroundStyle(Color.appText)
                    .lineLimit(1)

                HStack(spacing: AppSpacing.sm) {
                    if let pages = file.pageCount {
                        Text("\(pages) pages")
                            .font(.appCaption)
                            .foregroundStyle(Color.appTextDim)
                    }

                    Text(file.fileSize.formattedFileSize)
                        .font(.appCaption)
                        .foregroundStyle(Color.appTextDim)

                    Text(file.importedAt.relativeDisplay)
                        .font(.appCaption)
                        .foregroundStyle(Color.appTextDim)
                }
            }

            Spacer()

            if let tag = file.tag {
                Circle()
                    .fill(tag.color)
                    .frame(width: 8, height: 8)
            }

            if file.isFavorite {
                Image(systemName: "star.fill")
                    .font(.appCaption)
                    .foregroundStyle(Color.appWarning)
            }

            FileActionsMenu(file: file, onAction: onAction)
        }
        .padding(.vertical, AppSpacing.sm)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(file.fullFileName), \(file.fileSize.formattedFileSize)\(file.isFavorite ? ", favorited" : "")")
        .accessibilityHint("Double tap to open document")
        .task {
            let ext = file.fileExtension.lowercased()
            guard ext == "pdf" || ["jpg", "jpeg", "png", "heic"].contains(ext),
                  let url = file.fileURL else { return }
            if ext == "pdf" {
                thumbnail = ThumbnailService.shared.thumbnail(for: url)
            } else {
                // Downsample to thumbnail size instead of loading full image
                thumbnail = await Task.detached(priority: .utility) {
                    Self.downsampledThumbnail(from: url, maxPixelSize: 80)
                }.value
            }
        }
    }

    private nonisolated static func downsampledThumbnail(from url: URL, maxPixelSize: Int) -> UIImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
        ]
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}

enum FileRowAction {
    case rename
    case delete
    case share
    case info
    case toggleFavorite
    case setTag(FileTag?)
    case moveToFolder
    case setExpiry
    case extractData
    case moveToVault
}
