# AI App iOS Screen Flows: Detailed Walkthrough (March 2026)

Step-by-step screen flows for ChatGPT, Claude, Perplexity, and Gemini on iOS, compiled from web research, UI databases (Mobbin, Banani, SaaSUI), official docs, and product teardowns.

---

## TABLE OF CONTENTS

1. [ChatGPT (OpenAI)](#1-chatgpt)
2. [Claude (Anthropic)](#2-claude)
3. [Perplexity](#3-perplexity)
4. [Gemini (Google)](#4-gemini)
5. [Cross-App Comparison Tables](#5-comparison)

---

## 1. CHATGPT (OpenAI) {#1-chatgpt}

### 1.1 First Launch Experience

1. **Splash Screen**: Black screen with white OpenAI logo (brief).
2. **Welcome/Onboarding**: Guided setup with Face ID or Touch ID verification for secure authentication.
3. **Privacy Configuration**: Granular controls over data usage and AI interactions. Users choose whether to allow chat history to be used for training.
4. **Sign In / Sign Up**: Options for Apple ID, Google, email. Existing users can sign in to sync conversation history across devices.
5. **Subscription Prompt**: Users are shown tier options (Free, Plus, Pro). Can skip to free tier.
6. **Landing on Home Screen**: Empty new-chat state with suggested prompts.

### 1.2 Home Screen Layout (Empty / New Chat State)

```
+--------------------------------------------------+
| [hamburger menu]    ChatGPT v  [model picker]     |
|                                                    |
|                                                    |
|               (OpenAI logo, centered)              |
|                                                    |
|         "What can I help with?"                    |
|                                                    |
|   [Suggestion chip 1]  [Suggestion chip 2]         |
|   [Suggestion chip 3]  [Suggestion chip 4]         |
|                                                    |
|                                                    |
|                                                    |
+--------------------------------------------------+
| [+] [  Message ChatGPT...        ] [waveform icon]|
+--------------------------------------------------+
```

**Key elements:**
- **Top-left**: Hamburger menu icon (three horizontal lines) opens the conversation sidebar.
- **Top-center**: "ChatGPT" label with a dropdown chevron (v) that opens the model picker. Tapping reveals: GPT-5.3, GPT-5.4, o3, o4-mini, plus mode toggles for "Auto," "Fast," and "Thinking."
- **Center**: OpenAI logo with greeting text and 2-4 suggested prompt chips. Chips are tappable pill shapes showing example tasks like "Help me write," "Analyze data," "Brainstorm ideas," "Summarize text."
- **Bottom**: Floating input bar pinned to bottom of screen.

### 1.3 Input Bar (Detail)

```
+--------------------------------------------------+
| [+]  [  Message ChatGPT...          ]  [waveform] |
+--------------------------------------------------+
```

- **Left side**: "+" button (circle with plus icon). Tapping opens an attachment tray with options:
  - Photo Library (select existing photos)
  - Camera (take new photo)
  - Files (browse device files, PDFs, documents)
  - Drive integrations (if connected)
- **Center**: Auto-expanding text field. Placeholder text: "Message ChatGPT..." Grows vertically up to ~4 lines, then becomes scrollable.
- **Right side (idle)**: Waveform icon for Voice Mode. Tapping initiates Advanced Voice Mode -- a real-time spoken conversation within the same chat window.
- **Right side (text entered)**: Send button (up-arrow in circle) replaces the waveform icon when there is text in the field.
- **Microphone for dictation**: Standard iOS dictation via keyboard mic button (not a ChatGPT-specific button).

### 1.4 Conversation Sidebar (History)

Swipe right from left edge or tap hamburger menu:

```
+---------------------------+
|  [Search conversations]    |
|                            |
|  PINNED                    |
|  * Project planning chat   |
|  * Weekly standup notes     |
|                            |
|  TODAY                     |
|  * "Help me write an email"|
|  * "Explain quantum comp..." |
|                            |
|  YESTERDAY                 |
|  * "Debug my Python code"  |
|  * "Recipe suggestions"    |
|                            |
|  PREVIOUS 7 DAYS           |
|  * ...                     |
|                            |
|  [+ New chat]              |
|                            |
| -------------------------  |
| [avatar] [User Name]  ... |
| [Settings / Upgrade]      |
+---------------------------+
```

- **Search bar** at top for finding past conversations by keyword.
- **Pinned chats** appear at the top. Long-press a chat to pin, rename, or delete.
- Conversations grouped by time: Today, Yesterday, Previous 7 Days, Previous 30 Days, then by month.
- Each conversation shows an auto-generated title (first few words of conversation) that can be renamed.
- **Bottom of sidebar**: User avatar with name. Tapping the three-dot icon ("...") next to the name opens Settings.
- **"+ New chat"** button to start a fresh conversation.
- Infinite scroll for history.
- **Branched chats**: Available since late 2025. Long-press on any assistant message to create a branch, allowing divergent exploration without starting a new thread.

### 1.5 Settings Access

1. Open sidebar (hamburger menu or swipe right).
2. Tap the three-dot menu ("...") next to your account name at the bottom.
3. Settings screen includes:
   - **Account**: Email, subscription tier, "Restore purchases," sign out.
   - **Personalization**: Custom Instructions ("What would you like ChatGPT to know about you?" and "How would you like ChatGPT to respond?"), Memory management (view/delete stored memories).
   - **Voice**: Choose voice persona (options like Breeze, Ember, Cove, Sol, Sage).
   - **Data Controls**: Chat history toggle, data export, delete account.
   - **Connected Apps/Connectors**: Gmail, Slack, Notion, GitHub, Linear integrations.
   - **Model Preferences**: Default model, which models appear in the picker.
   - **Subscription**: Upgrade to Plus/Pro, manage billing.

### 1.6 Active Conversation Flow

**User sends a message:**

```
+--------------------------------------------------+
| [<back]         ChatGPT v                         |
|                                                    |
|  You:                                              |
|  "Explain how React hooks work with examples"      |
|                                                    |
|  ChatGPT:                                          |
|  [streaming text appears token by token...]        |
|  React Hooks are functions that let you...         |
|                                                    |
|  ```jsx                                            |
|  import { useState } from 'react';                 |
|  function Counter() {                              |
|    const [count, setCount] = useState(0);          |
|    ...                                             |
|  ```                            [Copy code]        |
|                                                    |
|  [Regenerate] [Edit]                               |
|                                                    |
+--------------------------------------------------+
| [+]  [  Message ChatGPT...          ]  [send]     |
+--------------------------------------------------+
```

**Response display details:**
- **Streaming**: Text appears token-by-token (typewriter effect) via SSE/WebSocket.
- **Markdown rendering**: Headers, bold, italic, lists, tables all render as formatted content.
- **Code blocks**: Monospaced font with syntax highlighting. Each code block has a "Copy code" button in the top-right corner of the block.
- **Images** (DALL-E generation): Rendered inline as full-width cards within the chat. Watermarked.
- **Web search results**: When the model searches the web, a collapsible "Searched N sites" card appears showing sources, followed by the response with inline citation numbers linking to sources.
- **Thinking mode**: When enabled, a collapsible "Thinking..." section shows the reasoning chain before the final response. Users can expand/collapse the thinking trace.

**Post-response controls:**
- **Regenerate button**: Circular arrow icon below the response to get a new answer.
- **Copy button**: Copies the full response text.
- **Thumbs up/down**: Feedback icons on each response.
- **Edit button** (on user messages): Pencil icon to edit and resubmit a previous message.

### 1.7 File Attachments Flow

1. Tap the "+" button in the input bar.
2. Attachment tray slides up with options: Photo Library, Camera, Files.
3. Select a file (PDF, spreadsheet, image, Word doc, etc.).
4. File appears as a thumbnail/chip above the text field (showing filename and file type icon).
5. User types an accompanying message and taps Send.
6. ChatGPT processes the file. For PDFs/documents, the AI references content directly. For images, it displays the image inline and analyzes it.
7. If Advanced Data Analysis is triggered (e.g., CSV file), ChatGPT may run Python code in a sandbox. The execution appears as a collapsible "Analyzing..." card, then shows results (charts, tables, processed files) inline.

**Limits**: 512MB per file, 80 files per 3 hours, 2M tokens per text/document file.

### 1.8 Canvas (Side Panel) -- NOT YET on iOS

Canvas is currently available only on Web, Windows, and macOS. On iOS, Canvas support is forthcoming. On desktop:
- **Trigger**: ChatGPT auto-detects when a response benefits from Canvas (e.g., long-form writing >10 lines, coding tasks).
- **Layout**: Chat compresses to left (~40%), Canvas panel opens on right (~60%).
- **Modes**: Document (rich text editor), Code (syntax-highlighted editor), Webview (live HTML render).
- **Editing**: Users directly edit AI-generated content in the panel. AI can be asked to modify specific sections.
- **Shortcuts menu**: Quick actions like "Adjust length," "Change reading level," "Add emojis," "Debug code," "Final polish."
- **Diff view**: AI edits shown as git-diff-style highlights.

### 1.9 Voice Mode Flow

1. Tap the waveform icon in the bottom-right of the input bar.
2. Voice Mode activates within the same chat window (no separate screen since recent update).
3. The waveform animation appears, indicating the AI is listening (blue = active listening).
4. Speak naturally. Live transcription appears in the text field.
5. ChatGPT responds with spoken audio. The transcript of the response appears in the chat as a normal message.
6. **Controls during voice mode**:
   - Bottom-left: Microphone mute/unmute button.
   - Bottom-right: Exit/end voice mode button.
   - Screen sharing and camera input supported during voice mode on mobile.
7. On exit, the full voice conversation remains in the chat thread as text transcripts.

### 1.10 Tab Structure

ChatGPT iOS does NOT use a bottom tab bar. Navigation is:
- **Sidebar** (left): Conversation history, new chat, settings access.
- **Main area**: Active conversation or new chat.
- All features accessed through the sidebar, input bar, or model picker.

---

## 2. CLAUDE (ANTHROPIC) {#2-claude}

### 2.1 First Launch Experience

1. **Splash Screen**: Anthropic logo with purple accent, brief loading.
2. **Sign In / Sign Up**: Apple ID, Google, email options. Account creation flow.
3. **Plan Selection**: Free, Pro ($20/mo), Max tiers shown.
4. **Landing**: Home screen with new conversation ready.

### 2.2 Home Screen Layout (New Chat State)

```
+--------------------------------------------------+
| [sidebar icon]      Claude      [new chat icon]   |
|                                                    |
|                                                    |
|               (Claude logo, purple)                |
|                                                    |
|        "How can I help you today?"                 |
|                                                    |
|   [Suggestion: "Help me write..."]                 |
|   [Suggestion: "Analyze this document"]            |
|   [Suggestion: "Explain a concept"]                |
|                                                    |
|                                                    |
+--------------------------------------------------+
| [+/paperclip] [Message Claude...] [mic] [voice]   |
+--------------------------------------------------+
```

**Key elements:**
- **Top-left**: Sidebar icon to access conversation history and Projects.
- **Top-center**: "Claude" label.
- **Top-right**: New chat icon (pencil/compose icon) to start fresh conversation.
- **Center**: Claude logo (purple) with greeting and suggestion chips.
- **Bottom**: Input bar pinned to bottom.
- **Color scheme**: Clean white background (or dark mode), black text, purple accents for branding and loading states.

### 2.3 Input Bar (Detail)

```
+--------------------------------------------------+
| [+]  [  Message Claude...     ] [mic] [waveform]  |
+--------------------------------------------------+
```

- **Left side**: Attachment button (paperclip or "+" icon). Tapping opens options:
  - Photo from gallery
  - Take new photo with camera
  - Select document (PDF, text files)
  - Multiple files can be uploaded simultaneously.
- **Center**: Auto-expanding text field. Placeholder: "Message Claude..."
- **Right side**: Two icons:
  - **Microphone icon**: Standard dictation (speech-to-text transcription). Tap to speak, Claude transcribes and processes the text normally.
  - **Waveform/voice mode icon**: Activates Voice Mode for a real-time spoken conversation with Claude (available on Pro/Max plans, free limited access).
- **Send button**: Appears (replacing voice icons or alongside) when text is entered.

### 2.4 Conversation Sidebar

Swipe right or tap sidebar icon:

```
+---------------------------+
| [Search]                   |
|                            |
|  PROJECTS                  |
|  > Marketing Campaign      |
|  > App Development         |
|  > Research Notes           |
|                            |
|  RECENT CONVERSATIONS      |
|  * "Code review help"      |
|  * "Meeting summary"       |
|  * "Translation request"   |
|                            |
|  OLDER                     |
|  * ...                     |
|                            |
| -------------------------  |
| [avatar] Settings          |
+---------------------------+
```

- **Projects section**: Folders that group multiple conversations + reference documents. Tapping a project shows its conversations and uploaded reference files. (Note: Cannot create new Projects on mobile -- must be done on web. Existing Projects accessible on mobile.)
- **Recent conversations**: Listed chronologically with auto-generated titles. Can rename by long-pressing.
- **Settings**: Profile icon or menu item at bottom leads to settings.
- **Offline access**: Recent chats are readable offline for reference.

### 2.5 Settings Access

1. Open sidebar, tap profile/settings icon at bottom.
2. Settings include:
   - Account details and subscription management.
   - Dark mode toggle.
   - Notification preferences.
   - Custom instructions per Project (tone, context guidelines).
   - Model selection: Claude Opus 4.5, Sonnet 4.5, Haiku 4.5.
   - Data and privacy controls.
   - Web search toggle (enable/disable).

### 2.6 Active Conversation Flow

```
+--------------------------------------------------+
| [<sidebar]       Claude          [new chat]       |
|                                                    |
|  You:                                              |
|  "Analyze this PDF and summarize the key points"   |
|  [attached: report.pdf]                            |
|                                                    |
|  Claude:                                           |
|  [streaming text, token by token...]               |
|  Here are the key findings from the report:        |
|                                                    |
|  **1. Revenue Growth**                             |
|  The report indicates a 23% increase...            |
|                                                    |
|  **2. Market Expansion**                           |
|  Three new markets were entered...                 |
|                                                    |
|  [Artifact card: "Revenue Summary Table"]          |
|                                                    |
+--------------------------------------------------+
| [+]  [  Reply to Claude...       ] [mic] [send]   |
+--------------------------------------------------+
```

**Response display details:**
- **Streaming**: Token-by-token text streaming, similar to ChatGPT.
- **Labels**: Messages labeled "You" and "Claude" with timestamps.
- **Markdown**: Full rendering of headers, bold, italic, lists, tables, blockquotes.
- **Code blocks**: Monospaced with syntax highlighting and copy button.
- **Outline view**: For long responses, Claude generates clickable section headers enabling quick navigation within the response.
- **Web search citations**: When web search is toggled on, responses include inline numbered citations.

### 2.7 Artifacts on Mobile

- **In-chat display**: Artifacts appear as clickable card elements within the conversation. The card shows a title and type indicator (e.g., "Code," "Document," "HTML").
- **Tapping the card**: On mobile, the artifact opens in a full-screen view (since there is no room for side-by-side split on phone). The view includes:
  - **Toggle** between Preview (rendered output) and Code (source code).
  - Navigation back to the chat via a back button.
  - Actions: Copy, Download.
- **Limitations on mobile**: Cannot create new Projects. Cannot access the dedicated Artifacts library tab. Some interactive visualizations (weather widgets, recipe data visuals) do not render on mobile -- desktop only.
- **On iPad / Desktop web**: Artifacts open in a split-pane view alongside the chat. Chat compresses to ~40-50% width, artifact panel takes the rest.

### 2.8 Voice Mode Flow

1. Tap the waveform/voice icon next to the microphone in the input bar.
2. Voice Mode activates with a visual indicator (audio waveform animation).
3. Speak to Claude. Claude responds with spoken audio.
4. Multiple voice personas available to choose from.
5. After the session, a transcript is displayed in the chat as normal text messages.
6. On Pro/Max tiers: Claude can access connected services (Google Calendar, Gmail, Drive) during voice mode for data-informed responses.

### 2.9 Home Screen Widget (iOS)

Claude offers an iOS widget with three buttons:
- **Chat button**: Opens the app to a new conversation.
- **Microphone button**: Opens the app directly in dictation mode.
- **Camera button**: Opens the camera to take a photo and send it to Claude for analysis.

Additionally, an "Analyze Photo with Claude" control is available in iOS Control Center and Lock Screen.

### 2.10 Tab Structure

Claude iOS does NOT use a bottom tab bar. Navigation:
- **Sidebar** (left): Conversation history, Projects, settings.
- **Main area**: Active conversation or new chat.
- Single-screen architecture with sidebar for navigation.

---

## 3. PERPLEXITY {#3-perplexity}

### 3.1 First Launch Experience

1. **Welcome Screen**: Perplexity branding with "Ask Anything" tagline.
2. **Sign In / Sign Up**: Options for Apple, Google, email. Can continue as guest.
3. **Landing**: Home tab with search interface.

### 3.2 Home Screen Layout

```
+--------------------------------------------------+
| [profile icon]    Perplexity    [thread icon]     |
|                                                    |
|                                                    |
|          "Ask anything..."                         |
|                                                    |
|  [Focus: Web v]  [Attach]  [Pro Search toggle]     |
|                                                    |
|  Suggested topics:                                 |
|  [Trending topic 1]                                |
|  [Trending topic 2]                                |
|  [Trending topic 3]                                |
|                                                    |
|                                                    |
+--------------------------------------------------+
|  [Home]    [Discover]    [Spaces]    [Library]     |
+--------------------------------------------------+
```

**Key elements:**
- **Top-left**: Profile icon for account/settings access.
- **Top-right**: Thread icon to start a new search thread.
- **Center**: Large search input field. Placeholder: "Ask anything..."
- **Below search bar**: Row of controls:
  - **Focus selector**: Dropdown defaulting to "Web." Options: Web, Academic, Social, Video, Writing, Math. Each restricts sources.
  - **Attach button**: For uploading files or images to include in the query.
  - **Pro Search toggle**: Enables deeper, multi-step research (Pro subscribers).
- **Suggested topics**: Trending or curated topics displayed as tappable cards.
- **Bottom tab bar**: Four tabs -- Home, Discover, Spaces, Library.

### 3.3 Bottom Tab Bar (Detail)

| Tab | Icon | Function |
|-----|------|----------|
| **Home** | House icon | Primary search interface. New query entry point. |
| **Discover** | Compass/explore icon | AI-curated news and trending topics. Browse headlines. Tap any item to ask follow-up questions. |
| **Spaces** | Grid/folder icon | Collaborative workspaces. Organize searches by project/topic. Upload reference files. Share with team members. Tap "+" to create new Space. |
| **Library** | Bookmark icon | Saved searches, recent query history, curated collections. More than just history -- acts as a personal knowledge base. |

### 3.4 Search/Query Flow

1. Tap the search bar on Home tab.
2. Keyboard opens. Focus mode selector visible above keyboard.
3. Type query (or use voice via iOS keyboard mic).
4. Optionally toggle Pro Search on.
5. Optionally select a Focus mode (Academic, Video, etc.).
6. Tap Send or press Return.

### 3.5 Answer Display

```
+--------------------------------------------------+
| [<back]     Query Title                           |
|                                                    |
|  SOURCES                                           |
|  [1] [2] [3] [4] [5]  (source pill badges)        |
|  (horizontal scrollable source cards)              |
|                                                    |
|  ANSWER                                            |
|  According to multiple sources [1][2], the         |
|  technology works by...                            |
|                                                    |
|  Key findings include:                             |
|  - Point one with citation [3]                     |
|  - Point two with citation [1][4]                  |
|  - Point three [5]                                 |
|                                                    |
|  RELATED                                           |
|  [Follow-up question 1?]                           |
|  [Follow-up question 2?]                           |
|  [Follow-up question 3?]                           |
|                                                    |
+--------------------------------------------------+
| [Ask follow-up...                          ] [send]|
+--------------------------------------------------+
```

**Answer display details:**
- **Sources section**: Appears ABOVE the answer. Shows numbered source badges (small pills with numbers [1], [2], etc.) and horizontally scrollable source cards showing website favicons, titles, and brief descriptions. Tapping a source card opens the source URL.
- **Answer body**: Well-formatted text with inline citation numbers. Citations are interactive -- tapping [1] highlights/navigates to the corresponding source card.
- **Markdown rendering**: Headers, lists, bold, tables, code blocks all rendered.
- **Live data cards**: For certain queries (flights, finance, weather), structured data cards appear inline with real-time information.
- **Related questions**: Below the answer, 2-4 AI-generated follow-up questions displayed as tappable chips. Tapping one immediately starts a new search in the same thread.
- **Thread continuation**: Below the related questions is a follow-up input bar for continuing the research thread.

### 3.6 Discover Tab

```
+--------------------------------------------------+
|           Discover                                 |
|                                                    |
|  TOP STORIES                                       |
|  [News card: headline + summary + image]           |
|  [News card: headline + summary + image]           |
|                                                    |
|  TECHNOLOGY                                        |
|  [Topic card] [Topic card] [Topic card]            |
|                                                    |
|  SCIENCE                                           |
|  [Topic card] [Topic card]                         |
|                                                    |
+--------------------------------------------------+
|  [Home]    [Discover]    [Spaces]    [Library]     |
+--------------------------------------------------+
```

- AI-curated news and topic cards.
- Each card is tappable -- opens a Perplexity-generated summary with sources.
- Can ask follow-up questions on any Discover item, and the active thread persists in the sidebar.

### 3.7 Spaces Tab

- Lists all created Spaces (collaborative research workspaces).
- Each Space has a name, description, and custom AI instructions.
- Tap "+" to create new Space.
- Inside a Space: see all threads, uploaded files, and shared members.
- Spaces support file uploads as persistent context for all queries within that Space.

### 3.8 Library Tab

- **Threads**: Recent search threads listed chronologically.
- **Collections**: User-curated groups of saved searches.
- Search bar at top for finding past queries.
- Long-press to delete, share, or organize threads.

### 3.9 Settings Access

1. Tap profile icon (top-left of Home tab).
2. Settings include:
   - Account details, subscription (Free vs. Pro).
   - AI Model preferences.
   - Default Focus mode.
   - Incognito mode toggle (prevents saving conversation history).
   - Notification settings.
   - Appearance (light/dark mode).
   - Connected accounts.

### 3.10 File Attachments

1. Tap Attach button near the search bar.
2. Select photo, document, or file from device.
3. File appears as a chip/thumbnail attached to the query.
4. Perplexity analyzes the file content alongside the search query.
5. Results reference file content with citations where applicable.

### 3.11 Empty States

- **Home (first use)**: Search bar centered with "Ask anything..." and trending topic suggestions below.
- **Library (empty)**: Message encouraging the user to start searching, with a CTA to go to Home.
- **Spaces (empty)**: Prompt to create first Space with explanation of what Spaces are for.

### 3.12 Voice Search

- Accessible via iOS keyboard microphone button (standard dictation).
- Native voice assistant mode (introduced April 2025): Background-capable voice search with fast response times. Accessible via a dedicated voice icon or the iOS widget.

---

## 4. GEMINI (GOOGLE) {#4-gemini}

### 4.1 First Launch Experience

1. **Splash Screen**: Google Gemini sparkle logo with multi-color gradient.
2. **Google Sign-In**: Uses existing Google account. Standard Google authentication flow.
3. **Terms/Permissions**: Privacy and data usage agreement.
4. **Landing**: Home screen with greeting and suggestion chips.

### 4.2 Home Screen Layout

```
+--------------------------------------------------+
| [chat history icon]          [account avatar]     |
|                                                    |
|                                                    |
|        "Hello, [Name]"                             |
|        (Gemini sparkle logo)                       |
|                                                    |
|  Suggestion chips (vertical layout):               |
|  [Create Image]                                    |
|  [Write]                                           |
|  [Build]                                           |
|  [Deep Research]                                   |
|  [Create Video]                                    |
|                                                    |
|  Secondary chips:                                  |
|  [Stay organized]  [Brief me]  [Do tasks for me]  |
|                                                    |
+--------------------------------------------------+
| [+] [Tools] [  Ask Gemini...          ] [mic]     |
+--------------------------------------------------+
```

**Key elements:**
- **Top-left**: Chat history icon (speech bubble icon). Tapping reveals conversation history drawer with: pinned chats at top, Gems (custom chatbots) below pinned chats, then recent conversations.
- **Top-right**: Google account avatar. Tapping opens account settings, subscription info, and app settings.
- **Center**: Personalized greeting ("Hello, [Name]") with Gemini sparkle logo. Below: suggestion chips arranged vertically (recent redesign, November 2025). Primary chips: Create Image, Write, Build, Deep Research, Create Video. Secondary row: Stay organized, Brief me, Do tasks for me.
- **Bottom**: Input bar pinned to bottom.
- **Color**: Light mode has a subtle gray/blue hue. Dark mode uses true black background with the prompt box maintaining a two-tone contrast look. Blue/purple accents. Gemini sparkle icon is blue-purple for free users, more red-tinted for Advanced subscribers.

### 4.3 Input Bar (Detail)

```
+--------------------------------------------------+
| [+]  [Tools]  [  Ask Gemini...       ]  [mic]    |
+--------------------------------------------------+
```

- **Left side**: "+" button. Tapping opens options to upload a file or photo, or select from Google Drive.
- **"Tools" button**: Replaced the old standalone chips and overflow menu (September 2025 redesign). Tapping opens a compact bottom sheet listing tools without icons or descriptions:
  - "Create videos with Veo"
  - "Create images"
  - "Deep Research"
  - "Canvas"
  - "Guided Learning"
  - Haptic feedback on tap.
- **Center**: Text field. Placeholder: "Ask Gemini..."
- **Right side**: Microphone icon for talk-to-text dictation. Tapping starts voice input.
- **Send button**: Appears when text is entered (replaces or appears alongside mic).
- **Suggestion chips below greeting disappear once the user begins typing.**

### 4.4 Chat History Drawer

Tap chat history icon (top-left):

```
+---------------------------+
|  PINNED CHATS              |
|  * "Trip planning"         |
|  * "Recipe collection"     |
|                            |
|  GEMS                      |
|  * "Writing Coach"         |
|  * "Code Reviewer"         |
|                            |
|  RECENT                    |
|  * "Image generation req"  |
|  * "Email draft help"      |
|  * ...                     |
|                            |
|  MY STUFF                  |
|  [3 recent generated items]|
|  [See all >]               |
+---------------------------+
```

- **Pinned chats** at top.
- **Gems**: Custom AI personas/chatbots the user has created or pinned. Each has a custom name and purpose.
- **Recent conversations**: Chronological list.
- **"My Stuff" folder** (new in redesign): Central repository for generated content -- images, documents, saved tasks. Shows 3 recent items with a "See all" link to fullscreen feed.
- Conversation history syncs across all devices via Google account.

### 4.5 Active Conversation Flow

```
+--------------------------------------------------+
| [<back]     Gemini                                |
|                                                    |
|  You:                                              |
|  "Create an image of a sunset over mountains"      |
|                                                    |
|  Gemini:                                           |
|  [Generated image grid: 2-4 variants]              |
|                                                    |
|  Here are some sunset images I created.            |
|  Which style do you prefer?                        |
|                                                    |
|  Suggested follow-ups:                             |
|  [Make it more dramatic]                           |
|  [Add a lake in the foreground]                    |
|  [Try a different art style]                       |
|                                                    |
+--------------------------------------------------+
| [+] [Tools] [  Ask Gemini...       ] [mic]        |
+--------------------------------------------------+
```

**Response display details:**
- **Streaming**: Text appears token-by-token.
- **Draft variants**: For some responses, Gemini offers multiple drafts. A "Show drafts" link appears, expanding to show 2-3 alternative phrasings/approaches.
- **Suggested follow-up questions**: Appear as tappable chips below each response (2-3 suggestions contextually related to the answer).
- **"Google It" button**: Small Google "G" icon on responses that can be fact-checked against web search results.
- **Code execution**: For Advanced users, code runs in a dual-pane view -- code on the left, output/errors on the right.
- **Generative UI**: For certain queries, Gemini dynamically creates custom interactive interfaces (charts, widgets, simulations) rendered inline. Two experiment modes: "Dynamic View" and "Visual Layout."
- **Image generation**: Images displayed in a grid of 2-4 variants.
- **Tables and charts**: Enhanced rendering for structured data, media cards with clean formatting.
- **Purple accents** on AI responses for visual distinction.

### 4.6 Gemini Live (Voice Conversation)

1. Tap the Gemini Live button (available from home screen widget or within the app).
2. Full-screen voice interface activates with animated visualization (morphing multi-colored gradient shapes).
3. Speak naturally -- Gemini responds with spoken audio in real-time.
4. **Voice personas**: Multiple options ("Mellow," "Glassy," etc.) with emotional tone variation.
5. **Camera and screen sharing**: Point phone camera at anything and discuss it live. Available free to all users on iOS and Android.
6. **Controls**: Mute button, end call button, text transcript appears alongside.
7. Exit returns to text chat with full transcript preserved.

### 4.7 Settings Access

1. Tap account avatar (top-right corner of home screen).
2. Settings include:
   - Account info and Google subscription tier.
   - Gemini Advanced / free tier management.
   - **Persistent memory** (Advanced users): View, edit, or wipe stored user preferences.
   - Language settings (40+ languages).
   - Voice persona selection.
   - Dark/light mode.
   - Data and privacy controls.

### 4.8 iOS Home Screen Widgets

Two widget options:
1. **Square widget (2x2 grid)**:
   - Top-left: Gemini sparkle icon (opens app and keyboard).
   - Microphone icon (start dictating a prompt).
   - Camera icon (take photo for Gemini analysis).
   - Gemini Live icon (launch full voice conversation).
2. **Rectangular widget**:
   - Pill-shaped "Ask Gemini" bar with microphone icon on the right.

### 4.9 Tab Structure

Gemini iOS does NOT use a traditional bottom tab bar. Navigation:
- **Chat history drawer** (top-left): Conversations, Gems, My Stuff.
- **Account/settings** (top-right): Profile and preferences.
- **Tools menu** (input bar): Access to specialized modes.
- **Home screen**: Central hub with suggestions and input.

### 4.10 Empty States

- **Home screen**: Personalized greeting + vertical suggestion chips. Never truly "empty" -- always shows actionable suggestions.
- **No conversations yet**: Suggestion chips and greeting serve as onboarding.
- **My Stuff (empty)**: Encouragement to create content with links to try image generation, writing, etc.

---

## 5. CROSS-APP COMPARISON TABLES {#5-comparison}

### 5.1 Navigation Architecture

| Feature | ChatGPT | Claude | Perplexity | Gemini |
|---------|---------|--------|------------|--------|
| **Bottom tab bar** | No | No | Yes (4 tabs) | No |
| **Sidebar** | Left (swipe/hamburger) | Left (swipe/icon) | No (uses tabs) | Left drawer (icon) |
| **Primary nav** | Sidebar + model picker | Sidebar + Projects | Bottom tabs | History drawer + Tools |
| **New chat** | Sidebar or "+" | Top-right compose icon | Home tab search bar | Home screen search bar |
| **Settings access** | Sidebar > "..." menu | Sidebar > profile | Profile icon (top-left) | Avatar (top-right) |

### 5.2 Input Bar Comparison

| Feature | ChatGPT | Claude | Perplexity | Gemini |
|---------|---------|--------|------------|--------|
| **Attach button** | "+" (left) | "+"/paperclip (left) | Attach near search bar | "+" (left) |
| **Voice dictation** | iOS keyboard mic | Mic icon (right) | iOS keyboard mic | Mic icon (right) |
| **Voice conversation** | Waveform icon (right) | Waveform icon (right) | N/A (voice assistant) | Gemini Live (separate) |
| **Send button** | Replaces waveform | Replaces voice icons | Right side | Replaces mic |
| **Tools/mode** | Model picker (top) | Web search toggle | Focus selector (above) | Tools button (left of field) |
| **Placeholder text** | "Message ChatGPT..." | "Message Claude..." | "Ask anything..." | "Ask Gemini..." |

### 5.3 Response Display Comparison

| Feature | ChatGPT | Claude | Perplexity | Gemini |
|---------|---------|--------|------------|--------|
| **Streaming** | Yes, token-by-token | Yes, token-by-token | Yes | Yes, token-by-token |
| **Code blocks** | Syntax highlighting + Copy | Syntax highlighting + Copy | Syntax highlighting | Syntax highlighting + execution |
| **Citations** | Web search inline numbers | Web search inline numbers | Core feature, numbered [1][2] | "Google It" fact-check button |
| **Source display** | Collapsible "Searched N sites" | Inline citation links | Scrollable source cards above answer | Link to Google search |
| **Follow-up suggestions** | Limited/none | None (user-driven) | 2-4 related questions | 2-3 suggested follow-ups |
| **Thinking trace** | Collapsible "Thinking..." block | Not visible | N/A | N/A |
| **Side panel** | Canvas (desktop only) | Artifacts (full-screen on phone) | N/A | Canvas (not yet on iOS) |
| **Draft variants** | No | No | No | Yes ("Show drafts") |
| **Generative UI** | No | No (Artifacts are closest) | Live data cards | Yes (Dynamic View, Visual Layout) |

### 5.4 Conversation History Comparison

| Feature | ChatGPT | Claude | Perplexity | Gemini |
|---------|---------|--------|------------|--------|
| **Organization** | Time-grouped + pins | Projects + conversations | Library + Spaces + Collections | Pins + Gems + My Stuff |
| **Search** | Yes (sidebar) | Yes (sidebar) | Yes (Library tab) | Evolving (limited) |
| **Pin conversations** | Yes (long-press) | No explicit pin | Via Collections | Yes (long-press) |
| **Rename** | Yes | Yes | Auto-titled threads | Yes |
| **Branching** | Yes (branch from any message) | No | No (new thread) | No |
| **Shared workspaces** | Team/Enterprise | Projects (Team plan) | Spaces | Google Workspace |
| **Offline access** | No | Yes (recent chats read-only) | No | No |

### 5.5 Empty State Patterns

| App | What User Sees |
|-----|---------------|
| **ChatGPT** | Logo centered, "What can I help with?" text, 2-4 suggested prompt chips, clean minimal layout |
| **Claude** | Logo centered, "How can I help you today?" text, 2-3 suggestion cards, purple accents |
| **Perplexity** | Search bar prominent, "Ask anything..." placeholder, Focus mode selector, trending topic cards below |
| **Gemini** | "Hello, [Name]" personalized greeting, vertical suggestion chips (Create Image, Write, Build, Deep Research, Create Video), secondary action chips |

---

## KEY PATTERNS ACROSS ALL APPS

1. **Input bar is always pinned to the bottom** of the screen, persistent across all states.
2. **Streaming text is universal** -- all apps display responses token-by-token.
3. **Voice is a first-class input** -- all apps offer voice dictation at minimum, with ChatGPT, Claude, and Gemini offering full voice conversation modes.
4. **No bottom tab bar** is the norm for pure chat apps (ChatGPT, Claude, Gemini). Perplexity is the exception because it is search-first, not chat-first.
5. **Sidebar navigation** is the dominant pattern for conversation history on chat-focused apps.
6. **Suggestion chips/cards on empty state** -- every app fills the new-chat screen with actionable prompts rather than leaving it empty.
7. **File attachment via "+" or paperclip** icon on the left side of the input bar is universal.
8. **Model/mode selection** lives above or near the input area, not buried in settings.
9. **Canvas/Artifacts side panels** exist only on desktop/web. On mobile, they go full-screen with a back button.
10. **Settings are 2 taps away** -- accessible from the sidebar or a profile icon, never requiring deep navigation.

---

## SOURCES

- [Comparing Conversational AI Tool User Interfaces 2025 (IntuitionLabs)](https://intuitionlabs.ai/articles/conversational-ai-ui-comparison-2025)
- [ChatGPT iOS App FAQ (OpenAI Help Center)](https://help.openai.com/en/articles/7885016-chatgpt-ios-app-faq)
- [ChatGPT Release Notes (OpenAI)](https://help.openai.com/en/articles/6825453-chatgpt-release-notes)
- [ChatGPT Model Picker Update (TechCrunch)](https://techcrunch.com/2025/08/12/chatgps-model-picker-is-back-and-its-complicated/)
- [ChatGPT Canvas Feature (OpenAI Help Center)](https://help.openai.com/en/articles/9930697-what-is-the-canvas-feature-in-chatgpt-and-how-do-i-use-it)
- [ChatGPT Voice Mode FAQ (OpenAI)](https://help.openai.com/en/articles/8400625-voice-chat-faq)
- [ChatGPT Branched Chats on iOS (TechRadar)](https://www.techradar.com/ai-platforms-assistants/chatgpt/the-chatgpt-app-just-got-a-big-upgrade-on-ios-and-android-to-stop-your-chats-spiraling-out-of-control)
- [ChatGPT File Uploads FAQ (OpenAI)](https://help.openai.com/en/articles/8555545-file-uploads-faq)
- [How to Use ChatGPT on iPhone Like a Pro (iAppList)](https://iapplist.com/use-chatgpt-like-a-pro/)
- [Claude iOS App Help Center](https://support.claude.com/en/articles/11869619-using-claude-with-ios-apps)
- [Claude App Intents and Widgets on iOS (Claude Help Center)](https://support.claude.com/en/articles/10263469-using-claude-app-intents-shortcuts-and-widgets-on-ios)
- [Claude Voice Mode (Claude Help Center)](https://support.claude.com/en/articles/11101966-using-voice-mode)
- [Claude Artifacts Explained (Anthropic)](https://support.claude.com/en/articles/9487310-what-are-artifacts-and-how-do-i-use-them)
- [Claude Artifacts Guide (Albato)](https://albato.com/blog/publications/how-to-use-claude-artifacts-guide)
- [How to Use Claude on Mobile (c-ai.chat)](https://c-ai.chat/blog/how-to-use-claude-on-mobile/)
- [Perplexity AI Complete Guide (LearnPrompting)](https://learnprompting.org/blog/guide-perplexity)
- [Perplexity Mobile App Tutorial (NewPerplexityAI)](https://newperplexityai.com/perplexity-ai-mobile-app-tutorial/)
- [Perplexity Spaces Help Center](https://www.perplexity.ai/help-center/en/articles/10352961-what-are-spaces)
- [Perplexity iOS App UI (SaaSUI)](https://www.saasui.design/application/perplexity-ai)
- [Perplexity iOS App UI (Banani)](https://www.banani.co/references/apps/perplexity)
- [Gemini iOS Getting Started (Google Support)](https://support.google.com/gemini/answer/14554984?hl=en&co=GENIE.Platform%3DiOS)
- [Gemini Tools Redesign (9to5Google)](https://9to5google.com/2025/09/15/gemini-tools-redesign-android-ios/)
- [Gemini 3 Pro iOS Redesign (9to5Google)](https://9to5google.com/2025/11/19/gemini-3-pro-android-ios/)
- [Gemini Homescreen Widgets iPhone (9to5Google)](https://9to5google.com/2025/04/30/gemini-iphone-homescreen-widgets/)
- [Gemini UX 2.0 Overhaul (Gemini.org.in)](https://www.gemini.org.in/gemini/2025/12/gemini-ux-2-0-overhaul)
- [Gemini App Updates Google I/O 2025 (Google Blog)](https://blog.google/products-and-platforms/products/gemini/gemini-app-updates-io-2025/)
- [ChatGPT iOS Screens (Mobbin)](https://mobbin.com/explore/screens/c176ae9f-5a25-45b6-acda-5620364105df)
- [Perplexity iOS Animations (60fps.design)](https://60fps.design/apps/perplexity)
- [OpenAI UI Guidelines for Apps SDK](https://developers.openai.com/apps-sdk/concepts/ui-guidelines)
