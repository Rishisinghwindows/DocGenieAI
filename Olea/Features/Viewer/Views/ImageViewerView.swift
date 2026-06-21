import SwiftUI
import ImageIO

struct ImageViewerView: View {
    let url: URL
    let fileName: String
    @State private var uiImage: UIImage?
    @State private var isLoading = true
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    var body: some View {
        GeometryReader { geo in
            if isLoading {
                ProgressView("Loading...")
                    .frame(width: geo.size.width, height: geo.size.height)
            } else if let uiImage {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .scaleEffect(scale)
                    .offset(offset)
                    .gesture(
                        MagnifyGesture()
                            .onChanged { value in
                                scale = lastScale * value.magnification
                            }
                            .onEnded { _ in
                                lastScale = max(1.0, scale)
                                scale = lastScale
                                if scale <= 1.0 {
                                    withAnimation {
                                        offset = .zero
                                        lastOffset = .zero
                                    }
                                }
                            }
                    )
                    .simultaneousGesture(
                        DragGesture()
                            .onChanged { value in
                                guard scale > 1.0 else { return }
                                offset = CGSize(
                                    width: lastOffset.width + value.translation.width,
                                    height: lastOffset.height + value.translation.height
                                )
                            }
                            .onEnded { _ in
                                lastOffset = offset
                            }
                    )
                    .onTapGesture(count: 2) {
                        withAnimation {
                            if scale > 1.0 {
                                scale = 1.0
                                lastScale = 1.0
                                offset = .zero
                                lastOffset = .zero
                            } else {
                                scale = 3.0
                                lastScale = 3.0
                            }
                        }
                    }
                    .frame(width: geo.size.width, height: geo.size.height)
            } else {
                EmptyStateView(
                    icon: "photo.badge.exclamationmark",
                    title: "Cannot Load Image",
                    message: "The image file could not be loaded."
                )
            }
        }
        .background(Color.appBGDark)
        .navigationTitle(fileName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                // Zoom indicator
                if scale > 1.0 {
                    Text("\(Int(scale * 100))%")
                        .font(.appMono)
                        .fontWeight(.medium)
                        .foregroundStyle(Color.appTextDim)
                }

                // Share
                Button {
                    ShareService.shared.share(fileURL: url)
                } label: {
                    Image(systemName: "square.and.arrow.up")
                        .foregroundStyle(Color.appTextMuted)
                }
            }
        }
        .task {
            let loadedImage = await Task.detached(priority: .userInitiated) {
                Self.loadImage(from: url)
            }.value
            uiImage = loadedImage
            isLoading = false
        }
    }

    private nonisolated static func loadImage(from url: URL) -> UIImage? {
        // Use CGImageSource for efficient loading with downsampling for very large images
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else {
            return nil
        }

        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: 4096
        ]

        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return UIImage(contentsOfFile: url.path)
        }

        return UIImage(cgImage: cgImage)
    }
}
