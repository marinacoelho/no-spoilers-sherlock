# 🏛️ ADR-0001: No Spoilers, Sherlock — Native iOS & AppCore Modular Architecture

- **Status**: Accepted
- **Date**: 2026-10-21
- **Author**: Senior Architect Agent (`@senior-architect`)
- **Related Spec**: [`docs/specs/prd-0001-no-spoilers-sherlock-ios.md`](../specs/prd-0001-no-spoilers-sherlock-ios.md)

---

## 1. Context & Problem Statement

Readers progressing through Sir Arthur Conan Doyle's *Sherlock Holmes* novels need a reading companion capable of answering chapter-scoped questions and generating period-accurate 1880s Victorian illustrations without leaking plot twists, culprit identities, or character deaths from future chapters.

While the Android reference application achieved this through a two-layer spoiler guardrail (database-level chunk filtering + strict LLM system prompt guardrails), the Apple workspace (`frontend/apple/`) currently contains only a starter scaffold (`ContentView.swift` and an empty `AppCore` Swift Package) with an invalid hyphenated `@main struct no-spoilers-sherlockApp` declaration and raw `"no-spoilers-sherlock"` display name.

We must design a native iOS 26+ / Swift 6 architecture that satisfies the following technical forces and constraints:
1. **Two-Layer Zero-Spoiler Guarantee (`G-1`, `FR-3`–`FR-7`)**: Every user query and scene visualization request must first filter book chunks strictly to `chapterOrder <= targetChapterOrder` before constructing a prompt with explicit negative constraints (`STRICT SPOILER GUARDBOUND`).
2. **UI-Independent Domain & State Package (`G-5`, `FR-1`–`FR-10`)**: `frontend/apple/Packages/AppCore/` must compile and pass `swift test --package-path frontend/apple/Packages/AppCore` on both macOS and iOS with zero external SPM dependencies (`Foundation` + `Observation` only) and without importing `UIKit`. Binary illustration payloads must cross boundaries as `Data` (`Foundation`) rather than `UIImage`.
3. **Swift 6 Strict Concurrency & Proper App Naming**: Both `AppCore` (`swift-tools-version: 6.0`) and `no-spoilers-sherlock` must compile with zero data-race warnings or errors. The `@main` entry point must use valid PascalCase Swift syntax (`struct NoSpoilersSherlockApp: App`), and `INFOPLIST_KEY_CFBundleDisplayName` must be `"No Spoilers, Sherlock"` while preserving the `frontend/apple/no-spoilers-sherlock.xcodeproj` and `-s no-spoilers-sherlock` scheme paths required by `AGENTS.md`.
4. **iOS 26+ Native SwiftUI Liquid Glass (`apple-flo-liquid-glass`)**: Interactive controls, badges, bottom bars, and HUD overlays must leverage native iOS 26+ Liquid Glass APIs (`.buttonStyle(.glass)`, `.buttonStyle(.glassProminent)`, `.buttonBorderShape(...)`, `.glassEffect(.regular, in: ...)`, `GlassEffectContainer`, `.safeAreaBar(edge: .bottom)`, and `.sharedBackgroundVisibility(.hidden)`) while strictly avoiding Liquid Glass inside `ScrollView` message rows.
5. **Resilient Offline & CI Execution (`FR-2`, `AC-13`)**: Local development, CI pipelines, and `flowdeck test` runs frequently execute without a live `GoogleService-Info.plist`, network connectivity, or Gemini API billing. The architecture must support seamless dependency injection with a seeded in-memory/Firestore repository and deterministic spoiler-bounded AI fallback (including a valid pre-encoded period-styled PNG `Data` payload) so all acceptance criteria (`AC-1` through `AC-13`) work out of the box.

---

## 2. Decision & Architectural Invariants

We adopt a **Two-Tier Modular Clean Architecture** split cleanly between the platform-agnostic `AppCore` Swift Package and the native iOS 26+ SwiftUI Liquid Glass application target `no-spoilers-sherlock`.

### Architectural Invariants

1. **Invariant 1 — Zero External SPM Dependencies in `AppCore` (`Foundation` + `Observation` Only)**:
   `AppCore` MUST have zero external Swift Package dependencies in `Package.swift` and depend solely on `Foundation` and `Observation`. It MUST NOT import `UIKit` or `SwiftUI` in domain/service files. Scene illustrations are stored and transported as `imageData: Data?` inside `ChatMessage`. Any optional Firebase SDK adapters in the iOS app target MUST be guarded by `#if canImport(FirebaseCore)` (and `#if canImport(FirebaseFirestore)` / `#if canImport(FirebaseAILogic)`).
2. **Invariant 2 — Two-Layer Spoiler Guardrail Enforcement & Boundary Clamping**:
   No user prompt is ever sent raw to an AI model. `ChatViewModel` MUST always:
   - Extract explicit positive chapter numbers via `SpoilerGuardManager.extractChapterFromPrompt(prompt)` (which rejects zero or negative numbers like `"chapter -2"` or `"chapter 0"` and returns `nil`), fall back to `defaultChapter` (or `lastDetectedChapter` for follow-up visualizations), and clamp the effective `targetChapter` to `1...selectedBook.totalChapters` (defaulting to `1...14`).
   - Fetch chunks exclusively via `BookRepositoryProtocol.getSpoilerBoundedChunks(bookId:targetChapterOrder:)`, which enforces `chunk.bookId == bookId && $0.chapterOrder <= targetChapterOrder` sorted by `chapterOrder` ascending.
   - Wrap the filtered chunks in `SpoilerGuardManager.buildSpoilerGuardrailPrompt(...)` or `SpoilerGuardManager.buildSceneVisualizationPrompt(...)`.
3. **Invariant 3 — Swift 6 Strict Concurrency & Proper PascalCase App Entry Point**:
   - All domain value types (`Book`, `Chapter`, `Chunk`, `MessageSender`, `ChatMessage`, `SceneIllustrationResult`) MUST conform to `Sendable`, `Equatable`, and `Codable`, with defaulted `public init` initializers matching Android's data models.
   - Service protocols (`BookRepositoryProtocol`, `AiServiceProtocol`) MUST refine `Sendable` so they can be safely called across actor boundaries from `@MainActor`.
   - `ChatViewModel` MUST be annotated with `@Observable @MainActor public final class ChatViewModel`.
   - The app entry point MUST be declared as `@main struct NoSpoilersSherlockApp: App` (replacing the invalid `struct no-spoilers-sherlockApp`), and `INFOPLIST_KEY_CFBundleDisplayName` in `project.pbxproj` MUST be set to `"No Spoilers, Sherlock"`.
4. **Invariant 4 — Native iOS 26+ SwiftUI Liquid Glass Hygiene (`apple-flo-liquid-glass`)**:
   - **No Fake Glass**: Never recreate Liquid Glass with custom materials, blurs, outlines, or drop shadows.
   - **Buttons**: Use `.buttonStyle(.glass)` for neutral/secondary actions (Book Filter Chip, QuickPromptSuggestions chips, `"Reset Zoom"`, `"Close"`) and `.buttonStyle(.glassProminent).tint(SherlockTheme.victorianGold)` for primary/tinted actions (Send button), shaped with `.buttonBorderShape(...)`.
   - **Custom Non-Button Surfaces**: Use `.glassEffect(.regular, in: ...)` for custom status/HUD surfaces (`AiStatusBadge`, `SherlockInvestigatingIndicator`, `ZoomableImageDialog` top and bottom HUD bars, and custom `ChatInputBar` field container).
   - **Grouped Glass**: Wrap adjacent Liquid Glass elements in `GlassEffectContainer(spacing: ...)` (e.g., top bar Book Filter Chip + `AiStatusBadge`, bottom `ChatInputBar` text field + Send button, and `ZoomableImageDialog` `"Reset Zoom"` + `"Close"` buttons).
   - **Bottom Bar**: Anchor the bottom stack (`SherlockInvestigatingIndicator`, `QuickPromptSuggestions`, `ChatInputBar`) using `.safeAreaBar(edge: .bottom)` rather than `VStack` overlays.
   - **No Glass Inside `ScrollView`**: Never apply `.glassEffect`, `.buttonStyle(.glass)`, or `.buttonStyle(.glassProminent)` to views inside the scrolling message list (`ModernMessageBubble` and `EmptyChatHero` cards MUST use solid Victorian Detective theme colors/surfaces).
   - **Toolbar Hygiene**: When using `.toolbar`, apply `.sharedBackgroundVisibility(.hidden)` directly on `ToolbarItem` for items that render their own custom glass or non-glass backgrounds.
5. **Invariant 5 — Resilient Runtime Fallback & Pre-Encoded PNG Payload**:
   At launch, `AppDependencyContainer` checks whether `GoogleService-Info.plist` is present in `Bundle.main` and whether Firebase SDKs are linked (`#if canImport(FirebaseCore)`). If absent or offline, `InMemorySeededBookRepository` (pre-seeded with both `"study_in_scarlet"` and `"sign_of_the_four"`) and `DeterministicSherlockAiService` (which synthesizes chapter-accurate answers and returns a valid pre-encoded Victorian-tinted PNG `Data` payload) provide 100% functional parity so `UIImage(data:)` / `NSImage(data:)` always decodes a non-nil image.

---

## 3. Architecture / Component Breakdown

### 3.1 Directory, Module & Xcode Scheme Mapping

```text
frontend/apple/
├── no-spoilers-sherlock.xcodeproj/
│   ├── project.pbxproj                               # IPHONEOS_DEPLOYMENT_TARGET = 26.0, CFBundleDisplayName = "No Spoilers, Sherlock"
│   └── xcshareddata/xcschemes/
│       └── no-spoilers-sherlock.xcscheme             # MUST include AppCoreTests (and/or iOS test target) in <TestAction><Testables>
├── Packages/
│   └── AppCore/
│       ├── Package.swift                             # Zero external dependencies (Foundation + Observation only)
│       ├── Sources/
│       │   └── AppCore/
│       │       ├── AppCore.swift
│       │       ├── Models/
│       │       │   └── BookModels.swift              # Book, Chapter, Chunk, MessageSender, ChatMessage, SceneIllustrationResult
│       │       ├── Domain/
│       │       │   └── SpoilerGuardManager.swift     # Regex chapter extraction (>0), keyword detection, guardrail prompts
│       │       ├── Data/
│       │       │   ├── BookRepositoryProtocol.swift  # Protocol + InMemorySeededBookRepository (study_in_scarlet + sign_of_the_four)
│       │       │   └── AiServiceProtocol.swift       # Protocol + DeterministicSherlockAiService (spoiler-safe + valid PNG Data)
│       │       └── ViewModel/
│       │           └── ChatViewModel.swift           # @Observable @MainActor state & workflow orchestration
│       └── Tests/
│           └── AppCoreTests/
│               └── AppCoreTests.swift                # Swift Testing (@Suite, @Test) unit tests for AC-1..AC-9
└── no-spoilers-sherlock/
    ├── NoSpoilersSherlockApp.swift                   # @main struct NoSpoilersSherlockApp: App & DI root
    ├── ContentView.swift                             # Root host forwarding to ChatScreen
    ├── Services/
    │   └── AppDependencyContainer.swift              # #if canImport(FirebaseCore) detection vs Seeded/Fallback adapters
    ├── Theme/
    │   └── SherlockTheme.swift                       # Victorian Detective color tokens & cross-platform Image decoder
    └── Views/
        ├── ChatScreen.swift                          # NavigationStack, .toolbar + GlassEffectContainer, .safeAreaBar(edge: .bottom)
        ├── ModernMessageBubble.swift                 # Solid Victorian cards inside ScrollView (NO Liquid Glass inside ScrollView!)
        ├── EmptyChatHero.swift                       # "The Game is Afoot" empty state + 4 starter cards
        ├── SherlockInvestigatingIndicator.swift      # .glassEffect(.regular, in: .capsule) pulsing indicator in bottom safeAreaBar
        ├── QuickPromptSuggestions.swift              # Horizontal book-aware suggestion chips (.buttonStyle(.glass)) in bottom safeAreaBar
        ├── ChatInputBar.swift                        # GlassEffectContainer with .glassEffect field + .buttonStyle(.glassProminent) Send
        ├── BookSelectionSheet.swift                  # Modal bottom sheet for selecting novels
        └── ZoomableImageDialog.swift                 # Full-screen 1x-5x zoom/pan inspector with Liquid Glass HUD bars
```

> **Xcode Project & Scheme Requirements (`project.pbxproj` & `no-spoilers-sherlock.xcscheme`)**:
> 1. **Proper Display Name & Entry Point**: Set `INFOPLIST_KEY_CFBundleDisplayName = "No Spoilers, Sherlock";` in `project.pbxproj`, and rename the `@main` struct from `struct no-spoilers-sherlockApp: App` (invalid Swift identifier) to `struct NoSpoilersSherlockApp: App` in `NoSpoilersSherlockApp.swift` (or `no-spoilers-sherlockApp.swift`). Keep the Xcode project path (`frontend/apple/no-spoilers-sherlock.xcodeproj`) and scheme name (`no-spoilers-sherlock`) intact so `flowdeck test -w frontend/apple/no-spoilers-sherlock.xcodeproj -s no-spoilers-sherlock` works as mandated by `AGENTS.md`.
> 2. **Scheme Testables**: Register `AppCoreTests` (`BuildableName = "AppCoreTests"`, `BlueprintName = "AppCoreTests"`, `ReferencedContainer = "container:Packages/AppCore"`) and/or a native iOS unit test target inside `<TestAction><Testables>` in `no-spoilers-sherlock.xcscheme` so `flowdeck test` executes cleanly (`AC-13`).

### 3.2 `AppCore` Contracts & Types (`frontend/apple/Packages/AppCore`)

#### 1. Domain Models (`Models/BookModels.swift`)
All models provide defaulted `public init` signatures mirroring Android's data classes:

```swift
import Foundation

public struct Book: Sendable, Equatable, Identifiable, Codable {
    public let id: String
    public let universeId: String
    public let bookOrder: Int
    public let title: String
    public let author: String
    public let totalChapters: Int

    public init(
        id: String = "",
        universeId: String = "",
        bookOrder: Int = 1,
        title: String = "",
        author: String = "",
        totalChapters: Int = 1
    ) {
        self.id = id
        self.universeId = universeId
        self.bookOrder = bookOrder
        self.title = title
        self.author = author
        self.totalChapters = totalChapters
    }
}

public struct Chapter: Sendable, Equatable, Identifiable, Codable {
    public let id: String
    public let bookId: String
    public let chapterOrder: Int
    public let title: String

    public init(
        id: String = "",
        bookId: String = "",
        chapterOrder: Int = 1,
        title: String = ""
    ) {
        self.id = id
        self.bookId = bookId
        self.chapterOrder = chapterOrder
        self.title = title
    }
}

public struct Chunk: Sendable, Equatable, Identifiable, Codable {
    public let id: String
    public let bookId: String
    public let bookOrder: Int
    public let chapterId: String
    public let chapterOrder: Int
    public let chunkIndex: Int
    public let content: String

    public init(
        id: String = "",
        bookId: String = "",
        bookOrder: Int = 1,
        chapterId: String = "",
        chapterOrder: Int = 1,
        chunkIndex: Int = 1,
        content: String = ""
    ) {
        self.id = id
        self.bookId = bookId
        self.bookOrder = bookOrder
        self.chapterId = chapterId
        self.chapterOrder = chapterOrder
        self.chunkIndex = chunkIndex
        self.content = content
    }
}

public enum MessageSender: String, Sendable, Equatable, Codable {
    case user
    case ai
    case system
}

public struct ChatMessage: Sendable, Equatable, Identifiable, Codable {
    public let id: String
    public let sender: MessageSender
    public let text: String
    public let timestamp: Int64
    public let extractedChapter: Int?
    public let citedChapters: [Int]
    public let isOfflineMode: Bool
    public let imageData: Data?
    public let isSceneVisualization: Bool

    public init(
        id: String = UUID().uuidString,
        sender: MessageSender,
        text: String,
        timestamp: Int64 = Int64(Date().timeIntervalSince1970 * 1000),
        extractedChapter: Int? = nil,
        citedChapters: [Int] = [],
        isOfflineMode: Bool = false,
        imageData: Data? = nil,
        isSceneVisualization: Bool = false
    ) {
        self.id = id
        self.sender = sender
        self.text = text
        self.timestamp = timestamp
        self.extractedChapter = extractedChapter
        self.citedChapters = citedChapters
        self.isOfflineMode = isOfflineMode
        self.imageData = imageData
        self.isSceneVisualization = isSceneVisualization
    }
}

public struct SceneIllustrationResult: Sendable, Equatable, Codable {
    public let caption: String
    public let imageData: Data?

    public init(caption: String, imageData: Data?) {
        self.caption = caption
        self.imageData = imageData
    }
}
```

#### 2. Spoiler Guardrail Engine (`Domain/SpoilerGuardManager.swift`)
Stateless `Sendable` struct/enum encapsulating deterministic text analysis, chapter boundary validation, and prompt synthesis:
- `public static func extractChapterFromPrompt(_ prompt: String) -> Int?`
  - Rejects negative chapter patterns (e.g., `(?:chapter|chap|ch\.?)\s*-\d+` or `-\d+(?:st|nd|rd|th)?\s*chapter`) by returning `nil`.
  - Evaluates Pattern 1 (`\b(?:chapter|chap|ch\.?)\s*(\d+)\b`, case-insensitive) and Pattern 2 (`\b(\d+)(?:st|nd|rd|th)?\s*chapter\b`, case-insensitive).
  - Returns the parsed integer only if `chapter > 0`; otherwise returns `nil`.
- `public static func clampChapter(_ chapter: Int, totalChapters: Int) -> Int`
  - Clamps any resolved chapter integer to `max(1, min(chapter, max(1, totalChapters)))`.
- `public static func isVisualizationRequest(_ prompt: String) -> Bool`
  - Case-insensitive containment check against `["visualize", "visualise", "illustrate", "draw", "sketch", "picture", "show me the scene", "generate an image", "generate image", "scene of", "depict", "portrait of"]`.
- `public static func buildSpoilerGuardrailPrompt(bookTitle: String, targetChapter: Int, userQuery: String, retrievedChunks: [Chunk]) -> String`
  - Strips `^Summary of Chapter \d+ \([^)]+\):\s*` prefixes from chunk contents, formats `- Chapter X: <cleanContent>` (or `"No prior chapter excerpts found."` if empty), and returns the exact system prompt with `STRICT SPOILER GUARDBOUND` and `Sherlock's Direct Answer (ZERO SPOILERS beyond Chapter \(targetChapter)! Do not list chapters):`.
- `public static func buildSceneVisualizationPrompt(bookTitle: String, targetChapter: Int, userQuery: String, retrievedChunks: [Chunk]) -> String`
  - Formats chunks identically and produces the Sidney Paget *Strand Magazine* 1880s Victorian pen-and-ink illustration prompt bounded to `CHAPTER \(targetChapter)`.

#### 3. Repository Layer (`Data/BookRepositoryProtocol.swift`)
```swift
public protocol BookRepositoryProtocol: Sendable {
    func ensureSampleDataPopulated() async throws
    func getBooks() async throws -> [Book]
    func getChapters(bookId: String) async throws -> [Chapter]
    func getSpoilerBoundedChunks(bookId: String, targetChapterOrder: Int) async throws -> [Chunk]
}
```
- `InMemorySeededBookRepository`: Thread-safe `actor` implementing `BookRepositoryProtocol`.
  - Seeds two books so book switching (`US-5`, `FR-12`, `FR-16`) works immediately offline:
    1. `"study_in_scarlet"`: `Book(id: "study_in_scarlet", universeId: "sherlock_holmes", bookOrder: 1, title: "A Study in Scarlet", author: "Sir Arthur Conan Doyle", totalChapters: 14)`
    2. `"sign_of_the_four"`: `Book(id: "sign_of_the_four", universeId: "sherlock_holmes", bookOrder: 2, title: "The Sign of the Four", author: "Sir Arthur Conan Doyle", totalChapters: 12)`
  - Seeds Chapters 1–7 for `"study_in_scarlet"` (`"study_in_scarlet_ch01"` .. `"study_in_scarlet_ch07"`, `"chunk_study_in_scarlet_ch01_001"` .. `"chunk_study_in_scarlet_ch07_001"`) using the **exact verbatim strings** from Android's `FirestoreRepository.kt`:
    1. Ch 1 (`"Mr. Sherlock Holmes"`): `"In 1878 I took my degree of Doctor of Medicine at the University of London... There I met Stamford and learned of Sherlock Holmes searching for a companion to share rooms at 221B Baker Street."`
    2. Ch 2 (`"The Science of Deduction"`): `"Sherlock Holmes was a man who performed strange chemical experiments and possessed exact knowledge of crime history. He explained his deduction methods from a magazine article."`
    3. Ch 3 (`"The Lauriston Garden Mystery"`): `"A telegram arrives from Inspector Tobias Gregson regarding a murder at 3 Lauriston Gardens near Brixton Road. The dead man is identified as Enoch J. Drebber of Cleveland, Ohio. The word 'RACHE' is written in blood on the wall."`
    4. Ch 4 (`"What John Rance Had to Tell"`): `"Constable John Rance recalls seeing a drunk man lurking outside Lauriston Gardens near the crime scene. Holmes deduces the drunk man was actually the murderer returning for the ring."`
    5. Ch 5 (`"Our Advertisement Brings a Visitor"`): `"Holmes places an advertisement in the newspaper offering a lost gold wedding ring found in Brixton Road. An old woman named Mrs. Sawyer arrives at 221B Baker Street to claim it."`
    6. Ch 6 (`"Tobias Gregson Shows What He Can Do"`): `"Inspector Gregson arrests Arthur Charpentier, son of the boarding-house keeper where Drebber stayed, believing he committed the crime due to a quarrel."`
    7. Ch 7 (`"Light in the Darkness"`): `"Inspector Lestrade arrives with shocking news: Joseph Stangerson, secretary to Enoch Drebber, has also been murdered at Halliday's Private Hotel!"`
  - Seeds Chapters 1–4 for `"sign_of_the_four"` (Miss Mary Morstan's pearls in Ch 2, Bartholomew Sholto found dead at Pondicherry Lodge with the wooden-legged man's thorn clue in Ch 4) so switching to *The Sign of the Four* and tapping its suggestion chips (`FR-16`) returns rich, spoiler-bounded answers.
  - Filtering invariant: `chunks.filter { $0.bookId == bookId && $0.chapterOrder <= targetChapterOrder }.sorted { $0.chapterOrder < $1.chapterOrder }`.

#### 4. AI Service Layer (`Data/AiServiceProtocol.swift`)
```swift
public protocol AiServiceProtocol: Sendable {
    func checkAndDownloadOnDeviceModel() async -> String?
    func noSpoilerAnswer(prompt: String) async throws -> String
    func generateSceneIllustration(prompt: String) async throws -> SceneIllustrationResult
}
```
- `DeterministicSherlockAiService`: Implements `AiServiceProtocol`.
  - Parses the spoiler-bounded context inside `prompt` to synthesize concise 1–3 sentence spoiler-free answers citing only facts present in the bounded chapters.
  - Embeds a valid pre-encoded PNG `Data` constant (a valid binary PNG header + IHDR + IDAT + IEND bytes representing a warm Victorian sepia/gold canvas) so `UIImage(data:)` on iOS and `NSImage(data:)` on macOS always decode a non-nil image (`AC-9`, `AC-12`).

#### 5. ViewModel Orchestration (`ViewModel/ChatViewModel.swift`)
```swift
@Observable
@MainActor
public final class ChatViewModel {
    public private(set) var books: [Book] = []
    public private(set) var selectedBook: Book?
    public private(set) var messages: [ChatMessage] = []
    public private(set) var isLoading: Bool = false
    public private(set) var statusMessage: String?
    public private(set) var onDeviceStatus: String?
    public private(set) var defaultChapter: Int = 3
    public private(set) var lastDetectedChapter: Int = 3
    // ...
}
```
- Key public methods matching Android's `ChatViewModel.kt`:
  - `public func loadBooksAndInit() async`: Sets `isLoading = true`, calls `ensureSampleDataPopulated()`, loads `books` (falling back to *A Study in Scarlet* if empty), sets `selectedBook = books.first`, sets `messages = [welcomeMessage(for: initialBook)]`, sets `isLoading = false`, and queries `checkAndDownloadOnDeviceModel()`.
  - `public func selectBook(_ book: Book)`: Updates `selectedBook = book`, resets `lastDetectedChapter = defaultChapter`, and resets `messages` to `[ChatMessage(sender: .system, text: "📖 Switched book to '\(book.title)'. Ask any question and include your chapter!")]` (matching Android `ChatViewModel.selectBook` and `FR-12`).
  - `public func setDefaultChapter(_ chapterNum: Int)`: Updates `defaultChapter = max(1, chapterNum)`.
  - `public func sendMessage(_ userText: String) async`: Ignores blank input; extracts and clamps chapter (`SpoilerGuardManager.clampChapter(extracted, totalChapters: activeBook.totalChapters)`); delegates to `visualizeScene(userText, targetChapter: clampedChapter)` if `isVisualizationRequest(userText)` is `true`; otherwise appends `.user` message, fetches spoiler-bounded chunks, builds guardrail prompt, calls `aiService.noSpoilerAnswer(prompt:)`, and appends `.ai` message with `extractedChapter` and `citedChapters`.
  - `public func visualizeScene(_ sceneQuery: String, targetChapter: Int? = nil) async`: Resolves and clamps chapter (`targetChapter ?? extractChapterFromPrompt(sceneQuery) ?? lastDetectedChapter ?? defaultChapter`), appends `.user` message, fetches spoiler-bounded chunks, builds scene visualization prompt, calls `aiService.generateSceneIllustration(prompt:)`, and appends `.ai` message with `isSceneVisualization = true`, `imageData`, `extractedChapter`, and `citedChapters`.

### 3.3 Native SwiftUI & iOS 26+ Liquid Glass Layer (`frontend/apple/no-spoilers-sherlock`)

1. **`SherlockTheme.swift` & Cross-Platform Image Helper**:
   - Defines static `Color` constants matching `FR-11`: `detectiveNavyDark` (`#0B132B`), `detectiveNavyMedium` (`#1C2541`), `detectiveNavyLight` (`#3A506B`), `victorianGold` (`#D4AF37`), `victorianGoldLight` (`#F3E5AB`), `parchmentCream` (`#F4F1DE`), `spoilerRedAccent` (`#E63946`), `citationGreen` (`#2A9D8F`).
   - Provides a cross-platform `SherlockPlatformImage.swiftUIImage(from data: Data) -> Image?` helper using `#if canImport(UIKit)` (`UIImage(data:)`) and `#elseif canImport(AppKit)` (`NSImage(data:)`) so multi-platform Xcode destinations compile without error.
2. **`AppDependencyContainer.swift`**:
   - Guarded by `#if canImport(FirebaseCore)` for optional live Firebase integration; defaults seamlessly to `InMemorySeededBookRepository` and `DeterministicSherlockAiService` when `GoogleService-Info.plist` or Firebase SDKs are absent.
3. **`ChatScreen.swift` (Liquid Glass Navigation & `.safeAreaBar(edge: .bottom)`)**:
   - Hosts `@State private var viewModel: ChatViewModel`, `@State private var inputText: String = ""`, `@State private var showBookBottomSheet: Bool = false`, and `@State private var selectedImageMessage: ChatMessage?`.
   - **Top Bar & Toolbar Hygiene (`apple-flo-liquid-glass` Rules #2, #5, #6, #9)**:
     - Displays `"No Spoilers, Sherlock"` navigation title.
     - Groups the interactive Book Filter Chip (`Button` with `.buttonStyle(.glass)` and `.buttonBorderShape(.capsule)`, `accessibilityIdentifier("bookSelectorChip")`) and `AiStatusBadge` (custom view with `.glassEffect(.regular, in: .capsule)`, `accessibilityIdentifier("aiStatusBadge")`) inside a `GlassEffectContainer(spacing: 8)`.
     - If placed inside `.toolbar { ToolbarItem(...) }`, applies `.sharedBackgroundVisibility(.hidden)` on the `ToolbarItem` so the system toolbar does not double-wrap custom Liquid Glass elements.
   - **Message ScrollView (`apple-flo-liquid-glass` Rule #7)**:
     - Scrollable message list using `ScrollViewReader` that auto-scrolls to `messages.last?.id` on `messages.count` change, or shows `EmptyChatHero` when `messages.isEmpty`.
     - Strictly avoids `.glassEffect` or `.buttonStyle(.glass)` inside `ScrollView` content.
   - **Bottom Bar (`apple-flo-liquid-glass` Rule #8)**:
     - Uses `.safeAreaBar(edge: .bottom)` on the main content view to anchor `SherlockInvestigatingIndicator` (when `viewModel.isLoading`), `QuickPromptSuggestions`, and `ChatInputBar`.
   - Presents `BookSelectionSheet` via `.sheet(isPresented: $showBookBottomSheet)` and `ZoomableImageDialog` via `.fullScreenCover(item: $selectedImageMessage)` (or cross-platform overlay).
4. **`ModernMessageBubble.swift` & `EmptyChatHero.swift` (Solid Victorian Surfaces Inside `ScrollView`)**:
   - Per `apple-flo-liquid-glass` Rule #7 (*"avoid using liquid glass inside ScrollView and List"*), `ModernMessageBubble` and `EmptyChatHero` use solid Victorian Detective theme surfaces (`SherlockTheme.detectiveNavyMedium`, `SherlockTheme.victorianGold`, `SherlockTheme.parchmentCream`).
   - Renders user bubbles trailing and AI/system bubbles leading with the 32pt circular avatar.
   - Uses `Text(LocalizedStringKey(message.text))` for native Markdown rendering.
   - Decodes `message.imageData` via `SherlockPlatformImage.swiftUIImage(from:)` inside an interactive card with the `"Examine"` badge (`accessibilityIdentifier("examineImageCard")`) and `"Sidney Paget Victorian Style • Nano Banana AI"` footer.
   - Renders the `"Visualize Scene (Ch. X)"` pill button (`accessibilityIdentifier("visualizeSceneButton_\(chapter)")`) below qualifying AI responses using solid Victorian styling inside the `ScrollView`.
5. **`SherlockInvestigatingIndicator.swift`, `QuickPromptSuggestions.swift`, & `ChatInputBar.swift` (Bottom `.safeAreaBar` Liquid Glass)**:
   - `SherlockInvestigatingIndicator`: Applies `.glassEffect(.regular, in: .capsule)` to the capsule container hosting the progress spinner and pulsing opacity text (`0.4` to `1.0` over `0.8s`).
   - `QuickPromptSuggestions`: Wraps the horizontal row of suggestion chip buttons in `GlassEffectContainer(spacing: 8)`, with each chip styled using `.buttonStyle(.glass)` and `.buttonBorderShape(.capsule)` (accounting for the ~13pt native Liquid Glass internal padding per Rule #4).
   - `ChatInputBar`: Wraps the text field container (`.glassEffect(.regular, in: .rect(cornerRadius: 24))`) and the circular Send button (`.buttonStyle(.glassProminent).tint(SherlockTheme.victorianGold)` + `.buttonBorderShape(.circle)`) inside a `GlassEffectContainer(spacing: 10)`.
6. **`ZoomableImageDialog.swift` (Liquid Glass HUD Overlays)**:
   - Full-screen investigation overlay supporting `MagnifyGesture` (`1.0...5.0`), double-tap gesture (`1.0x` <-> `2.5x`), and bounded `DragGesture` when `scale > 1.0`.
   - Top HUD bar uses `.glassEffect(.regular, in: .rect(cornerRadius: 20))` and houses `"🔍 Scene Investigation"`, subtitle, and a `GlassEffectContainer(spacing: 8)` wrapping the conditional `"Reset Zoom"` button (`.buttonStyle(.glass)`, `.buttonBorderShape(.capsule)`, `accessibilityIdentifier("resetZoomButton")`) and `"Close"` button (`.buttonStyle(.glassProminent).tint(SherlockTheme.victorianGold)`, `.buttonBorderShape(.circle)`, `accessibilityIdentifier("closeZoomDialogButton")`).
   - Bottom HUD bar uses `.glassEffect(.regular, in: .capsule)` to display `"Zoom: X.Xx"` and the 2-line truncated caption.

---

## 4. Mermaid Topology Diagram

```mermaid
flowchart TD
    subgraph iOS_App["frontend/apple/no-spoilers-sherlock (iOS 26+ SwiftUI Liquid Glass Target)"]
        AppEntry["NoSpoilersSherlockApp.swift (@main)"]
        DI["AppDependencyContainer (#if canImport(FirebaseCore))"]
        ChatScreen["ChatScreen.swift (.safeAreaBar(edge: .bottom))"]
        TopBar["GlassEffectContainer: BookFilterChip (.glass) + AiStatusBadge (.glassEffect)"]
        Hero["EmptyChatHero.swift (Solid Victorian Cards in ScrollView)"]
        Bubble["ModernMessageBubble.swift (Solid Victorian Cards in ScrollView)"]
        Indicator["SherlockInvestigatingIndicator.swift (.glassEffect capsule)"]
        QuickPrompts["QuickPromptSuggestions.swift (.buttonStyle(.glass) chips)"]
        InputBar["ChatInputBar.swift (GlassEffectContainer + .glassProminent Send)"]
        BookSheet["BookSelectionSheet.swift"]
        ZoomDialog["ZoomableImageDialog.swift (Liquid Glass HUD Bars)"]
    end

    subgraph AppCore_Pkg["frontend/apple/Packages/AppCore (Swift 6 SPM, Zero Ext Deps)"]
        VM["ChatViewModel (@Observable @MainActor)"]
        Guard["SpoilerGuardManager (Regex > 0 + Clamping + Guardrail Prompts)"]
        Models["BookModels (Book, Chapter, Chunk, ChatMessage)"]
        RepoProto["BookRepositoryProtocol (Sendable)"]
        AiProto["AiServiceProtocol (Sendable)"]
        SeedRepo["InMemorySeededBookRepository (Actor: Scarlet + Sign of Four)"]
        FallbackAI["DeterministicSherlockAiService (Spoiler-Safe + Pre-Encoded PNG Data)"]
    end

    AppEntry --> DI
    DI --> VM
    AppEntry --> ChatScreen
    ChatScreen --> TopBar
    ChatScreen --> Hero
    ChatScreen --> Bubble
    ChatScreen --> Indicator
    ChatScreen --> QuickPrompts
    ChatScreen --> InputBar
    ChatScreen --> BookSheet
    ChatScreen --> ZoomDialog

    ChatScreen -->|Observes & Invokes| VM
    VM -->|Extracts Chapter & Builds Prompts| Guard
    VM -->|Queries Chunks <= targetChapter| RepoProto
    VM -->|Requests Answer / Scene Image| AiProto
    RepoProto <|.. SeedRepo
    AiProto <|.. FallbackAI
    VM --> Models
```

---

## 5. Trade-offs & Risks

| Trade-off / Risk | Impact | Mitigation Strategy |
| :--- | :--- | :--- |
| **iOS 26+ Liquid Glass Inside ScrollViews (`apple-flo-liquid-glass` Rule #7)** | Applying `.glassEffect` inside `ScrollView` causes GPU overdraw and violates platform guidelines. | Strictly restrict `.glassEffect` and `.buttonStyle(.glass)` to fixed bars (`.safeAreaBar(edge: .bottom)`, top bar, and `ZoomableImageDialog` HUDs), while `ModernMessageBubble` and `EmptyChatHero` inside `ScrollView` use solid Victorian Detective theme colors. |
| **Storing `imageData: Data?` in `ChatMessage` instead of `UIImage`** | Requires decoding `Data` to `UIImage`/`NSImage` in `ModernMessageBubble` and `ZoomableImageDialog`. | Images are compact period illustrations and session history is bounded; keeps `AppCore` 100% free of `UIKit` so `swift test` runs natively on macOS. |
| **Out-of-Bounds or Negative Chapter Queries** | User prompts like `"In chapter 99..."` or `"In chapter -2..."` could confuse prompt construction. | `SpoilerGuardManager.extractChapterFromPrompt` rejects negative/zero values (falling back to `defaultChapter = 3`), and `clampChapter` bounds the chapter to `1...selectedBook.totalChapters`. |
| **Missing `GoogleService-Info.plist` or Empty Xcode Scheme `<Testables>`** | Calling `FirebaseApp.configure()` unconditionally traps at launch; empty `<Testables>` fails `flowdeck test`. | `AppDependencyContainer` guards Firebase with `#if canImport(FirebaseCore)` and plist checks; `no-spoilers-sherlock.xcscheme` registers `AppCoreTests` in `<TestAction><Testables>`. |

---

## 6. Alternatives Considered

- **Alternative 1: Custom Blur/Material/Shadow Approximation Instead of Native iOS 26+ Liquid Glass**
  - *Pros*: Works on legacy iOS 17–18 targets.
  - *Why Rejected*: Explicitly prohibited by `apple-flo-liquid-glass` Rule #1 (*"Don't build custom Liquid Glass through adding backgrounds, outlines, blurs and shadows"*). Targeting iOS 26.0+ allows native `.buttonStyle(.glass)`, `.glassEffect(.regular, in: ...)`, `GlassEffectContainer`, and `.safeAreaBar(edge: .bottom)`.
- **Alternative 2: Monolithic Xcode Target (No `AppCore` Package)**
  - *Pros*: Simpler file tree without public access control modifiers.
  - *Why Rejected*: Violates repository spatial hierarchy (`AGENTS.md`) and `G-5`. Placing domain logic and `ChatViewModel` in `AppCore` enables fast (< 2s) `swift test --package-path frontend/apple/Packages/AppCore` execution without booting an iOS Simulator.
- **Alternative 3: Direct `firebase-ios-sdk` Dependency Inside `AppCore/Package.swift`**
  - *Pros*: Allows `FirestoreRepository` to live directly inside `AppCore`.
  - *Why Rejected*: Adds massive C++/gRPC build overhead to `swift test --package-path frontend/apple/Packages/AppCore` and risks network fetch failures in offline sandboxes. Keeping `AppCore` zero-dependency (`Foundation` + `Observation`) guarantees instant, reliable compilation.

---

## 7. Consequences

- **Positive**:
  - `AppCore` has zero external dependencies and compiles in under 2 seconds via `swift test` with 100% deterministic unit test coverage across `AC-1` through `AC-9`.
  - The iOS app displays its proper title (`"No Spoilers, Sherlock"`), compiles with valid Swift 6 `@main struct NoSpoilersSherlockApp: App`, and adopts authentic iOS 26+ Liquid Glass controls and `.safeAreaBar(edge: .bottom)` ergonomics.
  - `flowdeck test -w frontend/apple/no-spoilers-sherlock.xcodeproj -s no-spoilers-sherlock` executes `AppCoreTests` cleanly via the updated scheme (`AC-13`).
- **Negative / Trade-offs**:
  - Requires Xcode 26 / iOS 26.0+ SDK (`IPHONEOS_DEPLOYMENT_TARGET = 26.0`, `MACOSX_DEPLOYMENT_TARGET = 26.0` in `project.pbxproj` and `AppCore/Package.swift`).
  - Liquid Glass buttons add ~13pt of intrinsic padding (`apple-flo-liquid-glass` Rule #4), so custom label padding on `.buttonStyle(.glass)` and `.buttonStyle(.glassProminent)` must be kept minimal to avoid oversized pills.
