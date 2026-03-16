# Changelog

All notable changes to DocSage are documented in this file.

---

## [2.3.0] -- 2026-03-15 -- Voice Notes & Complete Feature Set

### Added
- **Voice Notes** — tap mic → record with live transcription (AVAudioRecorder + SFSpeechRecognizer) → auto-save as .m4a document → post transcription in chat with [Summary] [Formal] [Bullets] [Copy] [Share] actions. Audio duration tracked. Transcription stored as ocrTextCache for search.

---

## [2.2.0] -- 2026-03-15 -- Full Agentic Completion

### Completed (previously partial)
- **Receipt/Card Parser wired into scan flow** — scan a receipt → structured data (vendor, date, items, total) shown in chat. Scan a business card → name, email, phone, company extracted automatically.
- **All text actions on document cards** — OCR, Summary, Formal, Casual, Grammar, Bullets, Expand, Compress, Watermark, Share (10 actions)
- **Search scope toggle in Files** — segmented picker: Name / Content / All (visible when searching)
- **Tag filter chips in Files** — horizontal scroll with All + 6 colored tag chips (Work, Personal, Invoice, Receipt, Legal, Archive)
- **9 tools auto-execute inline** — Compress, OCR, Summarize, Watermark + Page Numbers, Rotate, PDF to Text, PDF to Image, Doc to PDF
- **OCR text stored on scan** — `runBackgroundOCR` now saves `ocrTextCache` on DocumentFile for search

### Added
- **5 new inline tool executors**: Page Numbers, Rotate (90°), PDF to Text, PDF to Image (JPG), Doc to PDF
- **Sample queries** in README showing 12 example commands
- **Multi-step pipeline engine** — "scan and summarize", "extract and translate", "secure this pdf" run as automated multi-step workflows

---

## [2.1.0] -- 2026-03-15 -- Smart Features & Code Audit

### Added
- **Smart Text Actions** — 5 inline tools: rewrite formal/casual, fix grammar, bullet points, expand text
- **Smart Document Search** — search across all documents by OCR content, not just filename. Background OCR on import.
- **Receipt Parser** — auto-detects receipts, extracts vendor/date/items/subtotal/tax/total
- **Business Card Parser** — auto-detects cards, extracts name/company/email/phone/website
- **Auto-Execute Pipeline** — tools that don't need params (Compress, OCR, Summarize, Watermark) run automatically after file attachment
- **Tool Chaining** — after tool completion, suggests next logical tool (OCR→Summarize→Translate)

### Removed (Dead Code Cleanup)
- **SideMenuView.swift** (330 lines) — unused since tab-bar architecture adopted
- **SettingsTabPlaceholder.swift** (219 lines) — replaced by SettingsTabView
- **ToolsGridSheet.swift** (68 lines) — duplicate of ToolsTabView
- Total: **617 lines** of dead code removed

### Fixed
- **Force unwrap** in FileStorageService.swift → replaced with guard
- **Force try** in ScanContentType.swift receipt/card parsers → replaced with try?
- **Unused `.chaining` state** removed from AgentOrchestrator state machine
- **Unused variable** warning in ScanContentType.parseReceipt()

### Test Results
- 945 tests, 0 failures
- 77 new tests added this session (from 871 → 945)
- Covers: Agent Orchestrator, Chat Export, Receipt/Card Parsers, Smart Search, Text Actions, File Tags, Pinned Conversations

---

## [2.0.0] -- 2026-03-15 -- Agentic Architecture & Complete Redesign

### Renamed
- **DocGenie AI → DocSage** — new brand across all user-facing strings, Info.plist, legal pages, AI prompts, and accessibility labels. Internal project structure (`DocGenieAI`) preserved for migration safety.

### Added — Agentic Architecture
- **AgentOrchestrator** — LangGraph-style state machine for multi-step tool workflows. States: idle → awaitingFile → awaitingParams → executing → completed → chaining.
- **Intent Detection** — keyword-based router maps user messages to 17 tool types
- **Agentic Tool Flow** — Merge, Compress, OCR, Split, Lock, Watermark, Image to PDF, Sign now execute conversationally in chat instead of opening separate sheet UIs
- **Tool Chaining** — after completion, suggests next logical tool (OCR → Summarize → Translate)
- **Parameter Parsing** — extracts passwords, page ranges, languages from user messages

### Added — Features
- **Siri App Shortcuts** — "Scan with DocSage", "Ask DocSage", "Open DocSage" via AppIntents
- **Drag & Drop** — accept files on Files tab and Chat tab via `.dropDestination`
- **Batch Operations** — multi-select files with checkboxes, batch share/delete with action bar
- **PDF Annotations** — PencilKit overlay with pen, highlighter, eraser + 5 color picker
- **Export Chat as PDF** — formatted conversation export via ChatExportService
- **Pinned Conversations** — swipe to pin/unpin, pinned section in chat history
- **File Tags** — 6 preset color-coded tags (Work, Personal, Invoice, Receipt, Legal, Archive) via FileActionsMenu
- **Smart Conversation Titles** — ConversationTitleGenerator strips filler words, capitalizes, truncates at word boundary
- **Recent Files Strip** — shows 3 recently opened files as tappable chips during chat conversations
- **Attach File action** — `.attachFile` ChatActionType triggers attachment dialog from chat bubbles

### Changed — UX Redesign (ChatGPT/Gemini-style)
- **Welcome Screen** — time-based greeting ("Good morning/afternoon/evening"), sparkles icon with glow rings, gradient text, 2x2 color-coded suggestion grid
- **Suggestion Cards** — unique accent colors per card (Scan=cyan, Merge=purple, Convert=orange, OCR=green) with gradient borders and shadows
- **Input Bar** — floating pill design with rounded corners, shadow, minimal "Message" placeholder
- **Navigation Bar** — hidden on welcome screen for immersive feel; custom top bar with hamburger + compose icons
- **Tab Bar** — improved inactive contrast with UITabBarAppearance (gray-blue inactive vs indigo active)
- **AI Engine Badge** — changed from yellow warning to neutral gray for "Keyword" fallback
- **Chat History Badge** — changed from primary color to muted gray (doesn't look like notification)
- **Settings Header** — compact with smaller icon and "v1.0" instead of full version + build
- **Search Bars** — contextual placeholders: "Search tools..." (Tools), "Search files..." (Files)
- **Tool Result Badge** — shows tool type instead of duplicating result title

### Fixed
- **Share File action** — now opens share sheet with actual file (was navigating to Settings)
- **Open File action** — now opens file directly (was navigating to Settings)
- **Scanner → Chat** — scans from Tools tab now post to chat thread via toolDidProduceDocument notification
- **CoreData migration** — `Conversation.isPinned` uses default value `false` for existing records
- **Accessibility** — added labels/hints to WelcomeSuggestionCard, section headers in Tools tab

### Test Results
- 871 tests, 0 failures
- 70.8% line coverage (target: 80%+)
- 8 new ConversationTitleGenerator tests

---

## [1.2.0] -- 2026-03-13 -- Professional Polish & Discoverability

### Added
- **Programmatic App Icon** -- Professional 1024x1024 app icon generated entirely via CoreGraphics (`AppIconGenerator`). Dark gradient background with document shape, fold corner, text lines, and 4 AI sparkles with glow halos. No external design tools required.
- **Enhanced Onboarding** -- Complete redesign of the 3-page onboarding flow with layered glow rings (outer radial gradient + inner gradient circle), feature badges as capsule pills, animated gradient backgrounds that change per page, and pulsing SF Symbol icons via `.symbolEffect(.pulse)`.
- **TipKit Integration** -- 3 contextual tips with event-driven display rules:
  - `TryAIToolsTip` -- shown on first visit to the Tools tab
  - `ChatWelcomeTip` -- shown on first visit to the Chat tab
  - `ScanCompleteTip` -- shown after the first completed scan
- **What's New Screen** -- Version-based announcement system via `WhatsNewView`. Gated by `@AppStorage("lastWhatsNewVersion")`. Features displayed as staggered glass morphism cards with `GlowingIcon`. Currently ships with data for version 1.1 (AI Tools Suite, Sign Documents, Crop & Metadata, Smart Tips).
- **Settings Actions** -- Two new interactive buttons in the Settings screen:
  - **Replay Onboarding** -- resets `@AppStorage("hasCompletedOnboarding")` to re-show the onboarding flow
  - **Reset Tips** -- calls `Tips.resetDatastore()` to re-show all TipKit tips
- **AnimatedGradientView** -- Subtle animated gradient background used in the onboarding flow, with colors that transition per page.

### Changed
- **Settings Screen** -- Expanded with Actions section (Replay Onboarding, Reset Tips) alongside existing AI status, storage, capabilities, and about sections.
- **AppTabView** -- Now manages What's New sheet presentation alongside onboarding gate and splash overlay. Checks `lastWhatsNewVersion` vs current app version on launch.
- **DocGenieAIApp** -- Added TipKit configuration with `.displayFrequency(.immediate)` and `.datastoreLocation(.applicationDefault)`.

### New Files
- `Core/Tips/AppTips.swift` -- 3 TipKit tip definitions
- `Core/Utilities/AppIconGenerator.swift` -- Programmatic CoreGraphics icon renderer
- `Features/WhatsNew/WhatsNewView.swift` -- What's New screen + version data

### Test Results
- 160+ tests, 0 failures (31 test classes)

---

## [1.1.0] -- 2026-03-12 -- AI Tools & New PDF Tools

### Added
- **AI Tools Suite** -- 3 new AI-powered document tools:
  - **Summarize PDF** -- AI-generated 3-5 bullet point summary (LLM on iOS 26+, word/line count fallback)
  - **Ask PDF** -- Conversational Q&A against document content with chat-style interface
  - **Translate PDF** -- Full document translation to any language (requires iOS 26+)
- **AIDocumentViewModel** -- New ViewModel managing all AI tool operations with dual-provider support
- **Sign PDF** -- Draw a signature on a canvas (`SignatureCanvasView`) and apply it to any page at any position
- **Crop PDF** -- Crop page margins with configurable top, bottom, left, and right insets
- **PDF Metadata** -- Read and edit PDF document properties (title, author, subject, keywords) via `MetadataEditorView`
- **Email PDF** -- Send a PDF as an email attachment via `MFMailComposeViewController` (`MailComposerView`)
- **SignatureCanvasView** -- New UIKit representable providing a drawing canvas for signatures
- **MailComposerView** -- New UIKit representable wrapping MFMailComposeViewController
- **Apple Foundation Models** -- On-device LLM via `FoundationModels` framework (iOS 26+) with streaming responses and tool calling
- **AI Response Streaming** -- Real-time token-by-token response display in chat bubbles
- **AI Tool Calling** -- `SuggestToolDefinition` recommends tools; `NavigateTabDefinition` switches tabs. Actions appear as tappable buttons in messages.
- **Strategy Pattern** -- `AIResponseProvider` protocol with two implementations: `FoundationModelsProvider` (iOS 26+) and `KeywordMatchingProvider` (fallback)
- **AIService Singleton** -- Facade that auto-selects backend at runtime based on device capabilities
- **ToolItem expanded** -- Now defines 23 tools (was 16) across 5 sections: Scanner, PDF Tools, Converters, AI Tools, Utilities
- **ConverterService.saveTextFile()** -- New method for saving AI-generated text results as .txt files

### Changed
- **ChatViewModel** -- Rewritten to use AIService with streaming support, placeholder message pattern, and conversation-based session management
- **ChatTabView** -- Added streaming scroll behavior, typing indicator during non-streaming, On-Device AI badge
- **PDFToolsService** -- Expanded from 10 to 14 operations: added `signPDF()`, `cropPDF()`, `readMetadata()`, `writeMetadata()`
- **PDFToolsViewModel** -- Expanded to handle all 14 PDF operations plus email

### New Files
- `Features/AITools/ViewModels/AIDocumentViewModel.swift`
- `Features/AITools/Views/SummarizePDFView.swift`
- `Features/AITools/Views/AskPDFView.swift`
- `Features/AITools/Views/TranslatePDFView.swift`
- `Features/PDFTools/Views/SignPDFView.swift`
- `Features/PDFTools/Views/CropPDFView.swift`
- `Features/PDFTools/Views/MetadataEditorView.swift`
- `Features/PDFTools/Views/EmailPDFView.swift`
- `Representables/SignatureCanvasView.swift`
- `Representables/MailComposerView.swift`
- `Features/Chat/Services/AIResponseProvider.swift`
- `Features/Chat/Services/AIService.swift`
- `Features/Chat/Services/FoundationModelsProvider.swift`
- `Features/Chat/Services/KeywordMatchingProvider.swift`

### Test Results
- 160+ tests, 0 failures

---

## [1.0.1] -- 2026-03-12 -- Performance & Concurrency Fixes

### Fixed
- **Async PDF Processing** -- All `PDFToolsService` methods converted from synchronous to `async`. PDF operations no longer block the main thread.
- **Swift 6 Concurrency** -- Fixed strict concurrency warnings across all ViewModels, Services, and test classes. Added `@MainActor`, `Sendable`, and `nonisolated` annotations.
- **Memory Management** -- Added `autoreleasepool` to batch image processing in scanner and converter services.
- **Test Async Updates** -- All test methods updated from `throws` to `async throws`. Replaced `XCTAssertThrowsError` with `do/catch/XCTFail` for async error testing.

### Test Results
- 126 tests, 0 failures (before AI integration)

---

## [1.0.0] -- 2026-03-12 -- Initial Release

### Core Features
- **Document Scanner** -- Camera scanning with VisionKit, image filters (CIFilter), page management, PDF export
- **16 PDF/Document Tools** -- Merge, Split, Compress, Lock, Unlock, Extract Pages, Rotate, Reorder, Page Numbers, Watermark, OCR, Image to PDF, Doc to PDF, PDF to Image, PDF to Text
- **File Management** -- Import, categorize, search, sort, favorite, rename, delete, share
- **Document Viewers** -- PDF (PDFKit), Image (pinch-to-zoom), Office docs (QuickLook)
- **AI Chat** -- Conversational interface with quick actions and keyword-based responses
- **Design System** -- Dark theme with glass morphism, haptics, spring animations, glow effects
- **Onboarding Flow** -- 3-page swipeable onboarding with gradient icons (first launch only)
- **Splash Screen** -- 1.8s animated splash overlay with pulsing app icon
- **Confetti Animation** -- Canvas-based 60-particle confetti system triggered on tool completion
- **PDF Thumbnail Previews** -- `ThumbnailService` generates first-page thumbnails, cached via NSCache (100 items / 50MB)
- **Swipe Actions** -- Files: swipe right for delete/share, swipe left for favorite. Chat: swipe to delete conversations.
- **Skeleton Loaders** -- Shimmer loading animation on initial file load
- **Full Accessibility** -- VoiceOver labels, hints, and values on 13 components
- **Forced Dark Mode** -- Consistent dark theme across the app

### Architecture
- SwiftUI + SwiftData + MVVM (@Observable)
- Zero third-party dependencies
- XcodeGen project configuration
- iOS 17.0+ deployment target
- Swift 6.0

### Test Results
- 126 tests, 0 failures
