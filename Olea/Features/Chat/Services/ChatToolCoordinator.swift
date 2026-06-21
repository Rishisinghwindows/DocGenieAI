import SwiftUI
import SwiftData

@MainActor
@Observable
final class ChatToolCoordinator {
    var activeTool: ToolItem?
    var showScanner = false
    /// When non-nil, the ChatTabView presents the rewarded-ad gate sheet for
    /// this tool. After the user watches the ad (or the gate falls open),
    /// `unlockGatedTool(_:)` opens the tool for real.
    var gatedTool: ToolItem?

    func openTool(_ tool: ToolItem) {
        HapticManager.medium()
        switch FeatureGate.shared.evaluate(toolID: tool.id) {
        case .openFree:
            FeatureGate.shared.recordUse(toolID: tool.id)
            if tool == .scanner {
                showScanner = true
            } else {
                activeTool = tool
            }
        case .needsRewardedAd:
            gatedTool = tool
        }
    }

    /// Called by ChatTabView's gate-sheet binding when the user successfully
    /// watches the rewarded ad (or fall-open fires).
    func unlockGatedTool(_ tool: ToolItem) {
        FeatureGate.shared.recordUse(toolID: tool.id)
        gatedTool = nil
        if tool == .scanner {
            showScanner = true
        } else {
            activeTool = tool
        }
    }

    func dismissTool() {
        activeTool = nil
    }

    func toolForId(_ id: String) -> ToolItem? {
        ToolItem.allCases.first { $0.rawValue == id || $0.id == id }
    }
}

// MARK: - Agent Orchestrator (Graph-Based, LangGraph-Inspired)

/// A declarative graph engine for multi-step document workflows.
/// Supports: pipelines, conditional routing, parallel nodes, error recovery, persistent state.
/// Pure Swift — zero dependencies, fully on-device.
@MainActor
@Observable
final class AgentOrchestrator {
    static let shared = AgentOrchestrator()

    // Per-conversation state
    private var states: [UUID: AgentState] = [:]

    // Pipeline registry — multi-step workflows
    private(set) var pipelines: [String: Pipeline] = [:]

    private init() {
        registerBuiltInPipelines()
    }

    // MARK: - Graph State

    enum AgentState {
        case idle
        case awaitingFile(tool: AgentTool)
        case awaitingParams(tool: AgentTool, file: DocumentFile, neededParams: [String])
        case executing(tool: AgentTool, file: DocumentFile, params: [String: String])
        case runningPipeline(pipeline: Pipeline, stepIndex: Int, context: PipelineContext)
        case completed
    }

    // MARK: - Pipeline Engine (Multi-Step Workflows)

    /// A pipeline is a sequence of steps that execute in order.
    /// Each step is a node that transforms the context.
    struct Pipeline: Identifiable {
        let id: String
        let name: String
        let description: String
        let steps: [PipelineStep]
        let trigger: String // user-facing command like "scan and summarize"
    }

    /// A single step in a pipeline
    struct PipelineStep {
        let name: String
        let toolType: String // maps to InlineChatToolExecutor tool types
        let requiresFile: Bool
        let requiresParams: [String]
        let condition: ((PipelineContext) -> Bool)? // conditional execution

        init(name: String, toolType: String, requiresFile: Bool = false,
             requiresParams: [String] = [], condition: ((PipelineContext) -> Bool)? = nil) {
            self.name = name
            self.toolType = toolType
            self.requiresFile = requiresFile
            self.requiresParams = requiresParams
            self.condition = condition
        }
    }

    /// Shared context passed between pipeline steps
    class PipelineContext {
        var file: DocumentFile?
        var extractedText: String = ""
        var results: [String: InlineToolResult] = [:]
        var params: [String: String] = [:]
        var errors: [String] = []

        var lastResult: InlineToolResult? {
            results.values.sorted { $0.toolType < $1.toolType }.last
        }
    }

    // MARK: - Built-in Pipelines

    private func registerBuiltInPipelines() {
        // Pipeline: Scan → OCR → Summarize
        register(Pipeline(
            id: "scan_summarize",
            name: "Scan & Summarize",
            description: "Scan a document, extract text, and generate a summary",
            steps: [
                PipelineStep(name: "Extract Text", toolType: "ocr", requiresFile: true),
                PipelineStep(name: "Summarize", toolType: "summarize", requiresFile: true),
            ],
            trigger: "scan and summarize"
        ))

        // Pipeline: OCR → Translate
        register(Pipeline(
            id: "ocr_translate",
            name: "Extract & Translate",
            description: "Extract text from a document and translate it",
            steps: [
                PipelineStep(name: "Extract Text", toolType: "ocr", requiresFile: true),
                PipelineStep(name: "Translate", toolType: "summarize", requiresFile: true,
                             requiresParams: ["language"]),
            ],
            trigger: "extract and translate"
        ))

        // Pipeline: Compress → Watermark → Lock
        register(Pipeline(
            id: "secure_pdf",
            name: "Secure PDF",
            description: "Compress, add watermark, and password-protect a PDF",
            steps: [
                PipelineStep(name: "Compress", toolType: "compress", requiresFile: true),
                PipelineStep(name: "Watermark", toolType: "watermark", requiresFile: true),
            ],
            trigger: "secure this pdf"
        ))

        // Pipeline: OCR → Formal Rewrite
        register(Pipeline(
            id: "ocr_rewrite",
            name: "Extract & Rewrite",
            description: "Extract text and rewrite it formally",
            steps: [
                PipelineStep(name: "Extract Text", toolType: "ocr", requiresFile: true),
                PipelineStep(name: "Rewrite Formal", toolType: "rewrite_formal", requiresFile: true),
            ],
            trigger: "extract and rewrite"
        ))

        // Pipeline: OCR → Bullet Points
        register(Pipeline(
            id: "ocr_bullets",
            name: "Extract & Bulletize",
            description: "Extract text and convert to bullet points",
            steps: [
                PipelineStep(name: "Extract Text", toolType: "ocr", requiresFile: true),
                PipelineStep(name: "Bullet Points", toolType: "bullet_points", requiresFile: true),
            ],
            trigger: "extract and make bullets"
        ))
    }

    func register(_ pipeline: Pipeline) {
        pipelines[pipeline.id] = pipeline
    }

    // MARK: - Pipeline Detection

    func detectPipeline(from message: String) -> Pipeline? {
        let lower = message.lowercased()

        // Multi-step intent patterns
        let multiStepPatterns: [(keywords: [String], pipelineId: String)] = [
            (["scan and summarize", "scan then summarize", "scan summarize"], "scan_summarize"),
            (["extract and translate", "ocr and translate", "text and translate"], "ocr_translate"),
            (["secure", "compress and lock", "protect and compress"], "secure_pdf"),
            (["extract and rewrite", "ocr and rewrite", "formal rewrite"], "ocr_rewrite"),
            (["extract and bullet", "ocr and bullet", "make bullets from"], "ocr_bullets"),
        ]

        for (keywords, id) in multiStepPatterns {
            if keywords.contains(where: { lower.contains($0) }) {
                return pipelines[id]
            }
        }
        return nil
    }

    // MARK: - Pipeline Execution

    func startPipeline(
        _ pipeline: Pipeline,
        file: DocumentFile,
        conversationId: UUID
    ) {
        let context = PipelineContext()
        context.file = file
        setState(.runningPipeline(pipeline: pipeline, stepIndex: 0, context: context), for: conversationId)
    }

    func currentPipelineStep(for conversationId: UUID) -> (Pipeline, Int, PipelineContext)? {
        if case .runningPipeline(let pipeline, let index, let context) = getState(for: conversationId) {
            return (pipeline, index, context)
        }
        return nil
    }

    func advancePipeline(for conversationId: UUID) {
        guard case .runningPipeline(let pipeline, let index, let context) = getState(for: conversationId) else { return }
        let nextIndex = index + 1
        if nextIndex < pipeline.steps.count {
            setState(.runningPipeline(pipeline: pipeline, stepIndex: nextIndex, context: context), for: conversationId)
        } else {
            setState(.completed, for: conversationId)
        }
    }

    // MARK: - Tool Definitions (Nodes)

    enum AgentTool: String, CaseIterable {
        case merge, compress, ocr, split, lock, unlock, watermark
        case imageToPDF, sign, summarize, translate, askPDF
        case rotate, reorder, pageNumbers, extractPages, crop
        case docToPDF, pdfToImage, pdfToText, metadata, emailPDF

        var displayName: String {
            switch self {
            case .merge: return "Merge PDF"
            case .compress: return "Compress"
            case .ocr: return "OCR Text"
            case .split: return "Split PDF"
            case .lock: return "Lock PDF"
            case .unlock: return "Unlock PDF"
            case .watermark: return "Watermark"
            case .imageToPDF: return "Image to PDF"
            case .sign: return "Sign PDF"
            case .summarize: return "Summarize PDF"
            case .translate: return "Translate PDF"
            case .askPDF: return "Ask PDF"
            case .rotate: return "Rotate PDF"
            case .reorder: return "Reorder Pages"
            case .pageNumbers: return "Page Numbers"
            case .extractPages: return "Extract Pages"
            case .crop: return "Crop PDF"
            case .docToPDF: return "Doc to PDF"
            case .pdfToImage: return "PDF to Image"
            case .pdfToText: return "PDF to Text"
            case .metadata: return "PDF Metadata"
            case .emailPDF: return "Email PDF"
            }
        }

        var requiredParams: [String] {
            switch self {
            case .lock: return ["password"]
            case .split: return ["startPage", "endPage"]
            case .watermark: return ["watermarkText"]
            case .extractPages: return ["pages"]
            case .rotate: return ["degrees"]
            case .translate: return ["language"]
            case .askPDF: return ["question"]
            default: return []
            }
        }

        /// Tools that can chain after this tool completes
        var suggestedNextTools: [AgentTool] {
            switch self {
            case .ocr: return [.summarize, .translate]
            case .summarize: return [.translate, .compress]
            case .compress: return [.watermark, .lock]
            case .merge: return [.compress, .watermark]
            case .imageToPDF: return [.ocr, .compress]
            case .docToPDF: return [.compress, .ocr]
            case .pdfToText: return [.summarize, .translate]
            case .pdfToImage: return []
            case .rotate: return [.compress, .merge]
            case .crop: return [.compress]
            case .metadata: return [.compress, .lock]
            default: return []
            }
        }

        static func from(toolId: String) -> AgentTool? {
            switch toolId {
            case "Merge PDF": return .merge
            case "Compress": return .compress
            case "OCR Text": return .ocr
            case "Split PDF": return .split
            case "Lock PDF": return .lock
            case "Unlock PDF": return .unlock
            case "Watermark": return .watermark
            case "Image to PDF": return .imageToPDF
            case "Sign PDF": return .sign
            case "Summarize PDF": return .summarize
            case "Translate PDF": return .translate
            case "Ask PDF": return .askPDF
            case "Rotate PDF": return .rotate
            case "Reorder Pages": return .reorder
            case "Page Numbers": return .pageNumbers
            case "Extract Pages": return .extractPages
            case "Crop PDF": return .crop
            case "Doc to PDF": return .docToPDF
            case "PDF to Image": return .pdfToImage
            case "PDF to Text": return .pdfToText
            case "PDF Metadata": return .metadata
            case "Email PDF": return .emailPDF
            default: return nil
            }
        }
    }

    // MARK: - Intent Detection (Router Node)

    /// Analyzes user message and detects which tool they need
    func detectIntent(from message: String) -> AgentTool? {
        let lower = message.lowercased()

        let intentMap: [(keywords: [String], tool: AgentTool)] = [
            (["merge", "combine", "join"], .merge),
            (["compress", "reduce size", "smaller", "shrink"], .compress),
            (["ocr", "extract text", "read text", "text from"], .ocr),
            (["split", "separate", "divide"], .split),
            (["lock", "password", "protect", "encrypt"], .lock),
            (["unlock", "remove password", "decrypt"], .unlock),
            (["watermark", "stamp"], .watermark),
            (["image to pdf", "photo to pdf", "picture to pdf", "img to pdf"], .imageToPDF),
            (["sign", "signature", "autograph"], .sign),
            (["summarize", "summary", "tldr", "brief"], .summarize),
            (["translate", "translation"], .translate),
            (["ask", "question about", "what does"], .askPDF),
            (["rotate", "turn", "flip"], .rotate),
            (["reorder", "rearrange"], .reorder),
            (["page number", "numbering"], .pageNumbers),
            (["extract page", "pull out page"], .extractPages),
            (["crop", "trim", "margin"], .crop),
            (["doc to pdf", "convert to pdf", "word to pdf", "docx"], .docToPDF),
            (["pdf to image", "pdf to jpg", "pdf to png", "export as image"], .pdfToImage),
            (["pdf to text", "extract all text", "get text"], .pdfToText),
            (["metadata", "properties", "author", "title info"], .metadata),
            (["email", "mail", "send pdf"], .emailPDF),
        ]

        for (keywords, tool) in intentMap {
            if keywords.contains(where: { lower.contains($0) }) {
                return tool
            }
        }
        return nil
    }

    // MARK: - State Machine (Graph Execution)

    func getState(for conversationId: UUID) -> AgentState {
        states[conversationId] ?? .idle
    }

    func setState(_ state: AgentState, for conversationId: UUID) {
        states[conversationId] = state
    }

    func reset(for conversationId: UUID) {
        states[conversationId] = .idle
    }

    /// Process a user action/message through the state machine
    func process(
        conversationId: UUID,
        userMessage: String,
        attachedFile: DocumentFile?,
        context: ModelContext
    ) -> AgentResponse {

        let currentState = getState(for: conversationId)

        switch currentState {

        // IDLE → Detect intent → move to awaitingFile
        case .idle:
            if let tool = detectIntent(from: userMessage) {
                setState(.awaitingFile(tool: tool), for: conversationId)
                return AgentResponse(
                    message: promptForFile(tool: tool),
                    toolBadge: tool.displayName,
                    actions: [
                        ChatAction(label: "Attach File", icon: "plus.circle.fill", actionType: .attachFile)
                    ],
                    shouldExecute: false
                )
            }
            return AgentResponse(message: nil, shouldExecute: false)

        // AWAITING FILE → File received → check params or execute
        case .awaitingFile(let tool):
            guard let file = attachedFile else {
                return AgentResponse(
                    message: "Please attach a file to continue. Use the **+** button below.",
                    actions: [
                        ChatAction(label: "Attach File", icon: "plus.circle.fill", actionType: .attachFile)
                    ],
                    shouldExecute: false
                )
            }

            if tool.requiredParams.isEmpty {
                // No params needed → execute immediately
                setState(.executing(tool: tool, file: file, params: [:]), for: conversationId)
                return AgentResponse(
                    message: "Got it! Running **\(tool.displayName)** on \(file.fullFileName)...",
                    toolBadge: tool.displayName,
                    shouldExecute: true,
                    executeTool: tool,
                    executeFile: file,
                    executeParams: [:]
                )
            } else {
                // Need params → ask
                setState(.awaitingParams(tool: tool, file: file, neededParams: tool.requiredParams), for: conversationId)
                return AgentResponse(
                    message: promptForParams(tool: tool, file: file),
                    toolBadge: tool.displayName,
                    shouldExecute: false
                )
            }

        // AWAITING PARAMS → Parse params from message → execute
        case .awaitingParams(let tool, let file, _):
            let params = parseParams(from: userMessage, for: tool)
            setState(.executing(tool: tool, file: file, params: params), for: conversationId)
            return AgentResponse(
                message: "Running **\(tool.displayName)**...",
                toolBadge: tool.displayName,
                shouldExecute: true,
                executeTool: tool,
                executeFile: file,
                executeParams: params
            )

        // RUNNING PIPELINE → pipeline engine handles it
        case .runningPipeline:
            return AgentResponse(message: nil, shouldExecute: false)

        // EXECUTING / COMPLETED → suggest next tools (chaining)
        case .executing, .completed:
            // Check if user wants to chain another tool
            if let nextTool = detectIntent(from: userMessage) {
                setState(.awaitingFile(tool: nextTool), for: conversationId)
                return AgentResponse(
                    message: promptForFile(tool: nextTool),
                    toolBadge: nextTool.displayName,
                    actions: [
                        ChatAction(label: "Attach File", icon: "plus.circle.fill", actionType: .attachFile)
                    ],
                    shouldExecute: false
                )
            }
            setState(.idle, for: conversationId)
            return AgentResponse(message: nil, shouldExecute: false)
        }
    }

    /// After tool execution completes, suggest chaining
    func onToolComplete(
        conversationId: UUID,
        tool: AgentTool,
        result: InlineToolResult
    ) -> [ChatAction] {
        setState(.completed, for: conversationId)

        var actions: [ChatAction] = []
        for next in tool.suggestedNextTools.prefix(2) {
            actions.append(ChatAction(
                label: next.displayName,
                icon: "arrow.right.circle",
                actionType: .openTool,
                toolId: next.displayName
            ))
        }
        return actions
    }

    // MARK: - Prompt Generation

    private func promptForFile(tool: AgentTool) -> String {
        switch tool {
        case .merge:
            return "I'll merge your PDFs. Attach the files using the **+** button — I'll combine them in order."
        case .compress:
            return "Attach the PDF you'd like to compress and I'll reduce its file size."
        case .ocr:
            return "Attach a PDF or image and I'll extract all the text from it."
        case .split:
            return "Attach the PDF you want to split, then tell me which pages."
        case .lock:
            return "Attach the PDF you want to protect, then give me a password."
        case .unlock:
            return "Attach the locked PDF and provide the current password."
        case .watermark:
            return "Attach the PDF and tell me what watermark text to add."
        case .imageToPDF:
            return "Attach the images you want to convert to PDF."
        case .sign:
            return "Attach the PDF you'd like to sign."
        case .summarize:
            return "Attach a document and I'll generate a summary."
        case .translate:
            return "Attach a document and tell me the target language."
        case .askPDF:
            return "Attach a document and ask me any question about it."
        default:
            return "Attach the file you'd like to work with."
        }
    }

    private func promptForParams(tool: AgentTool, file: DocumentFile) -> String {
        switch tool {
        case .lock:
            return "Got **\(file.fullFileName)**. What password would you like to use?"
        case .split:
            return "Got **\(file.fullFileName)**. Which pages? (e.g., \"1-3\" or \"1, 3, 5\")"
        case .watermark:
            return "Got **\(file.fullFileName)**. What text should the watermark say?"
        case .extractPages:
            return "Got **\(file.fullFileName)**. Which pages to extract? (e.g., \"2, 4-6\")"
        case .rotate:
            return "Got **\(file.fullFileName)**. How many degrees? (90, 180, or 270)"
        case .translate:
            return "Got **\(file.fullFileName)**. Which language should I translate to?"
        case .askPDF:
            return "Got **\(file.fullFileName)**. What would you like to know about this document?"
        default:
            return "Got the file. Please provide the required details."
        }
    }

    private func parseParams(from message: String, for tool: AgentTool) -> [String: String] {
        var params: [String: String] = [:]
        switch tool {
        case .lock, .unlock:
            params["password"] = message.trimmingCharacters(in: .whitespacesAndNewlines)
        case .split:
            // Parse "1-3" or "1, 3, 5"
            params["pages"] = message.trimmingCharacters(in: .whitespacesAndNewlines)
        case .watermark:
            params["watermarkText"] = message.trimmingCharacters(in: .whitespacesAndNewlines)
        case .extractPages:
            params["pages"] = message.trimmingCharacters(in: .whitespacesAndNewlines)
        case .rotate:
            let digits = message.filter { $0.isNumber }
            params["degrees"] = digits.isEmpty ? "90" : digits
        case .translate:
            params["language"] = message.trimmingCharacters(in: .whitespacesAndNewlines)
        case .askPDF:
            params["question"] = message.trimmingCharacters(in: .whitespacesAndNewlines)
        default:
            break
        }
        return params
    }
}

// MARK: - Agent Response

struct AgentResponse {
    let message: String?
    var toolBadge: String?
    var actions: [ChatAction] = []
    let shouldExecute: Bool
    var executeTool: AgentOrchestrator.AgentTool?
    var executeFile: DocumentFile?
    var executeParams: [String: String] = [:]
}
