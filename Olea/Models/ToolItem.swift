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
        case .scanner: return oleaLocalized("Scanner")
        case .mergePDF: return oleaLocalized("Merge PDF")
        case .splitPDF: return oleaLocalized("Split PDF")
        case .compressPDF: return oleaLocalized("Compress")
        case .lockPDF: return oleaLocalized("Lock PDF")
        case .unlockPDF: return oleaLocalized("Unlock PDF")
        case .extractPages: return oleaLocalized("Extract Pages")
        case .rotatePDF: return oleaLocalized("Rotate PDF")
        case .reorderPDF: return oleaLocalized("Reorder Pages")
        case .pageNumbers: return oleaLocalized("Page Numbers")
        case .watermark: return oleaLocalized("Watermark")
        case .batchProcess: return oleaLocalized("Batch Process")
        case .ocrText: return oleaLocalized("OCR Text")
        case .comparePDF: return oleaLocalized("Compare PDFs")
        case .signPDF: return oleaLocalized("Sign PDF")
        case .cropPDF: return oleaLocalized("Crop PDF")
        case .metadataEditor: return oleaLocalized("PDF Metadata")
        case .redactPDF: return oleaLocalized("Redact PDF")
        case .imageToPDF: return oleaLocalized("Image to PDF")
        case .docToPDF: return oleaLocalized("Doc to PDF")
        case .pdfToImage: return oleaLocalized("PDF to Image")
        case .pdfToText: return oleaLocalized("PDF to Text")
        case .summarizePDF: return oleaLocalized("Summarize PDF")
        case .askPDF: return oleaLocalized("Ask PDF")
        case .translatePDF: return oleaLocalized("Translate PDF")
        case .handwriting: return oleaLocalized("Handwriting")
        case .formAutofill: return oleaLocalized("Smart Form Fill")
        case .templates: return oleaLocalized("Templates")
        case .emailPDF: return oleaLocalized("Email PDF")
        case .qrShare: return oleaLocalized("QR Share")
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
        case .scanner: return oleaLocalized("Scan documents")
        case .mergePDF: return oleaLocalized("Combine multiple PDFs")
        case .splitPDF: return oleaLocalized("Split PDF by pages")
        case .compressPDF: return oleaLocalized("Reduce PDF file size")
        case .lockPDF: return oleaLocalized("Password protect PDF")
        case .unlockPDF: return oleaLocalized("Remove PDF password")
        case .extractPages: return oleaLocalized("Extract specific pages")
        case .rotatePDF: return oleaLocalized("Rotate PDF pages")
        case .reorderPDF: return oleaLocalized("Rearrange PDF pages")
        case .pageNumbers: return oleaLocalized("Add page numbers")
        case .watermark: return oleaLocalized("Add text watermark")
        case .batchProcess: return oleaLocalized("Process multiple PDFs")
        case .ocrText: return oleaLocalized("Extract text from images")
        case .comparePDF: return oleaLocalized("Compare two documents")
        case .imageToPDF: return oleaLocalized("Convert images to PDF")
        case .docToPDF: return oleaLocalized("Convert documents to PDF")
        case .pdfToImage: return oleaLocalized("Export PDF pages as images")
        case .pdfToText: return oleaLocalized("Extract text from PDF")
        case .signPDF: return oleaLocalized("Add signature to PDF")
        case .cropPDF: return oleaLocalized("Crop PDF page margins")
        case .metadataEditor: return oleaLocalized("Edit PDF properties")
        case .redactPDF: return oleaLocalized("Auto-detect & redact sensitive data")
        case .summarizePDF: return oleaLocalized("AI-powered PDF summary")
        case .askPDF: return oleaLocalized("Ask questions about PDF")
        case .translatePDF: return oleaLocalized("Translate PDF content")
        case .handwriting: return oleaLocalized("Convert handwriting to text")
        case .formAutofill: return oleaLocalized("Auto-fill any form from your library")
        case .templates: return oleaLocalized("Create from template")
        case .emailPDF: return oleaLocalized("Email PDF as attachment")
        case .qrShare: return oleaLocalized("Share via QR code")
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

    /// Stable English identifier used for grouping/filtering — never displayed.
    /// `localizedSection` is what the UI renders. Splitting these prevents the
    /// "groupedTools is empty" regression that surfaces when callers compare a
    /// localized string against an English literal.
    var sectionID: String {
        switch self {
        case .scanner: return "Scan"
        case .mergePDF, .splitPDF, .extractPages, .rotatePDF, .reorderPDF, .cropPDF: return "Edit"
        case .compressPDF, .pageNumbers, .watermark, .signPDF, .metadataEditor: return "Enhance"
        case .lockPDF, .unlockPDF, .redactPDF: return "Protect"
        case .comparePDF, .batchProcess: return "Compare"
        case .summarizePDF, .askPDF, .translatePDF, .handwriting, .ocrText, .formAutofill: return "AI Intelligence"
        case .imageToPDF, .docToPDF, .pdfToImage, .pdfToText: return "Convert"
        case .templates, .emailPDF, .qrShare: return "Share & Create"
        }
    }

    var section: String {
        switch self {
        case .scanner:
            return oleaLocalized("Scan")
        case .mergePDF, .splitPDF, .extractPages, .rotatePDF, .reorderPDF, .cropPDF:
            return oleaLocalized("Edit")
        case .compressPDF, .pageNumbers, .watermark, .signPDF, .metadataEditor:
            return oleaLocalized("Enhance")
        case .lockPDF, .unlockPDF, .redactPDF:
            return oleaLocalized("Protect")
        case .comparePDF, .batchProcess:
            return oleaLocalized("Compare")
        case .summarizePDF, .askPDF, .translatePDF, .handwriting, .ocrText, .formAutofill:
            return oleaLocalized("AI Intelligence")
        case .imageToPDF, .docToPDF, .pdfToImage, .pdfToText:
            return oleaLocalized("Convert")
        case .templates, .emailPDF, .qrShare:
            return oleaLocalized("Share & Create")
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
