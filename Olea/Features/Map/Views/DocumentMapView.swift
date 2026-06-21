import SwiftUI
import MapKit
import SwiftData

struct DocumentMapView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \DocumentFile.importedAt, order: .reverse) private var allFiles: [DocumentFile]
    @State private var selectedFile: DocumentFile?
    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var navigateToFile: DocumentFile?

    private var geoFiles: [DocumentFile] {
        allFiles.filter { $0.latitude != nil && $0.longitude != nil && !$0.isInVault }
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                Map(position: $cameraPosition, selection: $selectedFile) {
                    ForEach(geoFiles) { file in
                        Marker(
                            file.name,
                            systemImage: fileIcon(for: file.fileExtension),
                            coordinate: CLLocationCoordinate2D(
                                latitude: file.latitude ?? 0,
                                longitude: file.longitude ?? 0
                            )
                        )
                        .tint(markerColor(for: file))
                        .tag(file)
                    }
                }
                .mapStyle(.standard(elevation: .realistic))
                .mapControls {
                    MapUserLocationButton()
                    MapCompass()
                    MapScaleView()
                }

                if let file = selectedFile {
                    selectedFileCard(file)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .padding(.horizontal, AppSpacing.md)
                        .padding(.bottom, AppSpacing.md)
                }
            }
            .animation(.easeInOut(duration: 0.25), value: selectedFile?.id)
            .navigationTitle("Document Map")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") {
                        HapticManager.light()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Text("\(geoFiles.count) locations")
                        .font(.appCaption)
                        .foregroundStyle(Color.appTextMuted)
                }
            }
            .overlay {
                if geoFiles.isEmpty {
                    EmptyStateView(
                        icon: "map",
                        title: "No Locations Yet",
                        message: "Scan or import documents to see them on the map. Location is captured automatically."
                    )
                }
            }
            .navigationDestination(item: $navigateToFile) { file in
                DocumentViewerRouter(file: file)
            }
        }
    }

    // MARK: - Selected File Card

    private func selectedFileCard(_ file: DocumentFile) -> some View {
        AppCard(style: .glass) {
            HStack(spacing: AppSpacing.md) {
                FileTypeIcon(fileExtension: file.fileExtension, size: 44)

                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text(file.name)
                        .font(.appBody)
                        .foregroundStyle(Color.appText)
                        .lineLimit(1)

                    if let locationName = file.locationName {
                        HStack(spacing: 4) {
                            Image(systemName: "mappin.circle.fill")
                                .font(.system(size: 11))
                                .foregroundStyle(Color.appPrimary)
                            Text(locationName)
                                .font(.appCaption)
                                .foregroundStyle(Color.appTextMuted)
                                .lineLimit(1)
                        }
                    }

                    HStack(spacing: AppSpacing.sm) {
                        Text(file.importedAt.formatted(date: .abbreviated, time: .shortened))
                            .font(.appMicro)
                            .foregroundStyle(Color.appTextDim)

                        Text(formattedSize(file.fileSize))
                            .font(.appMicro)
                            .foregroundStyle(Color.appTextDim)

                        if let tag = file.tag {
                            HStack(spacing: 3) {
                                Circle()
                                    .fill(tag.color)
                                    .frame(width: 6, height: 6)
                                Text(tag.rawValue)
                                    .font(.appMicro)
                                    .foregroundStyle(tag.color)
                            }
                        }
                    }
                }

                Spacer(minLength: 0)

                Button {
                    HapticManager.light()
                    file.lastOpenedAt = Date()
                    try? modelContext.save()
                    navigateToFile = file
                } label: {
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(Color.appPrimary)
                        .symbolRenderingMode(.hierarchical)
                }
            }
        }
    }

    // MARK: - Helpers

    private func fileIcon(for ext: String) -> String {
        switch ext.lowercased() {
        case "pdf": return "doc.fill"
        case "jpg", "jpeg", "png", "heic", "webp", "bmp", "gif", "tiff": return "photo"
        case "doc", "docx": return "doc.text.fill"
        case "xls", "xlsx": return "tablecells.fill"
        case "ppt", "pptx": return "play.rectangle.fill"
        default: return "doc.text.fill"
        }
    }

    private func markerColor(for file: DocumentFile) -> Color {
        if let tagName = file.tagName, let tag = FileTag(rawValue: tagName) {
            return tag.color
        }
        return .appPrimary
    }

    private func formattedSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}
