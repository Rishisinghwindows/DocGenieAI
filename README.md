<p align="center">
  <img src="DocGenieAI/Resources/Assets.xcassets/AppIcon.appiconset/icon.png" width="120" alt="DocSage Icon" />
</p>

<h1 align="center">DocSage</h1>

<p align="center">
  <strong>Your AI-Powered Document Assistant for iOS</strong>
</p>

<p align="center">
  Scan, manage, and transform documents with 27+ built-in tools and on-device AI — no cloud, no third-party APIs, no compromises on privacy.
</p>

<p align="center">
  <img src="https://img.shields.io/badge/platform-iOS%2017%2B-blue?style=flat-square" alt="Platform" />
  <img src="https://img.shields.io/badge/swift-6.0-orange?style=flat-square" alt="Swift" />
  <img src="https://img.shields.io/badge/UI-SwiftUI-purple?style=flat-square" alt="SwiftUI" />
  <img src="https://img.shields.io/badge/dependencies-zero-brightgreen?style=flat-square" alt="Zero Dependencies" />
  <img src="https://img.shields.io/badge/tests-945-green?style=flat-square" alt="Tests" />
</p>

<p align="center">
  <a href="#features">Features</a> &bull;
  <a href="#tech-stack">Tech Stack</a> &bull;
  <a href="#architecture">Architecture</a> &bull;
  <a href="#getting-started">Getting Started</a> &bull;
  <a href="#project-structure">Project Structure</a> &bull;
  <a href="#contributing">Contributing</a>
</p>

---

## At a Glance

```
172 Swift source files  |  ~30K lines of code
945 unit tests          |  0 failures
27+ document tools      |  5 multi-step pipelines
9 PDF templates         |  18 domain services
Zero third-party deps   |  100% Apple frameworks
```

---

## Overview

DocSage (internal codename: DocGenieAI) is a native iOS app that puts a complete document workflow in your pocket. From scanning paper documents with your camera to merging, signing, and compressing PDFs, everything runs locally on your device.

On iOS 26+, Apple Foundation Models power an AI chat assistant that can reason over your documents, execute multi-step agentic pipelines, and answer questions — all without sending a single byte off-device. On iOS 17-25, a keyword-matching fallback engine ensures core AI features still work.

---

## Features

### AI Chat & Agentic Workflows

- Conversational document assistant powered by **Apple Foundation Models** (iOS 26+)
- Keyword-matching fallback engine for iOS 17-25
- Graph-based **Agent Orchestrator** (LangGraph-inspired) for multi-step pipelines
- 5 built-in pipelines: scan-and-summarize, extract-and-translate, secure-pdf, extract-and-rewrite, extract-and-make-bullets
- Streaming responses, persistent conversation memory, and contextual tool calling
- Smart text actions: Formal, Casual, Fix Grammar, Bullet Points, Expand
- Siri Shortcuts integration ("Scan with DocSage", "Ask DocSage", "Open DocSage")

### Document Scanner

- VisionKit-powered camera scanning with auto edge detection
- 4 scan filters: Color, Grayscale, Black & White, Sharpen
- Rotate, delete, and reorder scanned pages
- Batch scanning with direct PDF generation
- Receipt and business card auto-detection with structured data extraction

### 27+ Built-in Tools

| Category | Tools |
|---|---|
| **Scanner** | Document Scanner |
| **PDF Tools** | Merge, Split, Compress, Lock, Unlock, Extract Pages, Rotate, Reorder Pages, Page Numbers, Watermark, Batch Process, OCR Text, Compare PDFs, Sign PDF, Crop, Metadata Editor |
| **Converters** | Image to PDF, Doc to PDF, PDF to Image, PDF to Text |
| **AI Tools** | Summarize PDF, Ask PDF, Translate PDF |
| **Utilities** | Templates, Email PDF, QR Share |

### AI-Powered Document Tools

- **Summarize PDF** — LLM-generated bullet-point summaries (or word/line stats on fallback)
- **Ask PDF** — conversational Q&A against document content
- **Translate PDF** — translate extracted text to any target language

### Smart Document Management

- Auto-categorization by file type and content
- Structured data extraction from receipts and business cards
- Full-text OCR powered by Apple Vision framework
- 6 file tags: Work, Personal, Invoice, Receipt, Legal, Archive
- Folders, favorites, search by name or content
- Batch operations (multi-select, share, delete)
- Sort by date, name, size, or type

### Secure Vault

- Biometric-protected document storage (Face ID / Touch ID)
- Separate encrypted area for sensitive files

### Document Expiry Tracking

- Set expiration dates on documents (licenses, contracts, IDs)
- Local notification reminders before documents expire

### Templates

9 professional PDF templates across 3 categories:

| Business | Personal | Legal |
|---|---|---|
| Invoice | Meeting Notes | NDA |
| Resume | Formal Letter | Receipt |
| Project Proposal | Casual Letter | |
| Report | | |

### Voice Notes

- Tap to record with live speech transcription
- Auto-saves as `.m4a` document + posts transcription in chat
- Actions: Summarize, Formal Rewrite, Bullets, Copy, Share

### PDF Viewer

- Page navigation with floating bottom bar
- Thumbnail grid (3-column, tap to jump)
- In-document search
- PencilKit annotations (pen, highlighter, eraser + 5 colors)
- Document info panel (metadata, page count, file size)

### Widgets & Extensions

- Home screen widgets via WidgetKit (recent documents, quick actions, statistics)
- Share Extension for importing documents from any app
- Deep linking (`docsage://scan`, `docsage://chat`, `docsage://tools`)

### Additional Highlights

- Drag & drop file import onto any tab
- Pinned conversations with swipe gestures
- Export chat as formatted PDF with timestamps
- 3-page animated onboarding with glow rings
- What's New version-based announcement screen
- Contextual tips via TipKit
- Confetti animation on tool completion
- Full VoiceOver accessibility
- Haptic feedback on all interactions
- Light / Dark / System appearance toggle
- Freemium model with daily usage limits (Pro unlocks unlimited)

---

## Tech Stack

| Layer | Technology |
|---|---|
| **Language** | Swift 6.0 (strict concurrency) |
| **UI** | SwiftUI, iOS 17+ |
| **Architecture** | MVVM + `@Observable` |
| **Data** | SwiftData (DocumentFile, ChatMessage, Conversation, ChatMemory, DocumentFolder) |
| **AI** | Apple Foundation Models (iOS 26+), keyword-matching fallback |
| **Orchestration** | Custom graph-based agent state machine (LangGraph-inspired) |
| **PDF** | PDFKit, UIGraphicsPDFRenderer, CoreGraphics |
| **Scanning** | VisionKit (`VNDocumentCameraViewController`) |
| **OCR** | Apple Vision (`VNRecognizeTextRequest`) |
| **Annotations** | PencilKit |
| **Voice** | Speech framework + AVAudioRecorder |
| **Notifications** | UserNotifications (expiry reminders) |
| **Intents** | AppIntents, Siri Shortcuts |
| **Widgets** | WidgetKit |
| **Auth** | LocalAuthentication (biometrics) |
| **Tips** | TipKit |
| **Project Gen** | XcodeGen (`project.yml`) |
| **3rd-party deps** | **None** — 100% Apple frameworks |

---

## Architecture

DocSage follows a layered MVVM architecture with clear separation of concerns:

```
┌─────────────────────────────────────────────────────────┐
│                     SwiftUI Views                        │
│   (ChatTabView, FilesTabView, ToolsTabView, ...)        │
├─────────────────────────────────────────────────────────┤
│                ViewModels (@Observable)                   │
│   (ChatVM, FilesVM, PDFToolsVM, AIDocumentVM, ...)      │
├─────────────────────────────────────────────────────────┤
│              Agent Orchestrator (Graph Engine)            │
│   27 tools | 5 pipelines | intent detection | state      │
├─────────────────────────────────────────────────────────┤
│                 Services (18 Singletons)                  │
│   PDFTools, OCR, Scanner, AI, Storage, Import, Vault...  │
├─────────────────────────────────────────────────────────┤
│             Models (SwiftData @Model + Enums)            │
│   DocumentFile, Conversation, ChatMessage, ChatMemory    │
├─────────────────────────────────────────────────────────┤
│                   Apple Frameworks                        │
│   PDFKit, Vision, VisionKit, PencilKit, Speech,          │
│   FoundationModels, TipKit, AppIntents, WidgetKit        │
└─────────────────────────────────────────────────────────┘
```

For the full architectural breakdown — including data flow diagrams, AI dual-provider strategy, design system documentation, navigation architecture, concurrency model, and design decisions — see **[ARCHITECTURE.md](ARCHITECTURE.md)**.

---

## Screenshots

<!-- Add screenshots here -->
| Chat | Tools | Scanner | PDF Viewer | Vault |
|:----:|:-----:|:-------:|:----------:|:-----:|
| *coming soon* | *coming soon* | *coming soon* | *coming soon* | *coming soon* |

---

## Requirements

| Requirement | Minimum |
|---|---|
| **iOS** | 17.0 |
| **Xcode** | 26.0 |
| **Swift** | 6.0 |
| **Device** | iPhone (portrait + landscape) |
| **AI features** | iOS 26+ with Apple Foundation Models support |

---

## Getting Started

### Prerequisites

- macOS with Xcode 26+ installed
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`)

### Build & Run

```bash
# 1. Clone the repository
git clone https://github.com/your-org/DocGenieAI.git
cd DocGenieAI

# 2. Generate the Xcode project from project.yml
xcodegen generate

# 3. Open in Xcode
open DocGenieAI.xcodeproj

# 4. Select an iPhone simulator and press Cmd+R
```

Or build from the command line:

```bash
xcodegen generate

xcodebuild build \
  -project DocGenieAI.xcodeproj \
  -scheme DocGenieAI \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro'
```

### Run Tests

```bash
xcodebuild test \
  -project DocGenieAI.xcodeproj \
  -scheme DocGenieAI \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro'

# Expected: 945 tests, 0 failures
```

---

## Project Structure

```
DocGenieAI/
├── project.yml                          # XcodeGen project definition
├── README.md
├── ARCHITECTURE.md
│
├── DocGenieAI/                          # Main app target (172 Swift files)
│   ├── App/
│   │   ├── DocGenieAIApp.swift          # @main, SwiftData container, deep links, Siri intents
│   │   └── Info.plist
│   │
│   ├── Core/
│   │   ├── DesignSystem/
│   │   │   ├── Theme/                   # AppColors, AppTypography, AppSpacing,
│   │   │   │                            #   AppEffects, AppAnimations, HapticManager
│   │   │   └── Components/              # 18 reusable UI components (buttons, cards,
│   │   │                                #   search bar, skeleton, confetti, glow, ...)
│   │   ├── Navigation/                  # AppTab, AppTabView, NavigationRouter
│   │   ├── Extensions/                  # Date, Int64, String, Notification helpers
│   │   ├── Tips/                        # TipKit definitions
│   │   └── Utilities/                   # Constants, UsageManager (freemium gating)
│   │
│   ├── Features/
│   │   ├── AITools/                     # Summarize, Ask, Translate PDF
│   │   ├── Chat/                        # AI chat with agentic workflows
│   │   │   ├── Services/                #   AIService, FoundationModelsProvider,
│   │   │   │                            #   KeywordMatchingProvider, ChatToolCoordinator,
│   │   │   │                            #   AgentOrchestrator
│   │   │   ├── ViewModels/              #   ChatViewModel
│   │   │   └── Views/                   #   ChatTabView, ChatBubble, InputBar, History, ...
│   │   ├── Converter/                   # Image/Doc to PDF, PDF to Image/Text
│   │   ├── Expiry/                      # Document expiry tracking & reminders
│   │   ├── Files/                       # Document list, folders, search, tags
│   │   ├── Import/                      # File import flows
│   │   ├── Menu/                        # Tool grid / menu
│   │   ├── Onboarding/                  # 3-page animated onboarding
│   │   ├── PDFTools/                    # Merge, split, compress, lock, sign, watermark, ...
│   │   ├── Scanner/                     # VisionKit camera scanning + review
│   │   ├── Settings/                    # Preferences, appearance, memory, about
│   │   ├── StructuredData/              # Structured data extraction & export
│   │   ├── Templates/                   # 9 PDF templates (Invoice, Resume, NDA, ...)
│   │   ├── Tools/                       # Tool launcher / routing
│   │   ├── Transfer/                    # File transfer / sharing
│   │   ├── Tutorial/                    # In-app tutorials
│   │   ├── Vault/                       # Biometric-locked secure storage
│   │   ├── Viewer/                      # PDF & document viewer with annotations
│   │   └── WhatsNew/                    # Version-based changelog screen
│   │
│   ├── Models/                          # SwiftData models + value types
│   │   ├── DocumentFile.swift           #   @Model — files with tags, folders, expiry
│   │   ├── ChatMessage.swift            #   @Model — messages with actions JSON
│   │   ├── Conversation.swift           #   @Model — conversations with pinning
│   │   ├── DocumentFolder.swift         #   @Model — folder organization
│   │   ├── ToolItem.swift               #   Enum — 27 tool definitions
│   │   └── ...                          #   FileCategory, ScanFilter, ViewerType, etc.
│   │
│   ├── Representables/                  # 7 UIKit bridge views
│   │   ├── DocumentCameraView.swift     #   VNDocumentCameraViewController
│   │   ├── SignatureCanvasView.swift     #   Custom signature drawing
│   │   ├── PDFKitView.swift             #   PDFView wrapper
│   │   ├── MailComposerView.swift       #   MFMailComposeViewController
│   │   └── ...                          #   DocumentPicker, QuickLook, ActivityView
│   │
│   ├── Resources/                       # Assets, colors, app icon
│   └── Services/                        # 18 domain services
│       ├── PDFToolsService.swift        #   All PDF operations (merge, split, sign, ...)
│       ├── OCRService.swift             #   Vision-based text recognition
│       ├── ScannerService.swift         #   Scan filters, rotation, PDF generation
│       ├── FileStorageService.swift      #   File system operations
│       ├── VaultService.swift           #   Biometric auth + secure storage
│       ├── AutoCategorizeService.swift  #   Content-based file categorization
│       ├── ExpiryNotificationService.swift  # Expiry date reminders
│       └── ...                          #   Converter, Import, Metadata, Share, etc.
│
├── DocSageWidget/                       # WidgetKit extension
│   ├── DocSageWidget.swift
│   ├── DocSageWidgetBundle.swift
│   └── Info.plist
│
├── DocSageShare/                        # Share Extension
│   ├── ShareViewController.swift
│   └── Info.plist
│
└── DocGenieAITests/                     # 945 unit tests
```

---

## Supported File Types

| Category | Formats |
|---|---|
| **Documents** | PDF, DOC, DOCX, XLS, XLSX, PPT, PPTX, TXT, CSV, XML, RTF |
| **Images** | JPG, JPEG, PNG, HEIC, WebP, BMP, GIF, TIFF |
| **Max file size** | 500 MB (Pro), 50 MB (Free) |

---

## Sample Chat Queries

| Say this | What happens |
|---|---|
| "compress this pdf" | Picker opens, auto-compress, result in chat |
| "extract text" | Picker opens, OCR runs, text appears in chat |
| "scan and summarize" | Scanner opens, OCR + AI summary (2-step pipeline) |
| "secure this pdf" | Picker opens, compress + watermark (pipeline) |
| "lock with password" | Picker opens, asks password, locks PDF |
| "I prefer formal tone" | Saved to memory, used in future conversations |
| "merge my PDFs" | Multi-file picker opens, merge, result in chat |

---

## Design System

Dark theme with consistent design tokens:

| Token | Value |
|---|---|
| **Primary** | `#6366F1` (Indigo) |
| **Accent** | `#06B6D4` (Cyan) |
| **Success** | `#10B981` (Emerald) |
| **Warning** | `#F59E0B` (Amber) |
| **Danger** | `#EF4444` (Red) |
| **Background** | `#0F0F23` (Deep Navy) |
| **Typography** | H1 (28pt) through Micro (11pt) — SF system font |
| **Spacing** | xs(4) sm(8) md(16) lg(24) xl(32) xxl(48) |

18 reusable components including glass-morphism cards, animated checkmarks, confetti particles, skeleton loaders, glow effects, and typing indicators.

---

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/my-feature`)
3. Make your changes and ensure all 945 tests pass
4. Commit with a descriptive message
5. Push to your fork and open a Pull Request

### Code Style

- Swift 6 strict concurrency (`@MainActor`, `Sendable`)
- SwiftUI-first — UIKit only via `UIViewControllerRepresentable` wrappers
- No third-party dependencies — keep it that way
- Feature modules are self-contained (Views + ViewModels + local Services)
- All ViewModels use `@Observable` (not Combine `ObservableObject`)
- `@Query` in views for reactive SwiftData fetching

---

## License

This project is licensed under the MIT License. See [LICENSE](LICENSE) for details.

---

<p align="center">
  Built entirely with SwiftUI and Apple frameworks.<br/>
  <strong>DocSage</strong> — Every document, one tap away.
</p>
