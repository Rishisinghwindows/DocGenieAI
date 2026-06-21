import SwiftUI
import PDFKit

enum TemplateCategory: String, CaseIterable, Identifiable {
    case business = "Business"
    case personal = "Personal"
    case legal = "Legal"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .business: return "briefcase.fill"
        case .personal: return "person.fill"
        case .legal: return "scale.3d"
        }
    }

    var color: Color {
        switch self {
        case .business: return .appPrimary
        case .personal: return .appAccent
        case .legal: return .appWarning
        }
    }
}

enum DocumentTemplate: String, CaseIterable, Identifiable {
    case invoice
    case resume
    case nda
    case meetingNotes
    case projectProposal
    case letterFormal
    case letterCasual
    case receipt
    case report

    var id: String { rawValue }

    var name: String {
        switch self {
        case .invoice: return "Invoice"
        case .resume: return "Resume"
        case .nda: return "NDA"
        case .meetingNotes: return "Meeting Notes"
        case .projectProposal: return "Project Proposal"
        case .letterFormal: return "Formal Letter"
        case .letterCasual: return "Casual Letter"
        case .receipt: return "Receipt"
        case .report: return "Report"
        }
    }

    var description: String {
        switch self {
        case .invoice: return "Professional invoice with line items"
        case .resume: return "Clean and modern resume layout"
        case .nda: return "Non-disclosure agreement template"
        case .meetingNotes: return "Structured meeting minutes"
        case .projectProposal: return "Detailed project proposal"
        case .letterFormal: return "Formal business letter"
        case .letterCasual: return "Friendly personal letter"
        case .receipt: return "Payment receipt with details"
        case .report: return "Professional report template"
        }
    }

    var systemImage: String {
        switch self {
        case .invoice: return "doc.text.fill"
        case .resume: return "person.text.rectangle"
        case .nda: return "lock.shield"
        case .meetingNotes: return "list.clipboard"
        case .projectProposal: return "lightbulb.fill"
        case .letterFormal: return "envelope.fill"
        case .letterCasual: return "text.bubble"
        case .receipt: return "receipt"
        case .report: return "chart.bar.doc.horizontal"
        }
    }

    var category: TemplateCategory {
        switch self {
        case .invoice, .resume, .projectProposal, .report:
            return .business
        case .meetingNotes, .letterCasual, .letterFormal:
            return .personal
        case .nda, .receipt:
            return .legal
        }
    }

    static func templates(for category: TemplateCategory) -> [DocumentTemplate] {
        allCases.filter { $0.category == category }
    }

    // MARK: - PDF Generation

    func generatePDF() -> Data {
        let pageWidth: CGFloat = 612
        let pageHeight: CGFloat = 792
        let margin: CGFloat = 50
        let contentWidth = pageWidth - margin * 2

        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight))

        return renderer.pdfData { context in
            context.beginPage()
            var yOffset: CGFloat = margin

            let titleAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 24, weight: .bold),
                .foregroundColor: UIColor(red: 0.388, green: 0.400, blue: 0.945, alpha: 1.0)
            ]
            let headingAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 16, weight: .semibold),
                .foregroundColor: UIColor.darkGray
            ]
            let bodyAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 12, weight: .regular),
                .foregroundColor: UIColor.darkGray
            ]
            let labelAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 11, weight: .medium),
                .foregroundColor: UIColor.gray
            ]

            func drawText(_ text: String, attributes: [NSAttributedString.Key: Any], at y: inout CGFloat, maxWidth: CGFloat = contentWidth) {
                let attributedString = NSAttributedString(string: text, attributes: attributes)
                let rect = CGRect(x: margin, y: y, width: maxWidth, height: .greatestFiniteMagnitude)
                let boundingRect = attributedString.boundingRect(with: rect.size, options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil)
                attributedString.draw(in: CGRect(x: margin, y: y, width: maxWidth, height: boundingRect.height))
                y += boundingRect.height + 8
            }

            func drawLine(at y: inout CGFloat) {
                let path = UIBezierPath()
                path.move(to: CGPoint(x: margin, y: y))
                path.addLine(to: CGPoint(x: pageWidth - margin, y: y))
                UIColor.lightGray.setStroke()
                path.lineWidth = 0.5
                path.stroke()
                y += 16
            }

            func drawField(_ label: String, placeholder: String, at y: inout CGFloat) {
                drawText(label, attributes: labelAttributes, at: &y)
                y -= 4
                let fieldRect = CGRect(x: margin, y: y, width: contentWidth, height: 22)
                UIColor(white: 0.95, alpha: 1.0).setFill()
                UIBezierPath(roundedRect: fieldRect, cornerRadius: 4).fill()
                let placeholderAttr = NSAttributedString(string: placeholder, attributes: [
                    .font: UIFont.systemFont(ofSize: 11, weight: .regular),
                    .foregroundColor: UIColor.lightGray
                ])
                placeholderAttr.draw(in: fieldRect.insetBy(dx: 8, dy: 4))
                y += 32
            }

            switch self {
            case .invoice:
                drawText("INVOICE", attributes: titleAttributes, at: &yOffset)
                drawLine(at: &yOffset)
                drawField("Invoice Number", placeholder: "#INV-001", at: &yOffset)
                drawField("Date", placeholder: "MM/DD/YYYY", at: &yOffset)
                drawField("Bill To", placeholder: "Client name and address", at: &yOffset)
                drawField("From", placeholder: "Your company name and address", at: &yOffset)
                yOffset += 8
                drawText("Line Items", attributes: headingAttributes, at: &yOffset)
                drawLine(at: &yOffset)
                for i in 1...3 {
                    drawText("Item \(i):  Description .................. $0.00", attributes: bodyAttributes, at: &yOffset)
                }
                drawLine(at: &yOffset)
                drawText("Subtotal: $0.00", attributes: bodyAttributes, at: &yOffset)
                drawText("Tax: $0.00", attributes: bodyAttributes, at: &yOffset)
                drawText("Total: $0.00", attributes: headingAttributes, at: &yOffset)
                yOffset += 16
                drawField("Payment Terms", placeholder: "Due within 30 days", at: &yOffset)
                drawField("Notes", placeholder: "Additional notes or instructions", at: &yOffset)

            case .resume:
                drawText("YOUR NAME", attributes: titleAttributes, at: &yOffset)
                drawText("your.email@example.com  |  (555) 123-4567  |  City, State", attributes: labelAttributes, at: &yOffset)
                drawLine(at: &yOffset)
                drawText("Professional Summary", attributes: headingAttributes, at: &yOffset)
                drawText("A brief summary of your professional experience, skills, and career objectives. Highlight your key achievements and what you bring to potential employers.", attributes: bodyAttributes, at: &yOffset)
                yOffset += 8
                drawText("Experience", attributes: headingAttributes, at: &yOffset)
                drawLine(at: &yOffset)
                drawText("Job Title  |  Company Name  |  Start Date - End Date", attributes: labelAttributes, at: &yOffset)
                drawText("- Describe your responsibilities and key accomplishments\n- Use bullet points for clarity\n- Quantify results when possible", attributes: bodyAttributes, at: &yOffset)
                yOffset += 8
                drawText("Education", attributes: headingAttributes, at: &yOffset)
                drawLine(at: &yOffset)
                drawText("Degree  |  University Name  |  Graduation Year", attributes: labelAttributes, at: &yOffset)
                yOffset += 8
                drawText("Skills", attributes: headingAttributes, at: &yOffset)
                drawLine(at: &yOffset)
                drawText("Skill 1, Skill 2, Skill 3, Skill 4, Skill 5", attributes: bodyAttributes, at: &yOffset)

            case .nda:
                drawText("NON-DISCLOSURE AGREEMENT", attributes: titleAttributes, at: &yOffset)
                drawLine(at: &yOffset)
                drawField("Effective Date", placeholder: "MM/DD/YYYY", at: &yOffset)
                drawField("Disclosing Party", placeholder: "Name of disclosing party", at: &yOffset)
                drawField("Receiving Party", placeholder: "Name of receiving party", at: &yOffset)
                yOffset += 8
                drawText("1. Definition of Confidential Information", attributes: headingAttributes, at: &yOffset)
                drawText("\"Confidential Information\" means any data or information, oral or written, that is treated as confidential by the Disclosing Party, including but not limited to trade secrets, business plans, financial information, and proprietary technology.", attributes: bodyAttributes, at: &yOffset)
                yOffset += 4
                drawText("2. Obligations of Receiving Party", attributes: headingAttributes, at: &yOffset)
                drawText("The Receiving Party agrees to hold all Confidential Information in strict confidence and not to disclose such information to any third party without prior written consent.", attributes: bodyAttributes, at: &yOffset)
                yOffset += 4
                drawText("3. Term", attributes: headingAttributes, at: &yOffset)
                drawText("This Agreement shall remain in effect for a period of [duration] from the Effective Date.", attributes: bodyAttributes, at: &yOffset)
                yOffset += 16
                drawField("Signature (Disclosing Party)", placeholder: "Sign here", at: &yOffset)
                drawField("Signature (Receiving Party)", placeholder: "Sign here", at: &yOffset)

            case .meetingNotes:
                drawText("MEETING NOTES", attributes: titleAttributes, at: &yOffset)
                drawLine(at: &yOffset)
                drawField("Meeting Title", placeholder: "Weekly Team Sync", at: &yOffset)
                drawField("Date & Time", placeholder: "MM/DD/YYYY at HH:MM AM/PM", at: &yOffset)
                drawField("Location", placeholder: "Conference Room / Virtual", at: &yOffset)
                drawField("Attendees", placeholder: "Name 1, Name 2, Name 3", at: &yOffset)
                yOffset += 8
                drawText("Agenda", attributes: headingAttributes, at: &yOffset)
                drawText("1. Topic one\n2. Topic two\n3. Topic three", attributes: bodyAttributes, at: &yOffset)
                yOffset += 4
                drawText("Discussion Notes", attributes: headingAttributes, at: &yOffset)
                drawLine(at: &yOffset)
                drawText("[Record key discussion points, decisions made, and any important details shared during the meeting.]", attributes: bodyAttributes, at: &yOffset)
                yOffset += 4
                drawText("Action Items", attributes: headingAttributes, at: &yOffset)
                drawLine(at: &yOffset)
                drawText("- [ ] Action item 1 - Assigned to: _____ - Due: _____\n- [ ] Action item 2 - Assigned to: _____ - Due: _____\n- [ ] Action item 3 - Assigned to: _____ - Due: _____", attributes: bodyAttributes, at: &yOffset)

            case .projectProposal:
                drawText("PROJECT PROPOSAL", attributes: titleAttributes, at: &yOffset)
                drawLine(at: &yOffset)
                drawField("Project Name", placeholder: "Enter project name", at: &yOffset)
                drawField("Prepared By", placeholder: "Your name", at: &yOffset)
                drawField("Date", placeholder: "MM/DD/YYYY", at: &yOffset)
                yOffset += 8
                drawText("Executive Summary", attributes: headingAttributes, at: &yOffset)
                drawText("Provide a high-level overview of the project, its goals, and expected outcomes. This section should capture the reader's attention and summarize the proposal.", attributes: bodyAttributes, at: &yOffset)
                yOffset += 4
                drawText("Objectives", attributes: headingAttributes, at: &yOffset)
                drawText("1. Primary objective\n2. Secondary objective\n3. Additional objective", attributes: bodyAttributes, at: &yOffset)
                yOffset += 4
                drawText("Scope & Deliverables", attributes: headingAttributes, at: &yOffset)
                drawText("Define the boundaries of the project and list key deliverables.", attributes: bodyAttributes, at: &yOffset)
                yOffset += 4
                drawText("Timeline", attributes: headingAttributes, at: &yOffset)
                drawText("Phase 1: Planning (Week 1-2)\nPhase 2: Development (Week 3-6)\nPhase 3: Review & Launch (Week 7-8)", attributes: bodyAttributes, at: &yOffset)
                yOffset += 4
                drawText("Budget", attributes: headingAttributes, at: &yOffset)
                drawField("Estimated Budget", placeholder: "$0.00", at: &yOffset)

            case .letterFormal:
                drawField("Your Name", placeholder: "Your full name", at: &yOffset)
                drawField("Your Address", placeholder: "Street, City, State ZIP", at: &yOffset)
                drawField("Date", placeholder: "MM/DD/YYYY", at: &yOffset)
                yOffset += 8
                drawField("Recipient Name", placeholder: "Recipient's full name", at: &yOffset)
                drawField("Recipient Address", placeholder: "Street, City, State ZIP", at: &yOffset)
                yOffset += 8
                drawText("Dear [Recipient Name],", attributes: headingAttributes, at: &yOffset)
                yOffset += 4
                drawText("I am writing to [state the purpose of your letter]. This letter serves as [a formal request / notification / inquiry] regarding [subject matter].", attributes: bodyAttributes, at: &yOffset)
                yOffset += 4
                drawText("[Provide additional details, context, or supporting information in this paragraph. Be clear and concise while maintaining a professional tone.]", attributes: bodyAttributes, at: &yOffset)
                yOffset += 4
                drawText("[Conclude with a call to action or next steps. Thank the recipient for their time and consideration.]", attributes: bodyAttributes, at: &yOffset)
                yOffset += 16
                drawText("Sincerely,", attributes: bodyAttributes, at: &yOffset)
                yOffset += 24
                drawField("Signature", placeholder: "Your signature", at: &yOffset)
                drawText("[Your Typed Name]", attributes: bodyAttributes, at: &yOffset)

            case .letterCasual:
                drawField("Date", placeholder: "MM/DD/YYYY", at: &yOffset)
                yOffset += 8
                drawText("Hey [Name]!", attributes: titleAttributes, at: &yOffset)
                yOffset += 4
                drawText("Hope you're doing well! I wanted to reach out about [reason for writing]. It's been a while since we last caught up, and I thought it would be great to [purpose].", attributes: bodyAttributes, at: &yOffset)
                yOffset += 4
                drawText("[Share your main message, updates, or news here. Keep the tone friendly and conversational.]", attributes: bodyAttributes, at: &yOffset)
                yOffset += 4
                drawText("[Wrap up with any plans, questions, or well-wishes. Mention if you'd like to meet up or continue the conversation.]", attributes: bodyAttributes, at: &yOffset)
                yOffset += 12
                drawText("Talk soon!", attributes: bodyAttributes, at: &yOffset)
                drawText("[Your Name]", attributes: headingAttributes, at: &yOffset)

            case .receipt:
                drawText("RECEIPT", attributes: titleAttributes, at: &yOffset)
                drawLine(at: &yOffset)
                drawField("Receipt Number", placeholder: "#REC-001", at: &yOffset)
                drawField("Date", placeholder: "MM/DD/YYYY", at: &yOffset)
                drawField("Received From", placeholder: "Payer name", at: &yOffset)
                drawField("Received By", placeholder: "Your name / company", at: &yOffset)
                yOffset += 8
                drawText("Payment Details", attributes: headingAttributes, at: &yOffset)
                drawLine(at: &yOffset)
                drawText("Description:  ________________________________", attributes: bodyAttributes, at: &yOffset)
                drawText("Amount:       $0.00", attributes: bodyAttributes, at: &yOffset)
                drawText("Payment Method: Cash / Check / Card / Transfer", attributes: bodyAttributes, at: &yOffset)
                yOffset += 8
                drawLine(at: &yOffset)
                drawText("Total Received: $0.00", attributes: headingAttributes, at: &yOffset)
                yOffset += 16
                drawField("Authorized Signature", placeholder: "Sign here", at: &yOffset)
                yOffset += 8
                drawText("Thank you for your payment.", attributes: labelAttributes, at: &yOffset)

            case .report:
                drawText("REPORT", attributes: titleAttributes, at: &yOffset)
                drawLine(at: &yOffset)
                drawField("Report Title", placeholder: "Enter report title", at: &yOffset)
                drawField("Prepared By", placeholder: "Author name", at: &yOffset)
                drawField("Date", placeholder: "MM/DD/YYYY", at: &yOffset)
                drawField("Department", placeholder: "Department or team name", at: &yOffset)
                yOffset += 8
                drawText("1. Executive Summary", attributes: headingAttributes, at: &yOffset)
                drawText("Provide a brief overview of the report's purpose, key findings, and recommendations.", attributes: bodyAttributes, at: &yOffset)
                yOffset += 4
                drawText("2. Introduction", attributes: headingAttributes, at: &yOffset)
                drawText("Describe the background and context for this report. Explain why this report was prepared and what it aims to address.", attributes: bodyAttributes, at: &yOffset)
                yOffset += 4
                drawText("3. Findings", attributes: headingAttributes, at: &yOffset)
                drawText("Present the key findings, data, and analysis. Use subsections as needed to organize the information clearly.", attributes: bodyAttributes, at: &yOffset)
                yOffset += 4
                drawText("4. Recommendations", attributes: headingAttributes, at: &yOffset)
                drawText("Based on the findings, provide actionable recommendations for next steps.", attributes: bodyAttributes, at: &yOffset)
                yOffset += 4
                drawText("5. Conclusion", attributes: headingAttributes, at: &yOffset)
                drawText("Summarize the key points and reiterate the importance of the recommendations.", attributes: bodyAttributes, at: &yOffset)
            }

            // Footer
            yOffset = pageHeight - margin - 20
            let footerText = NSAttributedString(string: "Generated by \(AppConstants.appName)", attributes: [
                .font: UIFont.systemFont(ofSize: 9, weight: .regular),
                .foregroundColor: UIColor.lightGray
            ])
            footerText.draw(at: CGPoint(x: margin, y: yOffset))
        }
    }

    func defaultFileName() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateString = formatter.string(from: Date())
        return "\(name) - \(dateString)"
    }
}
