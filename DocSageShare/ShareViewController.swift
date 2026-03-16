import UIKit
import UniformTypeIdentifiers

class ShareViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.systemBackground
        handleSharedItems()
    }

    private func handleSharedItems() {
        guard let extensionItems = extensionContext?.inputItems as? [NSExtensionItem] else {
            close()
            return
        }

        let group = DispatchGroup()
        var savedCount = 0

        for item in extensionItems {
            guard let attachments = item.attachments else { continue }
            for provider in attachments {
                group.enter()

                // Handle PDFs
                if provider.hasItemConformingToTypeIdentifier(UTType.pdf.identifier) {
                    provider.loadItem(forTypeIdentifier: UTType.pdf.identifier, options: nil) { [weak self] data, error in
                        defer { group.leave() }
                        if let url = data as? URL {
                            self?.saveFile(from: url)
                            savedCount += 1
                        } else if let data = data as? Data {
                            self?.saveData(data, extension: "pdf")
                            savedCount += 1
                        }
                    }
                }
                // Handle images
                else if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                    provider.loadItem(forTypeIdentifier: UTType.image.identifier, options: nil) { [weak self] data, error in
                        defer { group.leave() }
                        if let url = data as? URL {
                            self?.saveFile(from: url)
                            savedCount += 1
                        } else if let image = data as? UIImage, let jpegData = image.jpegData(compressionQuality: 0.9) {
                            self?.saveData(jpegData, extension: "jpg")
                            savedCount += 1
                        }
                    }
                }
                // Handle URLs (save as text file)
                else if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                    provider.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) { [weak self] data, error in
                        defer { group.leave() }
                        if let url = data as? URL, !url.isFileURL {
                            // Save URL reference as a text file
                            self?.saveData(url.absoluteString.data(using: .utf8) ?? Data(), extension: "txt", name: "Web Link")
                            savedCount += 1
                        }
                    }
                }
                // Handle plain text
                else if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                    provider.loadItem(forTypeIdentifier: UTType.plainText.identifier, options: nil) { [weak self] data, error in
                        defer { group.leave() }
                        if let text = data as? String {
                            self?.saveData(text.data(using: .utf8) ?? Data(), extension: "txt", name: "Shared Text")
                            savedCount += 1
                        }
                    }
                }
                // Handle generic files
                else if provider.hasItemConformingToTypeIdentifier(UTType.data.identifier) {
                    provider.loadItem(forTypeIdentifier: UTType.data.identifier, options: nil) { [weak self] data, error in
                        defer { group.leave() }
                        if let url = data as? URL {
                            self?.saveFile(from: url)
                            savedCount += 1
                        }
                    }
                } else {
                    group.leave()
                }
            }
        }

        group.notify(queue: .main) { [weak self] in
            // Signal main app to import from shared container on next launch
            if savedCount > 0 {
                UserDefaults(suiteName: "group.com.docgenieai.shared")?.set(true, forKey: "hasNewSharedFiles")
                UserDefaults(suiteName: "group.com.docgenieai.shared")?.set(savedCount, forKey: "sharedFileCount")
            }
            self?.close()
        }
    }

    private func saveFile(from sourceURL: URL) {
        let accessing = sourceURL.startAccessingSecurityScopedResource()
        defer { if accessing { sourceURL.stopAccessingSecurityScopedResource() } }

        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.docgenieai.shared") else { return }
        let sharedDir = containerURL.appendingPathComponent("SharedFiles")
        try? FileManager.default.createDirectory(at: sharedDir, withIntermediateDirectories: true)

        let fileName = sourceURL.lastPathComponent
        var destURL = sharedDir.appendingPathComponent(fileName)
        var counter = 1
        while FileManager.default.fileExists(atPath: destURL.path) {
            let name = (fileName as NSString).deletingPathExtension
            let ext = (fileName as NSString).pathExtension
            destURL = sharedDir.appendingPathComponent("\(name) (\(counter)).\(ext)")
            counter += 1
        }

        try? FileManager.default.copyItem(at: sourceURL, to: destURL)
    }

    private func saveData(_ data: Data, extension ext: String, name: String? = nil) {
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.docgenieai.shared") else { return }
        let sharedDir = containerURL.appendingPathComponent("SharedFiles")
        try? FileManager.default.createDirectory(at: sharedDir, withIntermediateDirectories: true)

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HHmmss"
        let baseName = name ?? "Shared_\(formatter.string(from: Date()))"
        let destURL = sharedDir.appendingPathComponent("\(baseName).\(ext)")
        try? data.write(to: destURL)
    }

    private func close() {
        extensionContext?.completeRequest(returningItems: nil)
    }
}
