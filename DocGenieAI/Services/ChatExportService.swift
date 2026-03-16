import UIKit
import PDFKit

@MainActor
final class ChatExportService {
    static let shared = ChatExportService()

    private init() {}

    func exportConversation(_ conversation: Conversation, messages: [ChatMessage]) -> URL? {
        let pageRect = CGRect(x: 0, y: 0, width: 612, height: 792)
        let margin: CGFloat = 50
        let contentWidth = pageRect.width - margin * 2

        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)

        let data = renderer.pdfData { context in
            var currentY: CGFloat = 0

            func newPage() {
                context.beginPage()
                currentY = margin
            }

            func ensureSpace(_ needed: CGFloat) {
                if currentY + needed > pageRect.height - margin {
                    newPage()
                }
            }

            newPage()

            // Header
            let titleAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 18),
                .foregroundColor: UIColor.darkGray
            ]
            ("DocSage Chat Export" as NSString).draw(at: CGPoint(x: margin, y: currentY), withAttributes: titleAttrs)
            currentY += 26

            let subAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 12),
                .foregroundColor: UIColor.gray
            ]
            (conversation.title as NSString).draw(at: CGPoint(x: margin, y: currentY), withAttributes: subAttrs)
            currentY += 18

            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .long
            dateFormatter.timeStyle = .short
            ("Exported: \(dateFormatter.string(from: Date()))" as NSString).draw(at: CGPoint(x: margin, y: currentY), withAttributes: subAttrs)
            currentY += 28

            // Separator
            context.cgContext.setStrokeColor(UIColor.lightGray.cgColor)
            context.cgContext.setLineWidth(0.5)
            context.cgContext.move(to: CGPoint(x: margin, y: currentY))
            context.cgContext.addLine(to: CGPoint(x: pageRect.width - margin, y: currentY))
            context.cgContext.strokePath()
            currentY += 16

            // Messages
            let sortedMessages = messages.sorted { $0.timestamp < $1.timestamp }
                .filter { $0.messageType != "processing" }

            for message in sortedMessages {
                let isUser = message.role == "user"

                // Role + time
                let roleAttrs: [NSAttributedString.Key: Any] = [
                    .font: UIFont.boldSystemFont(ofSize: 11),
                    .foregroundColor: isUser ? UIColor.systemBlue : UIColor.systemIndigo
                ]
                let timeAttrs: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 9),
                    .foregroundColor: UIColor.lightGray
                ]

                ensureSpace(40)
                let roleLabel = isUser ? "You" : "DocSage"
                (roleLabel as NSString).draw(at: CGPoint(x: margin, y: currentY), withAttributes: roleAttrs)

                let timeStr = message.timestamp.formatted(.dateTime.hour().minute())
                let timeSize = (timeStr as NSString).size(withAttributes: timeAttrs)
                (timeStr as NSString).draw(at: CGPoint(x: pageRect.width - margin - timeSize.width, y: currentY + 1), withAttributes: timeAttrs)
                currentY += 16

                // Content
                let contentAttrs: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 11),
                    .foregroundColor: UIColor.black,
                    .paragraphStyle: {
                        let p = NSMutableParagraphStyle()
                        p.lineSpacing = 3
                        return p
                    }()
                ]

                let attrStr = NSAttributedString(string: message.content, attributes: contentAttrs)
                let framesetter = CTFramesetterCreateWithAttributedString(attrStr)
                let suggestedSize = CTFramesetterSuggestFrameSizeWithConstraints(
                    framesetter, CFRangeMake(0, attrStr.length), nil,
                    CGSize(width: contentWidth, height: .greatestFiniteMagnitude), nil
                )

                ensureSpace(suggestedSize.height + 12)

                let path = CGPath(rect: CGRect(x: margin, y: 0, width: contentWidth, height: suggestedSize.height), transform: nil)
                let ctx = context.cgContext
                ctx.saveGState()
                ctx.translateBy(x: 0, y: currentY + suggestedSize.height)
                ctx.scaleBy(x: 1, y: -1)
                let frame = CTFramesetterCreateFrame(framesetter, CFRangeMake(0, attrStr.length), path, nil)
                CTFrameDraw(frame, ctx)
                ctx.restoreGState()

                currentY += suggestedSize.height + 14
            }
        }

        let safeName = conversation.title
            .replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: "/", with: "-")
            .prefix(20)
        let fileName = "DocSage_\(safeName).pdf"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        do {
            try data.write(to: tempURL)
            return tempURL
        } catch {
            return nil
        }
    }
}
