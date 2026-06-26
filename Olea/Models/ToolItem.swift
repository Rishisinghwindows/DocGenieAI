import SwiftUI

enum ToolItem: String, CaseIterable, Identifiable {
    // Scanner
    case scanner = "Scanner"
    // PDF Tools
    case mergePDF = "Merge PDF"
    case splitPDF = "Split PDF"
    case compressPDF = "Compress"
    case lockPDF = "Lock PDF"
    case unlockPDF = "Unlock PDF"
    case extractPages = "Extract Pages"
    case rotatePDF = "Rotate PDF"
    case reorderPDF = "Reorder Pages"
    case pageNumbers = "Page Numbers"
    case watermark = "Watermark"
    case batchProcess = "Batch Process"
    case ocrText = "OCR Text"
    case comparePDF = "Compare PDFs"
    case signPDF = "Sign PDF"
    case cropPDF = "Crop PDF"
    case metadataEditor = "PDF Metadata"
    case redactPDF = "Redact PDF"
    // Converters
    case imageToPDF = "Image to PDF"
    case docToPDF = "Doc to PDF"
    case pdfToImage = "PDF to Image"
    case pdfToText = "PDF to Text"
    // AI Tools
    case summarizePDF = "Summarize PDF"
    case askPDF = "Ask PDF"
    case translatePDF = "Translate PDF"
    case handwriting = "Handwriting"
    case formAutofill = "Smart Form Fill"
    // Utilities
    case templates = "Templates"
    case emailPDF = "Email PDF"
    case qrShare = "QR Share"

    var id: String { rawValue }

    /// Localized display name. Falls back to the English raw value when no
    /// translation is found, so we never show a missing-key marker. The
    /// rawValue stays the canonical English string — it's used for storage
    /// (e.g. ToolItem(rawValue:) round-trips) and search, neither of which
    /// should be locale-sensitive.
    var localizedName: String {
        switch self {
        case .scanner: return String(localized: "Scanner")
        case .mergePDF: return String(localized: "Merge PDF")
        case .splitPDF: return String(localized: "Split PDF")
        case .compressPDF: return String(localized: "Compress")
        case .lockPDF: return String(localized: "Lock PDF")
        case .unlockPDF: return String(localized: "Unlock PDF")
        case .extractPages: return String(localized: "Extract Pages")
        case .rotatePDF: return String(localized: "Rotate PDF")
        case .reorderPDF: return String(localized: "Reorder Pages")
        case .pageNumbers: return String(localized: "Page Numbers")
        case .watermark: return String(localized: "Watermark")
        case .batchProcess: return String(localized: "Batch Process")
        case .ocrText: return String(localized: "OCR Text")
        case .comparePDF: return String(localized: "Compare PDFs")
        case .signPDF: return String(localized: "Sign PDF")
        case .cropPDF: return String(localized: "Crop PDF")
        case .metadataEditor: return String(localized: "PDF Metadata")
        case .redactPDF: return String(localized: "Redact PDF")
        case .imageToPDF: return String(localized: "Image to PDF")
        case .docToPDF: return String(localized: "Doc to PDF")
        case .pdfToImage: return String(localized: "PDF to Image")
        case .pdfToText: return String(localized: "PDF to Text")
        case .summarizePDF: return String(localized: "Summarize PDF")
        case .askPDF: return String(localized: "Ask PDF")
        case .translatePDF: return String(localized: "Translate PDF")
        case .handwriting: return String(localized: "Handwriting")
        case .formAutofill: return String(localized: "Smart Form Fill")
        case .templates: return String(localized: "Templates")
        case .emailPDF: return String(localized: "Email PDF")
        case .qrShare: return String(localized: "QR Share")
        }
    }

    var systemImage: String {
        switch self {
        case .scanner: return "doc.viewfinder"
        case .mergePDF: return "doc.on.doc.fill"
        case .splitPDF: return "scissors"
        case .compressPDF: return "arrow.down.doc"
        case .lockPDF: return "lock.doc"
        case .unlockPDF: return "lock.open"
        case .extractPages: return "doc.badge.plus"
        case .rotatePDF: return "rotate.right"
        case .reorderPDF: return "arrow.up.arrow.down.square"
        case .pageNumbers: return "number.square"
        case .watermark: return "drop.triangle"
        case .batchProcess: return "square.stack.3d.up"
        case .ocrText: return "text.viewfinder"
        case .comparePDF: return "doc.on.doc"
        case .imageToPDF: return "photo.on.rectangle"
        case .docToPDF: return "doc.text.fill"
        case .pdfToImage: return "photo"
        case .pdfToText: return "doc.plaintext"
        case .signPDF: return "signature"
        case .cropPDF: return "crop"
        case .metadataEditor: return "info.circle"
        case .redactPDF: return "eye.slash"
        case .summarizePDF: return "text.badge.star"
        case .askPDF: return "questionmark.bubble"
        case .translatePDF: return "textformat.abc"
        case .handwriting: return "hand.draw"
        case .formAutofill: return "square.and.pencil.circle"
        case .templates: return "doc.badge.plus"
        case .emailPDF: return "envelope"
        case .qrShare: return "qrcode"
        }
    }

    var description: String {
        switch self {
        case .scanner: return String(localized: "Scan documents")
        case .mergePDF: return String(localized: "Combine multiple PDFs")
        case .splitPDF: return String(localized: "Split PDF by pages")
        case .compressPDF: return String(localized: "Reduce PDF file size")
        case .lockPDF: return String(localized: "Password protect PDF")
        case .unlockPDF: return String(localized: "Remove PDF password")
        case .extractPages: return String(localized: "Extract specific pages")
        case .rotatePDF: return String(localized: "Rotate PDF pages")
        case .reorderPDF: return String(localized: "Rearrange PDF pages")
        case .pageNumbers: return String(localized: "Add page numbers")
        case .watermark: return String(localized: "Add text watermark")
        case .batchProcess: return String(localized: "Process multiple PDFs")
        case .ocrText: return String(localized: "Extract text from images")
        case .comparePDF: return String(localized: "Compare two documents")
        case .imageToPDF: return String(localized: "Convert images to PDF")
        case .docToPDF: return String(localized: "Convert documents to PDF")
        case .pdfToImage: return String(localized: "Export PDF pages as images")
        case .pdfToText: return String(localized: "Extract text from PDF")
        case .signPDF: return String(localized: "Add signature to PDF")
        case .cropPDF: return String(localized: "Crop PDF page margins")
        case .metadataEditor: return String(localized: "Edit PDF properties")
        case .redactPDF: return String(localized: "Auto-detect & redact sensitive data")
        case .summarizePDF: return String(localized: "AI-powered PDF summary")
        case .askPDF: return String(localized: "Ask questions about PDF")
        case .translatePDF: return String(localized: "Translate PDF content")
        case .handwriting: return String(localized: "Convert handwriting to text")
        case .formAutofill: return String(localized: "Auto-fill any form from your library")
        case .templates: return String(localized: "Create from template")
        case .emailPDF: return String(localized: "Email PDF as attachment")
        case .qrShare: return String(localized: "Share via QR code")
        }
    }

    /// Power-user tools that we hide behind an "Advanced" disclosure in the Tools
    /// tab to cut first-impression overload. Frequently-used tools stay visible.
    var isAdvanced: Bool {
        switch self {
        case .pageNumbers, .metadataEditor, .reorderPDF, .cropPDF, .qrShare, .batchProcess:
            return true
        default:
            return false
        }
    }

    var section: String {
        switch self {
        case .scanner:
            return String(localized: "Scan", comment: "ToolItem section: scanner")
        case .mergePDF, .splitPDF, .extractPages, .rotatePDF, .reorderPDF, .cropPDF:
            return String(localized: "Edit", comment: "ToolItem section")
        case .compressPDF, .pageNumbers, .watermark, .signPDF, .metadataEditor:
            return String(localized: "Enhance", comment: "ToolItem section")
        case .lockPDF, .unlockPDF, .redactPDF:
            return String(localized: "Protect", comment: "ToolItem section")
        case .comparePDF, .batchProcess:
            return String(localized: "Compare", comment: "ToolItem section")
        case .summarizePDF, .askPDF, .translatePDF, .handwriting, .ocrText, .formAutofill:
            return String(localized: "AI Intelligence", comment: "ToolItem section")
        case .imageToPDF, .docToPDF, .pdfToImage, .pdfToText:
            return String(localized: "Convert", comment: "ToolItem section")
        case .templates, .emailPDF, .qrShare:
            return String(localized: "Share & Create", comment: "ToolItem section")
        }
    }

    var color: Color {
        switch self {
        case .scanner: return .appAccent
        case .mergePDF: return .appPrimary
        case .splitPDF: return .appWarning
        case .compressPDF: return .appSuccess
        case .lockPDF: return .appDanger
        case .unlockPDF: return .appAccent
        case .extractPages: return .appPrimary
        case .rotatePDF: return .appWarning
        case .reorderPDF: return .appSuccess
        case .pageNumbers: return .appAccent
        case .watermark: return .appPrimary
        case .batchProcess: return .appPrimary
        case .ocrText: return .appSuccess
        case .comparePDF: return .appWarning
        case .imageToPDF: return .appWarning
        case .docToPDF: return .appPrimary
        case .pdfToImage: return .appAccent
        case .pdfToText: return .appSuccess
        case .signPDF: return .appDanger
        case .cropPDF: return .appWarning
        case .metadataEditor: return .appAccent
        case .redactPDF: return .appDanger
        case .summarizePDF: return .appPrimary
        case .askPDF: return .appAccent
        case .translatePDF: return .appSuccess
        case .handwriting: return .appAccent
        case .formAutofill: return .appPrimary
        case .templates: return .appSuccess
        case .emailPDF: return .appWarning
        case .qrShare: return .appAccent
        }
    }
}
