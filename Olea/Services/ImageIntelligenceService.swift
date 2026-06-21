import Vision
import UIKit
import CoreImage
import CoreImage.CIFilterBuiltins

final class ImageIntelligenceService: Sendable {
    static let shared = ImageIntelligenceService()
    private let ciContext = CIContext(options: [.useSoftwareRenderer: false])
    private init() {}

    // MARK: - Classification

    func classifyImage(at url: URL) async -> [String] {
        guard let cgImage = loadCGImage(from: url) else { return [] }
        let request = VNClassifyImageRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        do {
            try handler.perform([request])
            let observations = (request.results as? [VNClassificationObservation]) ?? []
            return observations
                .filter { $0.confidence > 0.3 }
                .sorted { $0.confidence > $1.confidence }
                .prefix(5)
                .map { $0.identifier }
        } catch {
            return []
        }
    }

    // MARK: - Document Detection

    func isDocument(at url: URL) async -> Bool {
        guard let cgImage = loadCGImage(from: url) else { return false }
        let request = VNDetectDocumentSegmentationRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        do {
            try handler.perform([request])
            if let result = (request.results as? [VNRectangleObservation])?.first {
                let area = result.boundingBox.width * result.boundingBox.height
                return area > 0.15
            }
            return false
        } catch {
            return false
        }
    }

    // MARK: - Face Detection

    func detectFaces(at url: URL) async -> Int {
        guard let cgImage = loadCGImage(from: url) else { return 0 }
        let request = VNDetectFaceRectanglesRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        do {
            try handler.perform([request])
            return (request.results as? [VNFaceObservation])?.count ?? 0
        } catch {
            return 0
        }
    }

    // MARK: - Smart Crop

    func smartCropRect(for image: UIImage, targetSize: CGSize) async -> CGRect {
        guard let cgImage = image.cgImage else {
            return CGRect(origin: .zero, size: targetSize)
        }
        let imageSize = CGSize(width: cgImage.width, height: cgImage.height)

        let request = VNGenerateAttentionBasedSaliencyImageRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        do {
            try handler.perform([request])
            guard let result = (request.results as? [VNSaliencyImageObservation])?.first,
                  let salientObject = result.salientObjects?.max(by: { $0.confidence < $1.confidence }) else {
                return centerCropRect(imageSize: imageSize, targetSize: targetSize)
            }

            let bbox = salientObject.boundingBox
            let centerX = bbox.midX * imageSize.width
            let centerY = (1.0 - bbox.midY) * imageSize.height

            let aspectRatio = targetSize.width / targetSize.height
            var cropWidth = imageSize.width
            var cropHeight = cropWidth / aspectRatio
            if cropHeight > imageSize.height {
                cropHeight = imageSize.height
                cropWidth = cropHeight * aspectRatio
            }

            var originX = centerX - cropWidth / 2
            var originY = centerY - cropHeight / 2
            originX = max(0, min(originX, imageSize.width - cropWidth))
            originY = max(0, min(originY, imageSize.height - cropHeight))

            return CGRect(x: originX, y: originY, width: cropWidth, height: cropHeight)
        } catch {
            return centerCropRect(imageSize: imageSize, targetSize: targetSize)
        }
    }

    // MARK: - Background Removal

    func removeBackground(from image: UIImage) async -> UIImage? {
        guard let cgImage = image.cgImage else { return nil }

        let request = VNGeneratePersonSegmentationRequest()
        request.qualityLevel = .accurate
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        do {
            try handler.perform([request])
            guard let result = (request.results as? [VNPixelBufferObservation])?.first else { return nil }

            let maskPixelBuffer = result.pixelBuffer
            let maskCIImage = CIImage(cvPixelBuffer: maskPixelBuffer)
            let originalCIImage = CIImage(cgImage: cgImage)

            let scaleX = originalCIImage.extent.width / maskCIImage.extent.width
            let scaleY = originalCIImage.extent.height / maskCIImage.extent.height
            let scaledMask = maskCIImage.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))

            let backgroundCIImage = CIImage(color: CIColor.clear).cropped(to: originalCIImage.extent)

            let blendFilter = CIFilter.blendWithMask()
            blendFilter.inputImage = originalCIImage
            blendFilter.backgroundImage = backgroundCIImage
            blendFilter.maskImage = scaledMask

            guard let outputCIImage = blendFilter.outputImage,
                  let outputCGImage = ciContext.createCGImage(outputCIImage, from: outputCIImage.extent) else {
                return nil
            }

            return UIImage(cgImage: outputCGImage, scale: image.scale, orientation: image.imageOrientation)
        } catch {
            return nil
        }
    }

    // MARK: - Auto Enhance

    func autoEnhance(image: UIImage) -> UIImage? {
        guard let ciImage = CIImage(image: image) else { return nil }

        let adjustments = ciImage.autoAdjustmentFilters()
        var currentImage = ciImage
        for filter in adjustments {
            filter.setValue(currentImage, forKey: kCIInputImageKey)
            if let output = filter.outputImage {
                currentImage = output
            }
        }

        guard let cgImage = ciContext.createCGImage(currentImage, from: currentImage.extent) else { return nil }
        return UIImage(cgImage: cgImage, scale: image.scale, orientation: image.imageOrientation)
    }

    // MARK: - Document Enhancement

    func enhanceDocument(image: UIImage) async -> UIImage? {
        guard let cgImage = image.cgImage else { return nil }
        let ciImage = CIImage(cgImage: cgImage)

        // Step 1: Detect document rectangle for perspective correction
        var correctedImage = ciImage
        let docRequest = VNDetectDocumentSegmentationRequest()
        let docHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        if let _ = try? docHandler.perform([docRequest]),
           let result = docRequest.results?.first as? VNRectangleObservation {
            let imageWidth = ciImage.extent.width
            let imageHeight = ciImage.extent.height

            let topLeft = CGPoint(x: result.topLeft.x * imageWidth, y: result.topLeft.y * imageHeight)
            let topRight = CGPoint(x: result.topRight.x * imageWidth, y: result.topRight.y * imageHeight)
            let bottomLeft = CGPoint(x: result.bottomLeft.x * imageWidth, y: result.bottomLeft.y * imageHeight)
            let bottomRight = CGPoint(x: result.bottomRight.x * imageWidth, y: result.bottomRight.y * imageHeight)

            let perspectiveFilter = CIFilter.perspectiveCorrection()
            perspectiveFilter.inputImage = ciImage
            perspectiveFilter.topLeft = topLeft
            perspectiveFilter.topRight = topRight
            perspectiveFilter.bottomLeft = bottomLeft
            perspectiveFilter.bottomRight = bottomRight

            if let output = perspectiveFilter.outputImage {
                correctedImage = output
            }
        }

        // Step 2: Increase contrast
        let contrastFilter = CIFilter.colorControls()
        contrastFilter.inputImage = correctedImage
        contrastFilter.contrast = 1.3
        contrastFilter.brightness = 0.02
        contrastFilter.saturation = 0.0
        guard let contrasted = contrastFilter.outputImage else { return nil }

        // Step 3: Sharpen for crisp text
        let sharpenFilter = CIFilter.sharpenLuminance()
        sharpenFilter.inputImage = contrasted
        sharpenFilter.sharpness = 0.6
        sharpenFilter.radius = 1.5
        guard let sharpened = sharpenFilter.outputImage else { return nil }

        guard let outputCGImage = ciContext.createCGImage(sharpened, from: sharpened.extent) else { return nil }
        return UIImage(cgImage: outputCGImage, scale: image.scale, orientation: image.imageOrientation)
    }

    // MARK: - AI Description

    func describeImage(at url: URL) async -> String {
        async let classifications = classifyImage(at: url)
        async let faceCount = detectFaces(at: url)
        async let ocrText = extractText(at: url)

        let labels = await classifications
        let faces = await faceCount
        let text = await ocrText

        var parts: [String] = []

        if !labels.isEmpty {
            let labelString = labels.prefix(3).joined(separator: ", ")
            parts.append("An image containing: \(labelString)")
        } else {
            parts.append("An image")
        }

        if faces == 1 {
            parts.append("with 1 person")
        } else if faces > 1 {
            parts.append("with \(faces) people")
        } else {
            parts.append("no people")
        }

        if !text.isEmpty {
            let preview = String(text.prefix(80)).replacingOccurrences(of: "\n", with: " ")
            parts.append("containing text: \"\(preview)\"")
        }

        return parts.joined(separator: ", ")
    }

    // MARK: - Helpers

    private func loadCGImage(from url: URL) -> CGImage? {
        guard let data = try? Data(contentsOf: url),
              let uiImage = UIImage(data: data) else { return nil }
        return uiImage.cgImage
    }

    private func centerCropRect(imageSize: CGSize, targetSize: CGSize) -> CGRect {
        let aspectRatio = targetSize.width / targetSize.height
        var cropWidth = imageSize.width
        var cropHeight = cropWidth / aspectRatio
        if cropHeight > imageSize.height {
            cropHeight = imageSize.height
            cropWidth = cropHeight * aspectRatio
        }
        let originX = (imageSize.width - cropWidth) / 2
        let originY = (imageSize.height - cropHeight) / 2
        return CGRect(x: originX, y: originY, width: cropWidth, height: cropHeight)
    }

    private func extractText(at url: URL) async -> String {
        guard let cgImage = loadCGImage(from: url) else { return "" }
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .fast
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        do {
            try handler.perform([request])
            let observations = (request.results as? [VNRecognizedTextObservation]) ?? []
            return observations
                .compactMap { $0.topCandidates(1).first?.string }
                .joined(separator: "\n")
        } catch {
            return ""
        }
    }
}
