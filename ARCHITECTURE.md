# DocSage -- Architecture Documentation

## Table of Contents

1. [Overview](#overview)
2. [High-Level Architecture](#high-level-architecture)
3. [Layer Architecture](#layer-architecture)
4. [Navigation System](#navigation-system)
5. [AI Architecture](#ai-architecture)
6. [Service Layer](#service-layer)
7. [Models](#models)
8. [Feature Modules](#feature-modules)
9. [Design System](#design-system)
10. [Data Flow](#data-flow)
11. [Concurrency Model](#concurrency-model)
12. [Testing Strategy](#testing-strategy)
13. [File Organization Conventions](#file-organization-conventions)
14. [Key Design Decisions](#key-design-decisions)

---

## Overview

DocSage is a native iOS document management app built entirely in Swift with **zero third-party dependencies**. It follows MVVM architecture with `@Observable` ViewModels, uses SwiftData for persistence, and integrates Apple Foundation Models for on-device AI.

### Quick Stats

| Metric | Value |
|---|---|
| Swift source files | 172 |
| Lines of code | ~30,000 |
| Unit tests | 945 |
| Tools | 27+ |
| Agentic pipelines | 5 |
| Domain services | 18 |
| SwiftData models | 5 |
| PDF templates | 9 |
| Feature modules | 19 |
| UI components | 18 |
| Third-party deps | 0 |

---

## High-Level Architecture

```
┌──────────────────────────────────────────────────────────────────┐
│                         App Layer                                 │
│  DocGenieAIApp.swift — @main, SwiftData container, deep links,   │
│  Siri intents, TipKit config, appearance management               │
├──────────────────────────────────────────────────────────────────┤
│                        View Layer                                 │
│  SwiftUI Views organized by feature module                        │
│  (ChatTabView, FilesTabView, ToolsTabView, ScanReviewView, ...)  │
├──────────────────────────────────────────────────────────────────┤
│                      ViewModel Layer                              │
│  @Observable classes — UI state + service coordination            │
│  (ChatVM, FilesVM, PDFToolsVM, AIDocumentVM, ScanReviewVM, ...)  │
├──────────────────────────────────────────────────────────────────┤
│                   Agent Orchestrator                              │
│  Graph-based state machine for multi-step agentic workflows       │
│  27 tools | 5 pipelines | intent detection | per-conversation    │
├──────────────────────────────────────────────────────────────────┤
│                      Service Layer                                │
│  18 stateless singletons — domain operations                      │
│  (PDFTools, OCR, Scanner, AI, Storage, Import, Vault, ...)       │
├──────────────────────────────────────────────────────────────────┤
│                       Model Layer                                 │
│  SwiftData @Model: DocumentFile, ChatMessage, Conversation,       │
│  ChatMemory, DocumentFolder                                       │
│  Value types: ToolItem, FileCategory, ScanFilter, ChatAction, ... │
├──────────────────────────────────────────────────────────────────┤
│                    Apple Frameworks                                │
│  PDFKit, VisionKit, Vision, CoreImage, CoreGraphics,              │
│  FoundationModels, PencilKit, Speech, TipKit, AppIntents,         │
│  WidgetKit, LocalAuthentication, UserNotifications, MessageUI     │
└──────────────────────────────────────────────────────────────────┘
```

### Dependency Direction

```
Views ──→ ViewModels ──→ Services ──→ Apple Frameworks
  │            │              │
  │            │              └──→ Models (read/write)
  │            └──→ Models (via SwiftData @Query)
  └──→ Core (DesignSystem, Navigation, Extensions)
```

All dependencies flow downward. Views never call services directly — they go through ViewModels. Services have no knowledge of UI. Models are plain data containers.

---

## Layer Architecture

### 1. App Layer (`App/`)

The entry point of the application.

**`DocGenieAIApp.swift`** — the `@main` struct that configures:
- **SwiftData container** for 5 models: `DocumentFile`, `ChatMessage`, `Conversation`, `ChatMemory`, `DocumentFolder`
- **TipKit** initialization with immediate display frequency
- **Deep link handling** via `onOpenURL` for the `docsage://` URL scheme (scan, chat, tools)
- **Appearance management** via `@AppStorage("appAppearance")` — light, dark, or system
- **Siri Shortcuts** — 3 `AppIntent` definitions: `ScanDocumentIntent`, `AskDocSageIntent`, `OpenDocSageIntent`
- **`DocSageShortcuts`** — `AppShortcutsProvider` with natural language phrases

### 2. Core Layer (`Core/`)

Shared infrastructure consumed by all feature modules.

| Directory | Purpose |
|---|---|
| `DesignSystem/Theme/` | Design tokens — colors, typography, spacing, effects, animations, haptics |
| `DesignSystem/Components/` | 18 reusable UI components |
| `Navigation/` | `AppTab` enum (3 tabs), `AppTabView` (root container), `NavigationRouter` |
| `Extensions/` | `Date+Formatting`, `Int64+FileSize`, `String+FileExtension`, `Notification+App` |
| `Tips/` | TipKit tip definitions with event-driven display rules |
| `Utilities/` | `AppConstants` (app name, file limits, UTTypes), `UsageManager` (freemium gating) |

### 3. Features Layer (`Features/`)

19 self-contained feature modules, each with its own Views, ViewModels, and optionally local Services or Models.

| Module | Description |
|---|---|
| `AITools/` | Summarize, Ask, and Translate PDF via dual AI providers |
| `Chat/` | AI chat with streaming, memory, tool calling, agentic orchestration |
| `Converter/` | File format conversions (Image/Doc to PDF, PDF to Image/Text) |
| `Expiry/` | Document expiry date tracking with notification reminders |
| `Files/` | Document list, folder organization, search, tags, batch operations |
| `Import/` | File import flows (document picker, photo library) |
| `Menu/` | Tool grid / menu presentation |
| `Onboarding/` | 3-page animated onboarding with glow rings and badges |
| `PDFTools/` | 16 PDF manipulation tools (merge, split, sign, watermark, ...) |
| `Scanner/` | VisionKit camera scanning with filters, rotation, page management |
| `Settings/` | Preferences, appearance, memory management, about |
| `StructuredData/` | Structured data extraction from receipts/cards, export |
| `Templates/` | 9 professional PDF templates across 3 categories |
| `Tools/` | Tool launcher / routing hub |
| `Transfer/` | File transfer and sharing flows |
| `Tutorial/` | In-app tutorials and guides |
| `Vault/` | Biometric-locked secure document storage |
| `Viewer/` | PDF viewer with annotations, thumbnails, search |
| `WhatsNew/` | Version-gated feature announcement screen |

### 4. Services Layer (`Services/`)

18 stateless singleton services. See the [Service Layer](#service-layer) section for full details.

### 5. Model Layer (`Models/`)

SwiftData persistent models and value types. See the [Models](#models) section for full details.

---

## Navigation System

### Tab Structure

DocSage uses a 3-tab `TabView` as its root navigation:

```
DocGenieAIApp (@main)
└── AppTabView (root container)
    │
    ├── [Onboarding gate: @AppStorage("hasCompletedOnboarding")]
    │   └── OnboardingView — 3-page flow
    │
    ├── [Splash overlay: animated with pulsing icon]
    │
    ├── [What's New sheet: @AppStorage("lastWhatsNewVersion")]
    │   └── WhatsNewView — version-gated announcements
    │
    └── TabView (3 tabs)
        ├── Chat     → ChatTabView     → NavigationStack
        ├── Tools    → ToolsTabView    → NavigationStack
        └── Settings → SettingsView    → NavigationStack
```

### AppTab Enum

| Tab | Title | SF Symbol |
|-----|-------|-----------|
| `.chat` | Chat | `bubble.left.and.bubble.right` |
| `.tools` | Tools | `wrench.and.screwdriver` |
| `.settings` | Settings | `gearshape` |

### NavigationRouter

```swift
@Observable
final class NavigationRouter {
    var selectedTab: AppTab = .chat
    func resetCurrentTab() { /* scroll to top / pop to root */ }
}
```

Injected via `.environment(router)` and consumed by ViewModels for cross-tab navigation (e.g., AI says "Go to Tools tab").

### Sheet Presentations

Tool views are presented as sheets from `ChatTabView` via `ChatToolCoordinator`:

```swift
@Observable
final class ChatToolCoordinator {
    var activeTool: ToolItem?     // triggers .sheet(item:)
    var showScanner: Bool         // triggers .fullScreenCover
}
```

### Deep Linking

The `docsage://` URL scheme supports three routes:

| URL | Action |
|---|---|
| `docsage://scan` | Opens the document scanner |
| `docsage://chat` | Navigates to the Chat tab |
| `docsage://tools` | Navigates to the Tools tab |

### Onboarding Flow

A 3-page swipeable flow gated by `@AppStorage("hasCompletedOnboarding")`:

| Page | Icon | Title | Badges |
|------|------|-------|--------|
| 1 | `doc.viewfinder` | Scan & Digitize | Auto-Detect Edges, Multi-Page, PDF Export |
| 2 | `wrench.and.screwdriver` | 27+ Professional Tools | PDF Tools, AI Tools, Converters |
| 3 | `brain` | AI-Powered Assistant | Summarize, Ask PDF, Translate |

Features animated gradient backgrounds, layered glow rings, animated page dots, and Skip/Next/Get Started progression.

---

## AI Architecture

### Dual-Provider Strategy Pattern

```
AIService (singleton facade)
    │
    ├── activeBackend: .foundationModels | .keywordMatching
    │
    ├── FoundationModelsProvider (iOS 26+)
    │   ├── Uses SystemLanguageModel.default
    │   ├── LanguageModelSession with tools + instructions
    │   ├── Tool: SuggestToolDefinition (@Generable)
    │   ├── Tool: NavigateTabDefinition (@Generable)
    │   ├── Streaming via session.streamResponse(to:)
    │   ├── Action extraction from Transcript.ToolCalls
    │   └── Memory enrichment from ChatMemory
    │
    └── KeywordMatchingProvider (fallback, iOS 17+)
        ├── Keyword → response mapping
        ├── Static tool suggestions
        └── Simulated streaming delay
```

### Runtime Provider Selection

```swift
@MainActor @Observable
final class AIService {
    static let shared = AIService()

    private init() {
        #if canImport(FoundationModels)
        if #available(iOS 26, *) {
            let model = SystemLanguageModel.default
            if case .available = model.availability {
                self.provider = FoundationModelsProvider()
                self.activeBackend = .foundationModels
                return
            }
        }
        #endif
        self.provider = KeywordMatchingProvider()
        self.activeBackend = .keywordMatching
    }
}
```

The `AIResponseProvider` protocol abstracts the two backends:

```swift
protocol AIResponseProvider {
    var supportsStreaming: Bool { get }
    func generateResponse(for input: String, conversationHistory: [ChatMessage]) async throws -> AIResponse
    func streamResponse(for input: String, conversationHistory: [ChatMessage],
                        onPartialUpdate: @MainActor @Sendable (String) -> Void) async throws -> AIResponse
}
```

### Foundation Models Tool Calling

Two custom tools are defined for the LLM:

**`SuggestToolDefinition`** — recommends an app tool to the user:
```swift
@Generable struct Arguments {
    @Guide(description: "Tool ID") var toolId: String
    @Guide(description: "Button label") var label: String
}
```

**`NavigateTabDefinition`** — navigates to a tab:
```swift
@Generable struct Arguments {
    @Guide(description: "Tab: 'tools' or 'files'") var tabId: String
    @Guide(description: "Button label") var label: String
}
```

Tool calls extracted from the session transcript are converted to `ChatAction` objects displayed as tappable action buttons in chat messages.

### Agent Orchestrator (LangGraph-Inspired)

The `AgentOrchestrator` is a graph-based state machine managing multi-step agentic workflows:

```
State Graph:

  IDLE ──→ detectIntent() ──→ AWAITING_FILE ──→ file attached
    │                                                │
    │                                                ▼
    │                                          AWAITING_PARAMS
    │                                                │
    │                                          params parsed
    │                                                │
    │                                                ▼
    │                                            EXECUTING
    │                                                │
    │                                           completed
    │                                                │
    │                                                ▼
    └─────────────────────────────────────── COMPLETED ──→ chain next tool
```

Key capabilities:
- **Per-conversation state** — each conversation has independent agent state
- **Intent detection** — keyword matching routes to 27 tool types
- **Parameter parsing** — extracts passwords, page ranges, languages from user messages
- **Tool chaining** — suggests the next logical tool after completion (OCR -> Summarize -> Translate)
- **Conditional edges** — tools with no params execute immediately; others prompt for input
- **5 built-in pipelines**: scan-and-summarize, extract-and-translate, secure-pdf, extract-and-rewrite, extract-and-make-bullets

### AI Tools (Feature Module)

The `AIDocumentViewModel` provides three AI-powered document operations:

| Operation | Foundation Models (iOS 26+) | Keyword Matching Fallback |
|---|---|---|
| **Summarize PDF** | LLM generates 3-5 bullet-point summary | Word/line/character count + text preview |
| **Ask PDF** | LLM answers questions based on document context | Keyword search returning relevant excerpts |
| **Translate PDF** | LLM translates text chunks to target language | Not available (shows error) |

All three operations extract text via `OCRService` first, then process through the active AI provider.

### Conversation Memory

- Auto-extracts user preferences and facts from conversations
- Persists as `ChatMemory` in SwiftData across app restarts
- Injected into AI prompts for personalized responses
- Managed in Settings (view, delete, clear all)
- Max 50 memories with LRU eviction

---

## Service Layer

All services are `@MainActor` singletons with `static let shared` access. They are stateless — they perform operations and return results without maintaining persistent instance data.

### Main Services (`Services/`)

| Service | Key Methods | Purpose |
|---|---|---|
| `PDFToolsService` | `mergePDFs()`, `splitPDF()`, `compressPDF()`, `lockPDF()`, `unlockPDF()`, `extractPages()`, `rotatePDF()`, `reorderPDF()`, `addPageNumbers()`, `addWatermark()`, `signPDF()`, `cropPDF()`, `readMetadata()`, `writeMetadata()` | All PDF manipulation operations |
| `OCRService` | `recognizeText()`, `extractText()` | Vision framework text recognition |
| `ScannerService` | `applyFilter()`, `rotateImage()`, `generatePDF()`, `saveScanAsPDF()` | Scan image processing and PDF generation |
| `ConverterService` | `imagesToPDF()`, `documentToPDF()`, `pdfToImages()`, `pdfToText()`, `saveTextFile()` | File format conversions |
| `FileStorageService` | `importFile()`, `deleteFile()`, `renameFile()` | File system operations |
| `FileImportService` | `importFile()` | Orchestrates storage + metadata + SwiftData |
| `FileMetadataService` | `extractMetadata()` | File size, page count, dates |
| `ThumbnailService` | `thumbnail(for:)` | PDFKit thumbnails with NSCache (100 items / 50 MB) |
| `ShareService` | `shareFile()` | UIActivityViewController presentation |
| `VaultService` | `authenticate()`, `lockFile()`, `unlockFile()` | Biometric auth + secure storage |
| `AutoCategorizeService` | `categorize()` | Content-based file auto-categorization |
| `ExpiryNotificationService` | `scheduleReminder()`, `cancelReminder()` | Local notification reminders for expiring docs |
| `ChatExportService` | `exportAsPDF()` | Formatted conversation PDF export |
| `SpeechRecognitionService` | `startRecording()`, `stopRecording()` | Speech framework transcription |
| `StructuredDataExportService` | `export()` | Receipt/card data extraction and export |
| `SharedFileImportService` | `importSharedFile()` | Share Extension file import |
| `InlineChatToolExecutor` | `execute()` | Inline tool execution within chat |
| `WidgetDataService` | `getRecentFiles()`, `getStats()` | Data provider for WidgetKit |

### Chat-Specific Services (`Features/Chat/Services/`)

| Service | Purpose |
|---|---|
| `AIService` | Singleton facade — selects FoundationModels or KeywordMatching at runtime |
| `FoundationModelsProvider` | iOS 26+ LLM with streaming + tool calling |
| `KeywordMatchingProvider` | Fallback keyword-based responses |
| `ChatToolCoordinator` | Maps tool IDs to sheet presentations |
| `AgentOrchestrator` | Graph-based multi-step pipeline engine |

### PDFToolsService Detail

All methods are `async` and dispatch heavy PDF work to `DispatchQueue.global(qos: .userInitiated)`:

```swift
@MainActor
final class PDFToolsService {
    static let shared = PDFToolsService()

    func mergePDFs(from: [URL], outputName: String) async throws -> (url: URL, relativePath: String)
    func splitPDF(from: URL, startPage: Int, endPage: Int, outputName: String) async throws -> (url: URL, relativePath: String)
    func compressPDF(from: URL, level: CompressionLevel, outputName: String) async throws -> (url: URL, relativePath: String)
    func lockPDF(from: URL, password: String, outputName: String) async throws -> (url: URL, relativePath: String)
    func unlockPDF(from: URL, password: String, outputName: String) async throws -> (url: URL, relativePath: String)
    func extractPages(from: URL, pageIndices: [Int], outputName: String) async throws -> (url: URL, relativePath: String)
    func rotatePDF(from: URL, degrees: Int, outputName: String) async throws -> (url: URL, relativePath: String)
    func reorderPDF(from: URL, newOrder: [Int], outputName: String) async throws -> (url: URL, relativePath: String)
    func addPageNumbers(from: URL, outputName: String) async throws -> (url: URL, relativePath: String)
    func addWatermark(from: URL, text: String, outputName: String) async throws -> (url: URL, relativePath: String)
    func signPDF(from: URL, signatureImage: UIImage, pageIndex: Int, position: CGPoint, signatureSize: CGSize, outputName: String) async throws -> (url: URL, relativePath: String)
    func cropPDF(from: URL, top: CGFloat, bottom: CGFloat, left: CGFloat, right: CGFloat, outputName: String) async throws -> (url: URL, relativePath: String)
    nonisolated func readMetadata(from: URL) throws -> PDFMetadata
    func writeMetadata(to: URL, metadata: PDFMetadata, outputName: String) async throws -> (url: URL, relativePath: String)
}
```

---

## Models

### SwiftData Persistent Models

5 models registered in the SwiftData container:

```swift
// DocGenieAIApp.swift
.modelContainer(for: [DocumentFile.self, ChatMessage.self, Conversation.self, ChatMemory.self, DocumentFolder.self])
```

### Entity Relationships

```
DocumentFolder (1) ─── (*) DocumentFile
                            │ id: UUID (unique)
                            │ name: String
                            │ fileExtension: String
                            │ relativeFilePath: String
                            │ fileSize: Int64
                            │ pageCount: Int?
                            │ importedAt: Date
                            │ originalCreatedAt: Date?
                            │ originalModifiedAt: Date?
                            │ lastOpenedAt: Date?
                            │ isFavorite: Bool
                            │ tags: [FileTag]
                            │ expiryDate: Date?

Conversation (1) ────── (*) ChatMessage
    │ id: UUID                    │ conversationId: UUID
    │ title: String               │ content: String
    │ createdAt: Date             │ role: "user" | "assistant"
    │ updatedAt: Date             │ timestamp: Date
    │ isPinned: Bool              │ toolBadge: String?
                                  │ actionsJSON: String?

ChatMemory (standalone)
    │ id: UUID
    │ content: String
    │ createdAt: Date
```

Note: `ChatMessage` links to `Conversation` via a `conversationId: UUID` field rather than a SwiftData relationship, to avoid cascade delete complexity.

### Value Types

| Type | Kind | Purpose |
|---|---|---|
| `ToolItem` | enum (27 cases) | Tool definitions with icon, color, description, section |
| `FileCategory` | enum | Filter categories: all, pdf, doc, xls, ppt, txt, img |
| `FileTag` | enum (6 cases) | Work, Personal, Invoice, Receipt, Legal, Archive |
| `FileSortOption` | enum | Sort options: dateDesc, dateAsc, nameAsc, nameDesc, sizeDesc, typeAsc |
| `ViewerType` | enum | Viewer routing: pdf, image, quickLook |
| `ScanFilter` | enum | Image filters: color, grayscale, blackAndWhite, sharpen |
| `ScanContentType` | enum | Scan content type hints |
| `ScannedPage` | struct | Scan page: image + filter + rotation state |
| `ChatAction` | struct | Chat action button: label, icon, actionType, toolId/tabId |
| `InlineToolResult` | struct | Inline tool execution result |
| `PendingAttachment` | struct | File attachment pending in chat |

### ToolItem Sections

The `ToolItem` enum defines all 27 tools organized into 5 sections:

| Section | Count | Tools |
|---|---|---|
| **Scanner** | 1 | Scanner |
| **PDF Tools** | 16 | Merge, Split, Compress, Lock, Unlock, Extract Pages, Rotate, Reorder, Page Numbers, Watermark, Batch Process, OCR Text, Compare PDFs, Sign PDF, Crop, Metadata Editor |
| **Converters** | 4 | Image to PDF, Doc to PDF, PDF to Image, PDF to Text |
| **AI Tools** | 3 | Summarize PDF, Ask PDF, Translate PDF |
| **Utilities** | 3 | Templates, Email PDF, QR Share |

---

## Feature Modules

### Chat Feature

```
Features/Chat/
├── Services/
│   ├── AIResponseProvider.swift      # Protocol + AIResponse type
│   ├── AIService.swift               # Singleton facade, provider selection
│   ├── FoundationModelsProvider.swift # iOS 26+ implementation with tool calling
│   ├── KeywordMatchingProvider.swift  # Fallback implementation
│   └── ChatToolCoordinator.swift     # Tool sheet management + AgentOrchestrator
├── ViewModels/
│   └── ChatViewModel.swift           # Message/conversation/streaming/memory logic
└── Views/
    ├── ChatTabView.swift             # Main chat screen with greeting + suggestions
    ├── ChatBubbleView.swift          # Message bubble (user/assistant)
    ├── ChatInputBar.swift            # Text field + send + mic + attach
    ├── ChatActionButtonsView.swift   # Tappable action buttons in messages
    ├── ChatHistoryView.swift         # Conversation list with pinning
    └── QuickActionsView.swift        # Quick action suggestion chips
```

### Files Feature

```
Features/Files/
├── ViewModels/
│   ├── FilesViewModel.swift          # Search, filter, sort logic
│   └── FileActionsViewModel.swift    # CRUD operations (rename, delete, share, favorite)
└── Views/
    ├── FilesTabView.swift            # Main files screen (pull-to-refresh, skeleton)
    ├── FileListView.swift            # List with swipe actions + animations
    ├── FileRowView.swift             # Row with thumbnail + metadata
    ├── FileCategoryGridView.swift    # Category filter grid
    ├── FileActionsMenu.swift         # Context menu
    ├── FileDetailSheet.swift         # File info sheet
    └── FileRenameSheet.swift         # Rename dialog
```

### PDFTools Feature

```
Features/PDFTools/
├── ViewModels/
│   └── PDFToolsViewModel.swift       # All PDF tool operations
└── Views/
    ├── MergePDFView.swift            # Multi-file merge
    ├── SplitPDFView.swift            # Split by page range
    ├── CompressPDFView.swift         # Compression with level selection
    ├── LockPDFView.swift             # Password protection
    ├── UnlockPDFView.swift           # Password removal
    ├── ExtractPagesPDFView.swift     # Extract specific pages
    ├── RotatePDFView.swift           # Rotate pages
    ├── ReorderPDFView.swift          # Drag-to-reorder pages
    ├── PageNumbersPDFView.swift      # Add page numbers
    ├── WatermarkPDFView.swift        # Add text watermark
    ├── SignPDFView.swift             # Signature canvas placement
    ├── CropPDFView.swift             # Crop margins
    ├── MetadataEditorView.swift      # Edit PDF metadata
    ├── OCRTextView.swift             # Extract text via OCR
    ├── EmailPDFView.swift            # Email as attachment
    └── PDFFilePickerView.swift       # Shared file picker component
```

### Scanner Feature

```
Features/Scanner/
├── ViewModels/
│   └── ScanReviewViewModel.swift     # Page management, filters, rotation
└── Views/
    ├── ScanReviewView.swift          # Main scan review screen
    ├── ScanActionBar.swift           # Action buttons
    ├── ScanFilterBar.swift           # Filter selection (Color, Grayscale, B&W, Sharpen)
    ├── ScanPageManagerSheet.swift    # Page reordering
    ├── ScanPagePreview.swift         # Full-page preview
    ├── ScanPageStripView.swift       # Thumbnail strip
    └── ScanSaveSheet.swift           # Filename + save
```

### Templates Feature

```
Features/Templates/
├── Models/
│   └── DocumentTemplate.swift        # 9 templates + 3 categories + PDF generation
└── Views/
    └── TemplatePickerView.swift      # Template selection and generation UI
```

9 templates with full PDF generation via `UIGraphicsPDFRenderer`:
- **Business**: Invoice, Resume, Project Proposal, Report
- **Personal**: Meeting Notes, Formal Letter, Casual Letter
- **Legal**: NDA, Receipt

---

## Design System

### Theme Modules (`Core/DesignSystem/Theme/`)

| Module | Contents |
|---|---|
| **`AppColors`** | Semantic color palette: Primary (#6366F1 Indigo), Accent (#06B6D4 Cyan), Success (#10B981), Warning (#F59E0B), Danger (#EF4444). Background (#0F0F23), Card (#1A1A2E). Gradient definitions. |
| **`AppTypography`** | Font scale: H1 (28pt), H2 (22pt), H3 (17pt), Body (15pt), Caption (13pt), Micro (11pt). All SF system font with weight variants. |
| **`AppSpacing`** | Spacing scale: xs=4, sm=8, md=16, lg=24, xl=32, xxl=48. Corner radii: sm=8, md=12, lg=16, xl=20. |
| **`AppAnimations`** | Spring animations with configurable response/damping. Staggered appear modifier with index-based delays. |
| **`AppEffects`** | View modifiers: `.glassCard()` (frosted glass), `.glow(color:radius:)` (neon shadow), `.shimmer()` (animated gradient), `.confettiOnComplete(_:)` (particle overlay). |
| **`HapticManager`** | Unified haptic API: `.light()`, `.medium()`, `.success()`, `.error()`, `.selection()`. |

### Component Library (`Core/DesignSystem/Components/`)

18 reusable components:

| Component | Purpose |
|---|---|
| `AppCard` | Glass morphism container (`.glass`, `.solid` styles) |
| `PrimaryButton` | Gradient CTA with loading state |
| `SecondaryButton` | Outlined secondary action button |
| `GhostButton` | Minimal text button |
| `ScaleButtonStyle` | Press-to-scale tap feedback |
| `AnimatedCheckmark` | Animated success indicator + haptic |
| `AnimatedTransitions` | Custom transition modifiers |
| `ConfettiView` | Canvas particle system (60 particles, 9 colors) |
| `SkeletonView` | Shimmer loading placeholders |
| `EmptyStateView` | Icon + title + message + optional CTA |
| `FileTypeIcon` | Color-coded file type icons |
| `GlowingIcon` | Neon glow effect circle icon |
| `SparkleEffect` | Animated sparkle particles |
| `MeshGradientBackground` | Mesh gradient background view |
| `CategoryChip` | Filter chip with count badge |
| `TypingIndicator` | Animated 3-dot typing animation |
| `AppSearchBar` | Styled search input |
| `SortMenuButton` | Sort option picker menu |

### Effect Modifiers

| Modifier | Effect |
|---|---|
| `.glassCard()` | Frosted glass background with subtle border |
| `.glow(color:radius:)` | Neon glow shadow |
| `.shimmer()` | Animated shimmer gradient overlay |
| `.staggeredAppear(index:)` | Delayed fade-in based on position |
| `.confettiOnComplete(_:)` | Confetti overlay triggered by Bool binding |

---

## Data Flow

### Chat Message Flow

```
User types message
    │
    ▼
ChatViewModel.sendMessage()
    │
    ├── Insert user ChatMessage into SwiftData
    ├── Insert placeholder assistant ChatMessage
    ├── Enrich input with ChatMemory preferences
    ├── Call AIService.streamResponse()
    │       │
    │       ├── iOS 26+: FoundationModelsProvider
    │       │       ├── LanguageModelSession.streamResponse(to:)
    │       │       ├── Partial text updates → placeholder.content
    │       │       └── Extract tool calls → ChatActions
    │       │
    │       └── iOS 17-25: KeywordMatchingProvider
    │               ├── Keyword matching → response text
    │               └── Static tool suggestion → ChatActions
    │
    ├── Finalize placeholder with result text + actions
    ├── Auto-extract memory if preference detected
    └── Save to SwiftData
```

### File Import Flow

```
User picks file (DocumentPicker / PhotoLibrary / Share Extension)
    │
    ▼
FileImportService.importFile(from: URL)
    │
    ├── FileStorageService.importFile() → copy to app sandbox
    ├── FileMetadataService.extractMetadata() → size, page count, dates
    ├── OCRService.extractText() → build searchable index (background)
    ├── AutoCategorizeService.categorize() → assign category
    └── Create DocumentFile in SwiftData
```

### PDF Tool Flow

```
User selects files + configures tool options
    │
    ▼
PDFToolsViewModel.mergePDFs(urls: outputName: context:)
    │
    ├── isProcessing = true
    ├── PDFToolsService.shared.mergePDFs() → returns (URL, relativePath)
    ├── FileImportService.importFile(from: result) → save to SwiftData
    ├── didComplete = true → triggers confetti + animated checkmark
    └── isProcessing = false
```

### AI Tool Flow

```
User selects PDF + action (Summarize / Ask / Translate)
    │
    ▼
AIDocumentViewModel.summarizePDF(url:)
    │
    ├── OCRService.extractText(from: URL) → extract all text
    ├── Check AIService.shared.isOnDeviceAIAvailable
    │       │
    │       ├── true: AIService.generateResponse(for: prompt)
    │       │         → LLM-generated summary
    │       │
    │       └── false: generateBasicSummary(text:)
    │                  → Word/line count + preview
    │
    ├── resultText = response
    └── didComplete = true → triggers confetti
```

### Agentic Pipeline Flow

```
User says "scan and summarize"
    │
    ▼
AgentOrchestrator.detectIntent()
    │
    ├── Matches "scan-and-summarize" pipeline
    ├── State: IDLE → AWAITING_FILE
    │
    ▼ (user scans document)
    │
    ├── State: AWAITING_FILE → EXECUTING
    ├── Step 1: ScannerService → generate PDF
    ├── Step 2: OCRService → extract text
    ├── Step 3: AIService → summarize
    ├── State: EXECUTING → COMPLETED
    └── Display result + suggest next tool (e.g., Translate)
```

---

## Concurrency Model

### Swift 6 Strict Concurrency

The project uses Swift 6 with `SWIFT_STRICT_CONCURRENCY: "minimal"`:

- All ViewModels: `@MainActor @Observable`
- All Services: `@MainActor` singletons
- AI streaming callbacks: `@MainActor @Sendable` closures
- PDFToolsService: `async` methods dispatch heavy work to `DispatchQueue.global(qos: .userInitiated)`
- UI updates from async contexts: `Task { @MainActor in ... }`
- Batch image processing: `autoreleasepool` blocks

### Threading Strategy

```
Main Thread (@MainActor)
├── All SwiftUI Views
├── All ViewModels
├── AIService, ThumbnailService
├── SwiftData ModelContext operations
└── UI state mutations

Background (async / DispatchQueue.global)
├── PDFToolsService operations (merge, split, compress, sign, crop, ...)
├── ConverterService operations
├── ScannerService filter processing
├── OCRService text recognition (Vision framework)
├── Foundation Models LLM inference
└── Thumbnail generation
```

---

## Testing Strategy

### Test Suite: 945 tests, 0 failures

Tests are organized across multiple test files in the `DocGenieAITests` target.

### Coverage Areas

| Area | What's Tested |
|---|---|
| **Models** | DocumentFile properties, ChatMessage actions JSON encoding, Conversation model, ScannedPage |
| **Value Types** | FileCategory mapping, ViewerType resolution, ToolItem definitions/sections/icons, ScanFilter, FileSortOption |
| **Services** | FileStorageService (file I/O), ScannerService (filters, PDF gen, rotation), PDFToolsService (all 14 operations + error cases), ConverterService (all 4 conversions) |
| **ViewModels** | FilesViewModel (search, filter, sort), ScanReviewViewModel (page management), PDFToolsViewModel (state transitions), ConverterViewModel (state), ChatViewModel |
| **AI** | KeywordMatchingProvider (all keyword categories), AIService (backend selection, facade), AIResponse model |
| **Extensions** | String file extensions, Int64 file size formatting, Date formatting |
| **Utilities** | AppConstants validation |

### Testing Approach

- **Unit tests only** — no UI tests or snapshot tests
- **Services tested with real operations** — actual PDF manipulation, real file I/O
- **ViewModels tested via `@MainActor`** — verify state transitions
- **AI tested with keyword provider** — Foundation Models not available in simulator
- **All service tests use `async throws`**
- **Tests run against the `DocGenieAITests` target** linked to the main app target

---

## File Organization Conventions

### Naming

| Type | Convention | Example |
|---|---|---|
| Views | `<Feature><Purpose>View.swift` | `MergePDFView.swift`, `ChatBubbleView.swift` |
| ViewModels | `<Feature>ViewModel.swift` | `ChatViewModel.swift`, `FilesViewModel.swift` |
| Services | `<Domain>Service.swift` | `PDFToolsService.swift`, `OCRService.swift` |
| Models | `<Entity>.swift` | `DocumentFile.swift`, `ToolItem.swift` |
| Extensions | `<Type>+<Purpose>.swift` | `Date+Formatting.swift`, `Int64+FileSize.swift` |
| UIKit bridges | `<Name>View.swift` in `Representables/` | `DocumentCameraView.swift`, `SignatureCanvasView.swift` |
| Design tokens | `App<Token>.swift` | `AppColors.swift`, `AppTypography.swift` |
| Components | `<Name>.swift` in `Components/` | `AppCard.swift`, `ConfettiView.swift` |

### Feature Module Structure

Each feature module follows this structure (not all directories are required):

```
Features/<FeatureName>/
├── Models/          # Feature-local models (optional)
├── Services/        # Feature-local services (optional)
├── ViewModels/      # @Observable ViewModels
└── Views/           # SwiftUI views
```

### Import Ordering

1. SwiftUI / UIKit
2. SwiftData
3. Apple frameworks (PDFKit, Vision, etc.)
4. `#if canImport(FoundationModels)` guarded imports

---

## Key Design Decisions

### 1. Zero Dependencies

All functionality uses Apple frameworks only: PDFKit, VisionKit, CoreImage, Vision, CoreText, CoreGraphics, FoundationModels, TipKit, MessageUI, LocalAuthentication, WidgetKit, Speech. This eliminates dependency management, reduces app size, ensures long-term stability, and simplifies App Store review.

### 2. Strategy Pattern for AI

The `AIResponseProvider` protocol allows swapping AI implementations without changing any View or ViewModel code. This enabled a clean fallback from Foundation Models to keyword matching, and the same pattern powers `AIDocumentViewModel` for the AI tools feature.

### 3. SwiftData over Core Data

SwiftData provides a simpler, more Swift-native API with `@Model` macros and `@Query` property wrappers that integrate directly into SwiftUI. The trade-off is an iOS 17 minimum deployment target.

### 4. UUID-based Message Linking

`ChatMessage` links to `Conversation` via a `conversationId: UUID` field rather than a SwiftData relationship. This avoids cascade delete complexity, simplifies queries, and prevents SwiftData relationship graph issues.

### 5. Graph-Based Agent Orchestrator

Instead of a simple if/else command router, the agent uses a state machine with explicit states and transitions. This makes multi-step pipelines declarative, enables conditional routing and error recovery, and keeps the orchestration logic testable.

### 6. Singleton Services

Services are stateless singletons because they don't own data — they perform operations and return results. This keeps them simple, testable, and avoids dependency injection complexity for a single-target app.

### 7. @Observable over Combine

Using the `@Observable` macro (iOS 17+) instead of `ObservableObject` + `@Published` eliminates Combine boilerplate and enables more granular view updates (only views reading changed properties re-render).

### 8. Compile-Time AI Availability

`#if canImport(FoundationModels)` combined with `@available(iOS 26, *)` and a runtime `SystemLanguageModel.default.availability` check ensures the app compiles and runs on iOS 17+ while only using Foundation Models when actually available at runtime.

### 9. XcodeGen for Project Generation

The Xcode project is generated from `project.yml` via XcodeGen, avoiding merge conflicts in `.xcodeproj` files and making the project configuration declarative and version-control friendly.

### 10. Feature-Based Module Organization

Code is organized by feature (Chat, Scanner, PDFTools, Vault) rather than by type (Views, ViewModels, Services). This improves discoverability and keeps related code co-located. Shared infrastructure lives in `Core/`.

### 11. Freemium with Daily Limits

The `UsageManager` implements a freemium model with per-day usage limits tracked in `UserDefaults`. Free tier limits: 5 tool uses, 3 conversations, 2 voice notes, 1 pipeline, 50 MB max file size. Pro unlocks unlimited usage. Daily counters auto-reset at midnight.

### 12. UIKit Bridges via Representables

7 `UIViewControllerRepresentable` wrappers bridge essential UIKit APIs (VNDocumentCamera, UIDocumentPicker, MFMailCompose, PDFView, QLPreview, UIActivityViewController, custom signature canvas) into SwiftUI. This keeps the SwiftUI-first approach while accessing UIKit-only capabilities.
