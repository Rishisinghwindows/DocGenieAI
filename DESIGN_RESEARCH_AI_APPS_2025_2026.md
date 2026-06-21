# Deep Research: Agentic AI App UI Design Patterns (2025-2026)

Compiled March 2026 from analysis of ChatGPT, Claude, Perplexity, Gemini, and industry-wide AI UX research.

---

## TABLE OF CONTENTS

1. [Comparative Analysis: Major AI Chat Interfaces](#1-comparative-analysis)
2. [The "Magical vs Clunky" Framework](#2-magical-vs-clunky)
3. [AI Thinking & Processing States](#3-thinking-processing-states)
4. [Suggestion & Prompt Patterns](#4-suggestion-prompt-patterns)
5. [Tool Usage & Inline Results](#5-tool-usage-inline-results)
6. [Onboarding Patterns](#6-onboarding-patterns)
7. [Chat-to-Tool Execution Transitions](#7-chat-to-tool-transitions)
8. [Color Schemes & Visual Language](#8-color-schemes-visual-language)
9. [Conversation History Management](#9-conversation-history)
10. [User Control in Agentic AI](#10-user-control)
11. [Implementable Component Specs](#11-component-specs)
12. [Canvas/Artifacts Side Panel Pattern](#12-canvas-artifacts)
13. [Empty State Design](#13-empty-states)
14. [Input Bar Design](#14-input-bar-design)
15. [Accessibility Requirements](#15-accessibility)

---

## 1. COMPARATIVE ANALYSIS: MAJOR AI CHAT INTERFACES {#1-comparative-analysis}

### ChatGPT (OpenAI)
- **Layout**: Minimalist with collapsible sidebar for conversation threads. Clean white/dark background.
- **Input**: Text box with regenerate/edit buttons. Voice input on mobile with TTS reply. Image upload integrated into chat flow.
- **Responses**: Code in monospaced blocks with syntax highlighting + copy button. Markdown tables render as formatted tables.
- **Canvas**: Side-panel for editing documents/code. Supports Document mode (rich text), Code mode (syntax-highlighted), and Webview mode (renders HTML). Edits shown as git-diff-style suggestions.
- **Model Selection**: Dropdown at top of chat (GPT-5.2, GPT-5 mini, o3, o4-mini). Users can switch between "Auto," "Fast," and "Thinking" modes.
- **History**: Auto-saving with sidebar pinning. Infinite-scroll history. Conversation renaming. Custom instructions apply globally.
- **Unique**: Advanced Data Analysis shows file imports and Python execution inline. Web search results integrated into conversation flow.

### Claude (Anthropic)
- **Layout**: Minimalist, utilitarian. Two-column: left sidebar (conversations/Projects), main chat area. Purple accents for branding. Deliberately subdued to emphasize content.
- **Input**: Text input, voice mode on mobile with mic button, multi-file drag-and-drop upload. Tone/Length dropdown (Formal/Casual, Short/Detailed).
- **Responses**: Messages labeled "You" / "Claude" with timestamps. Code in monospaced blocks with syntax highlighting. **Artifacts** open in separate side panel for full-size viewing.
- **Outline View**: Long responses get clickable section headers for navigation.
- **History**: All conversations saved in sidebar with renaming. **Projects** organize multiple chats + reference documents. Multi-user Project sharing with activity feed.
- **Unique**: 200K context window. Web search toggle with citations. Artifacts as clickable cards expanding to side panel.

### Google Gemini
- **Layout**: Material Design aesthetic. White background with blue/purple accents. Omnipresent across Google products (Gmail sidebar, Docs panel, Android overlay).
- **Input**: Text input, voice via power button hold or "Hey Google." Multiple voice personas ("Mellow," "Glassy"). Image/PDF attachment via paperclip with Drive integration.
- **Responses**: Purple accents on AI responses. **Draft variants** showing multiple response approaches. "Google It" button for fact-checking. Python code execution with dual-pane editor.
- **Generative UI**: Dynamically creates custom interfaces per query (charts, interactive widgets, etc.).
- **Design Language**: Gradients as core visual metaphor with "sharp, almost opaque leading edges that diffuse at the tail." Rounded corners throughout. Four-color dots (red, yellow, green, blue) from Google logo.
- **History**: Synced across devices via Google Account. Recent conversations sidebar. Persistent memory for Advanced users.
- **Unique**: Deep Research mode toggle showing multi-step research planning. Suggested follow-up questions.

### Perplexity
- **Layout**: Search-first design. Clean conversational UI. Recently redesigned with chat bubbles, universal tabs, and refreshed sidebar.
- **Input**: Search-oriented input. Shopping integration with PayPal. Virtual try-on.
- **Responses**: Inline source citations. Live flight info, finance data, quizzes/flashcards directly in responses.
- **Comet Assistant**: When users open linked sources, active thread persists in sidebar for context preservation.
- **iPad**: Purpose-built for multitasking and real work.
- **Privacy**: Snapshot widget with session-level privacy toggles.
- **Unique**: Real-time finance and news. Source-thread persistence. Focus on verifiable, cited answers.

### Poe (Quora)
- **Layout**: Colorful, multi-model aggregator. Bot selection via sidebar/top bar. Each model has custom icon/emoji.
- **Input**: Bot selection before messaging. Suggested prompts per bot. Swipeable conversations on mobile.
- **Responses**: Multi-bot chat displays answers side-by-side or sequentially. Direct comparison view.
- **Unique**: Community-created bots with app-store aesthetic. Group chats (200 users, 200+ models). Model quota visibility.

---

## 2. THE "MAGICAL VS CLUNKY" FRAMEWORK {#2-magical-vs-clunky}

### What Makes AI Feel MAGICAL

1. **Streaming text with typewriter effect** - Content appears token-by-token, reducing perceived wait by 55-70% vs waiting for full response
2. **Seamless mode transitions** - Moving between chat, voice, camera, and tool execution without page reloads or jarring context switches
3. **Anticipatory suggestions** - AI predicts what user wants next (follow-up questions, related actions)
4. **Invisible complexity** - Tool calls, web searches, and file processing happen behind simple, calm UI elements
5. **Generative UI** (Gemini pattern) - Interface adapts to content type; a chart query produces an interactive chart, not just text
6. **Progressive disclosure** - Show summary first, expand to detail on demand. Claude's Outline View pattern.
7. **Artifacts/Canvas** - Content created in dedicated editing space, not buried in chat scroll
8. **Confidence communication** - Subtle signals about certainty without overwhelming

### What Makes AI Feel CLUNKY

1. **Generic spinners** for AI processing (vs skeleton screens or streaming)
2. **Full-page reloads** between features
3. **No way to interrupt** a long response
4. **Tool results buried** in paragraphs of text vs structured cards
5. **Identical treatment** for all content types (code, prose, data all look the same)
6. **No persistent context** - having to re-explain every conversation
7. **Chat-only interface** for everything (no canvas/artifact pattern for creation tasks)
8. **"Is it broken?"** moments - no feedback during processing gaps

---

## 3. AI THINKING & PROCESSING STATES {#3-thinking-processing-states}

### Two-Stage Loading Model (Industry Standard)

**Stage 1 - Processing (Pre-Generation)**
- Display: AI avatar with loading state + descriptive text in chat bubble
- Text format: `[Generating/Loading] [specific artifact]` (sentence case, no end punctuation)
- Use "Generating" for new content, "Loading"/"Fetching" for existing data
- CRITICAL: Do NOT show loading state for sub-1-second operations (causes jarring flicker)

**Stage 2 - Generation (Active Output)**
- Streaming text: Token-by-token display via SSE or WebSocket
- Cursor: 2px vertical bar, 500ms blink rate
- Cursor disappears when streaming completes
- Loading avatar remains visible during generation (signals overall system state)

### Skeleton Loading for AI Responses
- 3-5 lines of grey shimmer animation at decreasing widths
- Fills 500ms-2s pre-generation delay before first token
- Moving gradient shimmer animation
- Reduces perceived load time by 40% vs blank panels with spinners

### Gemini's Thinking Visualization
- Morphing, multi-colored gradient shapes depicting thinking states
- Pulsing shapes suggesting ongoing processing
- Concentrated gradients during voice transcription
- Diffusing color patterns showing information synthesis
- Motion is functional, not decorative, with defined start/end points

### ChatGPT's "Thinking" Mode
- Explicit "Thinking" mode toggle in UI
- Shows reasoning chain in a collapsible section
- Visual distinction between thinking trace and final response

### Micro-Animation Specs for State Changes
- Duration: 100-300ms
- State animations: processing pulse, height expansion, color transitions, fade-out on dismiss
- Best completion time: 400-500ms for engagement

### Confidence Indicators (Emerging 2026 Pattern)
- Percentage badges ("92% confidence")
- Source citation counts
- Color-coded borders: Green (high confidence), Amber (medium), Red (low/uncertain)
- Apply only where factual accuracy carries risk (medical, financial, code)

---

## 4. SUGGESTION & PROMPT PATTERNS {#4-suggestion-prompt-patterns}

### Empty State Suggestions (First Screen)
- **Gemini Pattern**: Personalized greeting ("Hello, [Name]. How can I help you today?") + curated suggestion cards highlighting different capabilities
- **ChatGPT Pattern**: Clean input with suggested starter prompts as tappable chips
- **Perplexity Pattern**: Search-oriented with trending topics and categories

### Follow-Up Suggestions
- **Gemini**: Suggested follow-up questions appear after AI response
- **Poe**: Per-bot suggested prompts based on bot specialty
- **Best Practice**: 2-4 suggestions max, contextually relevant to current conversation, displayed as tappable chips/pills

### Prompt Enhancement Patterns
- AI-generated pre-prompts and prompt extensions
- Query builders as alternatives to manual typing
- Claude's Tone/Length dropdown (Formal/Casual, Short/Detailed) sets meta-context without requiring prompt engineering

### Suggested Actions (Post-Response)
- AI recommends actionable next steps: scheduling, research, filtering, format transformations
- Integration actions: "Post to Slack," "Create Jira ticket," "Save to Drive"
- Displayed as tappable action buttons below the response

---

## 5. TOOL USAGE & INLINE RESULTS {#5-tool-usage-inline-results}

### How Top Apps Show Tool Execution

**ChatGPT**
- Web search results integrated directly into conversation flow
- Advanced Data Analysis: file imports and Python execution shown within chat
- Canvas: documents/code open in dedicated side panel
- Model auto-selects appropriate tool; user sees results, not the mechanism

**Claude**
- Artifacts as clickable cards that expand to side panel
- Web search toggle with inline citations
- No built-in code execution; code presented for copying

**Gemini**
- Deep Research mode: shows multi-step research plan before execution
- Code execution: dual-pane editor (code left, output right)
- "Google It" button for fact-checking with integrated results
- Generative UI: custom visual interfaces created per query

**Perplexity**
- Inline source citations with numbered references
- Live data: flight info, finance data, news rendered as structured cards
- Source thread persists in sidebar when opening links

### Design Patterns for Tool Display

1. **Collapsible Tool Execution Card**: Shows tool name, status (running/complete), and expandable result. Compact by default.
2. **Side Panel (Canvas/Artifacts)**: Full editing environment for generated documents, code, or web content. Chat continues alongside.
3. **Inline Structured Cards**: For data results (tables, charts, lists) that are visually distinct from chat text.
4. **Progressive Disclosure**: Summary visible, full results on expand/tap.
5. **Citation Badges**: Numbered inline references linking to sources.

---

## 6. ONBOARDING PATTERNS {#6-onboarding-patterns}

### Goal-First Onboarding (2026 Standard)
- Users expect outcomes, not tutorials
- Ask "What do you want to accomplish?" not "Here's how our tool works"
- Reduce steps: 2025 average was 6 steps; 2026 best practice is 2 steps based on user history

### Adaptive & Personalized Flows
- AI analyzes survey responses, behavioral patterns, usage metadata to tailor what users see
- Dynamic user segmentation from moment of signup
- Generative UX content creates tips and guidance on the fly

### Contextual AI Assistants in Onboarding
- Embedded helpers with inline suggestions, autofill, smart search
- Predictive nudges: users who pause too long see clarifying pop-ups
- Users who skip advanced features receive gentle suggestions later

### Capability Showcase Pattern
- Empty state shows 3-4 curated suggestion cards demonstrating range of capabilities
- Each card is a one-tap-to-try example (Gemini's approach)
- Examples categorized: "Write," "Analyze," "Research," "Create"

### Progressive Capability Discovery
- Don't reveal everything at once
- Surface advanced features (voice, file upload, tool use) contextually as users' needs evolve
- "Did you know?" nudges after specific interaction patterns

---

## 7. CHAT-TO-TOOL EXECUTION TRANSITIONS {#7-chat-to-tool-transitions}

### Agentic UX Lifecycle (Smashing Magazine Framework)

**Pre-Action Patterns**
1. **Intent Preview**: Plain-language description of planned actions. Choices: Proceed / Edit Plan / Handle Myself. Non-negotiable for irreversible actions, financial transactions, data sharing.
2. **Autonomy Dial**: Per-task-type settings ranging from "Observe & Suggest" to "Act Autonomously." Separate dials for different categories (scheduling vs. email vs. purchases).

**In-Action Patterns**
3. **Explainable Rationale**: Links decisions to user's stated preferences. Simple cause-and-effect: "Because you said X, I did Y."
4. **Confidence Signal**: Visual certainty indicators. Green checkmarks (high), yellow question marks (uncertain).

**Post-Action Patterns**
5. **Action Audit & Undo**: Chronological log of all agent actions. Clear status: successful, in progress, undone. Time-limited undo windows with visible expiration. One-click undo for every action.
6. **Escalation Pathway**: Clarification requests ("Do you mean September 30th or October 7th?"), option presentation (multiple valid paths), human intervention pathway for high-stakes tasks.

### Supervisor-Worker Agent Architecture (UX Magazine Pattern)
- Central reasoning agent orchestrates specialized worker agents
- Workers operate asynchronously, reporting findings back
- **Suggestions panel** updates progressively as agents complete tasks
- **Accept/reject mechanism** for suggestions guides the next investigation phase
- Left sidebar accumulates accepted findings; right panel shows incoming suggestions
- Non-blocking: users review suggestions at their own pace

### Transition Animations
- Chat smoothly pushes left or compresses when side panel (Canvas/Artifacts) opens
- Tool execution cards expand inline with height animation (100-300ms)
- Background dimming or blur when modal tool UI appears
- Progress indicators within the tool card, not separate from conversation

---

## 8. COLOR SCHEMES & VISUAL LANGUAGE {#8-color-schemes-visual-language}

### 2026 Industry Standard: Dark Mode Default

**Base Colors**
- Background: `#0D0D14` (preferred) or range `#0A0A0A` to `#1A1A2E` (NOT pure black #000000)
- Text: `#D4D4E8` (off-white, not pure white)
- Panels: `rgba(255, 255, 255, 0.06)` with backdrop blur 12-20px

**82% of users prefer dark mode for extended AI sessions.**

### Glassmorphism 2.0 for AI Panels
```css
.ai-panel {
  background: rgba(255, 255, 255, 0.06);
  backdrop-filter: blur(16px);
  border: 1px solid rgba(255, 255, 255, 0.10);
  border-radius: 16px;
  box-shadow: 0 4px 24px rgba(0, 0, 0, 0.3),
              inset 0 1px 0 rgba(255, 255, 255, 0.08);
}
/* Subtle accent overlay */
.ai-panel::after {
  background: rgba(99, 102, 241, 0.04); /* Indigo accent */
}
```

### Per-App Color Identity
- **ChatGPT**: Clean white/dark with green accents (#10A37F)
- **Claude**: Purple accents on neutral base, deliberately subdued
- **Gemini**: Multi-color gradients (Google's red/yellow/green/blue), purple accents on responses, blue highlighting
- **Perplexity**: Clean blue/white, citation-focused visual hierarchy

### Apple Liquid Glass (iOS 26)
- Translucent, depth-aware material
- Refraction and adaptive materials change how elements layer
- Allows light and color to shine through
- Reflects light subtly when device moves
- Rewrites contrast behavior for layered interfaces

### Color Accessibility
- WCAG 2.2 minimum: 4.5:1 contrast ratio for standard text
- Avoid "grey-on-grey fatigue"
- System-aware switching via `prefers-color-scheme`
- Manual toggle always accessible in header/settings

---

## 9. CONVERSATION HISTORY MANAGEMENT {#9-conversation-history}

### Sidebar Pattern (Industry Standard)
- **ChatGPT**: Collapsible sidebar, infinite-scroll history, pinning, renaming
- **Claude**: Sidebar + Projects (groups of conversations + documents). Multi-user sharing with activity feed.
- **Gemini**: Cross-device sync via Google Account. Recent conversations sidebar. Search functionality (evolving).
- **Perplexity**: Refreshed sidebar with universal tabs. Thread persistence when navigating to sources.

### Mobile-Specific History Patterns
- Swipe from left edge to reveal history sidebar
- Recent conversations as horizontal scroll cards at top
- Search within history (critical for power users)
- Conversation renaming for organization

### Persistent Context Design
- Persistent header/sidebar displaying relevant conversation details
- Remind users of conversation purpose and key information
- Claude's Projects: maintain document context across multiple conversations

### Best Practices
1. Auto-save all conversations (never lose work)
2. Enable conversation renaming/categorization
3. Provide search across all history
4. Show conversation preview/snippet in list
5. Support conversation sharing/export
6. Cross-device sync
7. Allow conversation forking/branching
8. Context window visibility (how much context the AI "remembers")

---

## 10. USER CONTROL IN AGENTIC AI {#10-user-control}

### The Autonomy Dial (Core Pattern)
Four levels of agent independence, configurable per task type:
1. **Observe & Suggest**: Agent notifies only, no proposals
2. **Plan & Propose**: Creates plans requiring user review
3. **Act with Confirmation**: Prepares actions, needs final "Go" approval
4. **Act Autonomously**: Pre-approved tasks executed independently, user notified after

### Control Mechanisms
- **Intent Preview**: Always show what agent will do before it does it
- **One-Click Undo**: Every agent action must be reversible with single tap
- **Undo Time Windows**: Visible countdown showing when action becomes permanent
- **Interrupt Capability**: Ability to stop mid-generation or mid-action
- **Action Audit Log**: Chronological timeline of all agent-initiated actions with status

### Trust-Building Patterns
- Start conservative (Level 2: Plan & Propose) and let users upgrade autonomy
- Separate autonomy settings for different task types (scheduling: autonomous; purchasing: always confirm)
- Explain reasoning: "Because you said X, I did Y"
- Acknowledge uncertainty: confidence indicators prevent automation bias
- Escalate gracefully: "I'm not sure about this. Do you mean A or B?"

### Empathic Error Recovery
When agent makes mistake:
1. Clear acknowledgment of error
2. Immediate corrective action
3. Prevention measure communicated
4. Path to human support
Pattern: "We made a mistake. [Error stated]. [Correction applied]. [What we'll do to prevent this]. [Support link]"

### Perplexity's Privacy Controls
- Session-level privacy toggles during browsing
- Snapshot widget for managing stored information
- Page-level interaction controls
- Transparent about what data is stored

---

## 11. IMPLEMENTABLE COMPONENT SPECS {#11-component-specs}

### Streaming Text Container
```
Font size: 15px
Line height: 1.7
Letter spacing: 0.01em
Cursor: 2px vertical bar, 500ms blink
Streaming: SSE or WebSocket, token-by-token
```

### AI Response Bubble
```
Background (dark mode): rgba(255, 255, 255, 0.06)
Backdrop blur: 12-20px
Border: 1px solid rgba(255, 255, 255, 0.10)
Border radius: 16px
Padding: 16px
Shadow: 0 4px 24px rgba(0, 0, 0, 0.3)
```

### Skeleton Loading (Pre-Response)
```
Lines: 3-5
Line widths: 100%, 85%, 70%, 60%, 45% (decreasing)
Animation: Moving gradient shimmer
Duration: Visible for 500ms-2s before first token
Color: rgba(255, 255, 255, 0.08) shimmer on dark base
```

### Suggestion Chips
```
Background: rgba(255, 255, 255, 0.08)
Border: 1px solid rgba(255, 255, 255, 0.12)
Border radius: 20px (pill shape)
Padding: 8px 16px
Font size: 14px
Max chips visible: 2-4
Layout: Horizontal scroll on mobile
Tap target: minimum 44px height (Apple HIG)
```

### Tool Execution Card
```
Background: rgba(255, 255, 255, 0.04)
Border-left: 3px solid accent color
Border radius: 12px
Padding: 12px 16px
States: pending (pulse animation), running (progress), complete (checkmark), error (red)
Expand/collapse: 200ms ease-out
```

### Confidence Badge
```
High (>85%): Green border/badge (#22C55E)
Medium (60-85%): Amber border/badge (#F59E0B)
Low (<60%): Red border/badge (#EF4444)
Format: "92% confidence" or source count "[3 sources]"
Position: Top-right of response bubble or inline
```

### Voice Input Button
```
Position: Primary action bar, persistent
Size: 44x44px minimum (touch target)
Active state: Audio waveform animation
Feedback: Live transcription in text field
Privacy: Clear visual indicator when mic is active
```

### Micro-Animation Timings
```
State transitions: 100-300ms
Processing pulse: 1000ms loop
Height expansion: 200ms ease-out
Color transitions: 150ms ease-in-out
Fade out on dismiss: 200ms
Skeleton shimmer cycle: 1500ms
```

---

## 12. CANVAS/ARTIFACTS SIDE PANEL PATTERN {#12-canvas-artifacts}

### Core Concept
Separate creative outputs from main chat flow. A dedicated editing space alongside conversation.

### ChatGPT Canvas
- **Modes**: Document (rich text), Code (syntax-highlighted), Webview (renders HTML)
- **Interaction**: Users directly edit AI output in-panel
- **Partial edits**: Don't re-render whole document
- **Diff view**: Edits shown like git diff suggestions
- **Shortcuts**: Edit suggestions, adjust length, change reading level, final polish

### Claude Artifacts
- Clickable cards in chat that expand to full side panel
- Supports: code, documents, HTML rendering, diagrams
- Persistent: survives across conversation turns
- Versioned: can reference/modify previous artifacts

### Implementation Pattern
```
Layout: Chat (40-50% width) | Panel (50-60% width)
Mobile: Full-screen panel with back-to-chat navigation
Transition: Chat slides/compresses left, panel slides in from right (300ms)
Panel header: Title + close button + type indicator
Panel actions: Copy, Download, Edit, Share
```

---

## 13. EMPTY STATE DESIGN {#13-empty-states}

### Best-in-Class Pattern (Gemini-Style)
1. **Personalized greeting**: "Hello, [Name]. How can I help you today?"
2. **Capability cards**: 3-4 curated suggestions showing range of abilities
3. **One-tap activation**: Each card is immediately actionable
4. **Category diversity**: Write, Analyze, Research, Create

### Design Principles
- Interactive, not passive ("Try this" not "Nothing here yet")
- Preload sample data or auto-generate starter content
- Show what's possible, not what's missing
- Centered layout with: headline, description, icon/illustration, CTA

### Avoid
- Generic "Start a conversation" with no guidance
- Overwhelming with too many options (max 4 cards)
- Static illustrations with no actionable elements

---

## 14. INPUT BAR DESIGN {#14-input-bar-design}

### Standard Components (2026)
1. **Text field**: Auto-expanding, placeholder text suggesting capabilities
2. **Voice button**: Persistent microphone icon in primary action bar
3. **Attachment button**: Paperclip/plus icon for files, images, camera
4. **Send button**: Appears when text is entered (replaces voice button or sits alongside)
5. **Model/mode selector**: Accessible but not obstructing (dropdown or segmented control above input)

### Mobile-Specific
- Large touch targets (44px minimum per Apple HIG)
- Floating input bar at bottom of screen
- Auto-expanding text field (grows with content up to ~4 lines, then scrolls)
- Attachment options in expandable tray (not always visible)
- Voice waveform replaces text field during voice input

### WhatsApp/iOS 26 Pattern (Liquid Glass)
- Floating chat bar with separated individual elements
- Translucent glass material following Apple's Liquid Glass design
- Elements: attachment, text input, voice each as distinct interactive zones

---

## 15. ACCESSIBILITY REQUIREMENTS {#15-accessibility}

### WCAG 2.2 Compliance for AI Interfaces
- `aria-live="polite"` on AI response containers
- `role="status"` on loading elements
- Keyboard focus moves to completed AI response
- Alt text for all icons and AI-generated images
- Screen reader compatible streaming text

### Testing Tools
- VoiceOver (iOS/macOS)
- NVDA (Windows)
- Dynamic Type support (iOS)
- SF Symbols with accessibility labels

### Key Requirements
- Keyboard navigation for all interactive elements
- Voice input as first-class alternative to typing
- Visual accommodation options (high contrast, reduced motion)
- 4.5:1 contrast ratio minimum for all text
- Touch targets minimum 44x44pt (iOS HIG)

---

## KEY TAKEAWAYS FOR IMPLEMENTATION

### The 5 Non-Negotiables for 2026 AI Apps

1. **Streaming responses with skeleton pre-loading** - Never show a blank screen or generic spinner
2. **Dark mode as default** with system-aware switching and manual override
3. **Canvas/Artifacts pattern** for any content creation beyond simple chat replies
4. **Autonomy controls** - Users must always be able to see what the agent will do, approve/reject it, and undo it
5. **Voice as first-class input** - Persistent mic button, waveform feedback, live transcription

### The Design Equation
```
Magical AI UX = Streaming + Progressive Disclosure + Contextual Actions + User Control + Beautiful Loading States
```

### Phased Implementation
- **Phase 1 (Foundation)**: Streaming text, skeleton loading, dark mode, basic chat bubbles, input bar
- **Phase 2 (Intelligence)**: Suggestion chips, follow-up prompts, tool execution cards, inline citations
- **Phase 3 (Agentic)**: Intent preview, autonomy dial, action audit/undo, side panel (canvas/artifacts)
- **Phase 4 (Polish)**: Confidence indicators, generative UI, voice-first interface, ambient intelligence

---

## SOURCES

- [UI/UX Design Trends for AI-First Apps in 2026 (GroovyWeb)](https://www.groovyweb.co/blog/ui-ux-design-trends-ai-apps-2026)
- [Designing For Agentic AI: Practical UX Patterns (Smashing Magazine)](https://www.smashingmagazine.com/2026/02/designing-agentic-ai-practical-ux-patterns/)
- [Comparing Conversational AI Tool User Interfaces 2025 (IntuitionLabs)](https://intuitionlabs.ai/articles/conversational-ai-ui-comparison-2025)
- [Gemini AI Visual Design (Google Design)](https://design.google/library/gemini-ai-visual-design)
- [Secrets of Agentic UX (UX Magazine)](https://uxmag.com/articles/secrets-of-agentic-ux-emerging-design-patterns-for-human-interaction-with-ai-agents)
- [Generative AI Loading States (Cloudscape)](https://cloudscape.design/patterns/genai/genai-loading-states/)
- [AI Interface Design Patterns (Smart Interface Design Patterns)](https://smart-interface-design-patterns.com/articles/ai-design-patterns/)
- [Agentic AI Design Patterns (AufaitUX)](https://www.aufaitux.com/blog/agentic-ai-design-patterns-enterprise-guide/)
- [Agentic UX & Design Patterns (Mania Labs)](https://manialabs.substack.com/p/agentic-ux-and-design-patterns)
- [Mobile App Design Trends 2026 (UXPilot)](https://uxpilot.ai/blogs/mobile-app-design-trends)
- [iOS UX Design Trends 2026 (AsappStudio)](https://asappstudio.com/ios-ux-design-trends-2026/)
- [Apple Intelligence iOS 26 Features (9to5Mac)](https://9to5mac.com/2025/10/15/apple-intelligence-new-features-in-ios-26-full-list/)
- [iOS 26 Developer Guide (Index.dev)](https://www.index.dev/blog/ios-26-developer-guide)
- [Chatbot UI Best Practices 2026 (Vynta)](https://vynta.ai/blog/chatbot-ui/)
- [Conversational UI Best Practices 2026 (AIMultiple)](https://research.aimultiple.com/conversational-ui/)
- [Dark Mode Design Best Practices 2026 (Tech-RZ)](https://www.tech-rz.com/blog/dark-mode-design-best-practices-in-2026/)
- [Perplexity AI Updates Late 2025 (DataStudios)](https://www.datastudios.org/post/perplexity-ai-updates-in-late-2025-feature-expansions-service-behavior-and-platform-direction)
- [Gemini App Updates Google I/O 2025](https://blog.google/products/gemini/gemini-app-updates-io-2025/)
- [ChatGPT Canvas vs Claude Artifacts](https://medium.com/@jakairos/chatgpt-canvas-the-dawn-of-ephemeral-apps-c3f32999517e)
- [Chatbot UI Examples (Eleken)](https://www.eleken.co/blog-posts/chatbot-ui-examples)
- [Empty State UI Pattern (Mobbin)](https://mobbin.com/glossary/empty-state)
- [AI User Onboarding (UserPilot)](https://userpilot.com/blog/ai-user-onboarding/)
- [Must-Know Agentic Design Patterns 2026 (Medium/ProCreator)](https://medium.com/@pro.namratapanchal/what-are-the-must-know-agentive-design-patterns-for-2026-21cf34839a01)
