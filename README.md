# 🔍 No Spoilers, Sherlock

**No Spoilers, Sherlock** is a multi-platform AI reading companion for mystery novels and multi-book universes (starting with Sir Arthur Conan Doyle's *Sherlock Holmes* canon). It lets readers ask questions about characters, plot clues, and settings—and generate 1880s Victorian pen-and-ink scene illustrations—while **guaranteeing 100% spoiler prevention** beyond the chapter they are currently reading.

---

## ✨ Key Features

- **Two-Layer Spoiler Guardrail**:
  1. **Database-Level Filtering**: Queries Cloud Firestore (or the offline seeded casebook) strictly for chunks where `chapterOrder <= targetChapterOrder`.
  2. **Prompt-Level Guardrail**: Wraps retrieved excerpts in a strict negative constraint (`STRICT SPOILER GUARDBOUND`) so the model never reveals future plot twists, culprit identities, or character deaths.
- **Automatic Chapter Detection & Boundary Control**: Extracts the reader's current chapter directly from natural language prompts (e.g., *"In Chapter 3, who died?"*), or uses the interactive chapter boundary selector.
- **Victorian Scene Visualization (Nano Banana AI)**: Generates period-accurate 1880s Victorian pen-and-ink illustrations in the style of Sidney Paget's *Strand Magazine* engravings using `gemini-3.1-flash-image` / `gemini-2.5-flash-image`, with a full-screen pinch-to-zoom inspector.
- **Cross-Platform Monorepo**:
  - **iOS 26+ (`frontend/apple/`)**: Native SwiftUI application adopting **iOS 26+ Liquid Glass** (`GlassEffectContainer`, `.glassEffect()`, `.buttonStyle(.glass)`, `.safeAreaBar(edge: .bottom)`), Apple HIG semantic colors, Swift 6 strict concurrency, and a zero-dependency `AppCore` Swift Package.
  - **Android (`frontend/android/`)**: Native Jetpack Compose & Material 3 application powered by Firebase AI Logic and Cloud Firestore offline persistence.

---

## 🗂️ Repository Structure

```text
├── frontend/
│   ├── apple/
│   │   ├── no-spoilers-sherlock/           # Native iOS 26+ SwiftUI Liquid Glass App
│   │   ├── no-spoilers-sherlock.xcodeproj  # Xcode Project
│   │   └── Packages/AppCore/               # Shared Swift 6 Domain, SpoilerGuardManager & ViewModel
│   ├── android/                            # Native Android (Jetpack Compose + Material 3) App
│   └── web/                                # Web Surface Scaffold
├── backend/
│   └── cli/                                # TypeScript CLI & MCP Server
├── firebase/                               # Firestore Security Rules & Composite Indexes
└── docs/
    ├── specs/                              # Product Requirement Documents (PRDs)
    ├── architecture/                       # Architecture Decision Records (ADRs)
    ├── learnings/                          # Engineering Learnings
    └── journal/                            # Session Engineering Journals
```

---

## 🚀 Getting Started

### iOS (`frontend/apple`)
1. *(Optional for Live Cloud AI / Firestore)* Place your `GoogleService-Info.plist` in `frontend/apple/no-spoilers-sherlock/`. Without it, the app automatically runs using the seeded offline casebook (`InMemorySeededBookRepository`) and deterministic spoiler-safe AI fallback (`DeterministicSherlockAiService`).
2. Run the `AppCore` Swift Testing suite:
   ```bash
   swift test --package-path frontend/apple/Packages/AppCore
   ```
3. Open `frontend/apple/no-spoilers-sherlock.xcodeproj` in Xcode 26+ (or run via FlowDeck) targeting an iOS 26+ Simulator.

### Android (`frontend/android`)
1. Place your `google-services.json` in `frontend/android/app/`.
2. Run unit tests or launch from Android Studio:
   ```bash
   (cd frontend/android && ./gradlew test)
   ```
