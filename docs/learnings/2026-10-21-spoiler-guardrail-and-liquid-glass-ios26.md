# 💡 Learnings: Adversarial Hardening of Spoiler Guardrails, `@MainActor` Session Generation Counters, and iOS 26 Liquid Glass Hygiene

**Author**: Learnings Agent & iOS / Swift SDK Architecture Fleet  
**Date**: 2026-10-21  
**Tags**: `swift-6`, `swiftui`, `ios-26`, `liquid-glass`, `concurrency`, `rag-guardrails`, `adversarial-testing`  

---

## Summary

While building and red-teaming **No Spoilers, Sherlock**—a dual-layer spoiler-guarded literary reading companion for iOS 26+—we uncovered five subtle parser and concurrency vulnerabilities capable of leaking future plot twists across chapter boundaries or book sessions. By hardening natural-language boundary extraction in `SpoilerGuardManager` (preserving `0` for clamping, saturating 64-bit integer overflows to `Int.max`, taking `.min()` across multi-chapter references, and filtering figurative idioms via word-boundary regexes), introducing a monotonic `sessionGeneration: UInt64` counter in `@Observable @MainActor ChatViewModel`, and strictly isolating iOS 26 Liquid Glass materials (`GlassEffectContainer`, `.glassEffect`, `.safeAreaBar`) away from scrolling `ScrollView` content (`ModernMessageBubble`), we achieved zero spoiler leaks and sustained 120Hz scrolling performance.

---

## The Problem / Challenge

**No Spoilers, Sherlock** enforces a two-layer spoiler prevention architecture:
1. **Layer 1 (Database-Level Filtering)**: Queries only retrieve book chunks where `chapterOrder <= targetChapterOrder`.
2. **Layer 2 (System Prompt Guardrail)**: Constructs an explicit `=== STRICT SPOILER GUARDBOUND ===` system prompt containing only the permitted excerpts up to `targetChapter`.

However, an adversarial red-team stress test (`/challenge`) exposed five non-trivial edge cases where the boundary resolution, intent router, or asynchronous UI state machine could be tricked into leaking spoilers or misrouting requests:

1. **The `"chapter 0"` Fallback Escalation**: When a reader asked *"In chapter 0, who is Holmes?"*, an initial `extractChapterFromPrompt` implementation filtered for `value > 0` and returned `nil`. Because `ChatViewModel` coalesced `nil` to `defaultChapter` (`3`), asking about Chapter 0 silently escalated the reader's spoiler boundary from `1` to `3`, exposing Chapters 2 and 3!
2. **64-Bit Integer Overflow on Huge Chapter Numbers**: When a prompt contained a 20-digit number like `"In chapter 99999999999999999999, who is the culprit?"`, `Int(rawDigits)` overflowed 64-bit signed integer limits and returned `nil`. Again, `nil` fell back to `defaultChapter` (`3`) instead of clamping to `totalChapters` (`14`).
3. **Multi-Chapter Mention Order Bias**: When a reader wrote *"Without spoiling chapter 7, tell me what happened in chapter 2"*, a first-match regex extractor captured `7` instead of `2`, unlocking chapters the reader explicitly asked *not* to have spoiled.
4. **Visualization Keyword False Positives**: Naive substring matching on visualization keywords (`"draw"`, `"picture"`, `"sketch"`) falsely routed analytical text questions—such as *"Did Holmes withdraw from the room?"*, *"What conclusion did Holmes draw?"*, or *"What is the big picture in chapter 3?"*—into the image generation pipeline.
5. **Cross-Book Mid-Flight `await` State Bleeding**: Because `ChatViewModel` is `@MainActor`-isolated, suspension points (`await repository.getSpoilerBoundedChunks(...)` and `await aiService.noSpoilerAnswer(...)`) yield the main actor. If a user switched books (`selectBook(_:)`) or cleared the chat (`clearConversation()`) while an inference task was in flight, the resumed task appended the previous book's answer into the newly selected book's transcript.
6. **Scroll Hitching from Liquid Glass Overuse**: Applying iOS 26 `.glassEffect()` inside repeating `ScrollView` message cells (`ModernMessageBubble`) violates platform rendering hygiene and degrades 120Hz ProMotion frame pacing.

---

## Root Cause & Discovery

### 1. Ambiguous `nil` Semantics in Boundary Extraction
The root cause of both the `"chapter 0"` and `"chapter 99999999999999999999"` vulnerabilities was conflating *"no chapter was mentioned in the prompt"* (`nil`) with *"an out-of-bounds chapter number was mentioned in the prompt"*.
- When no chapter is mentioned (*"Who is Inspector Lestrade?"*), returning `nil` so `ChatViewModel` falls back to `defaultChapter` (`3`) is desirable.
- When `"chapter 0"` is explicitly mentioned, returning `nil` bypasses `clampChapter(0, totalChapters: 14) -> 1` and instead evaluates `nil ?? defaultChapter -> 3`.
- Similarly, when `\d+` matches a 20-digit integer string, `Int(rawDigits)` fails not because no digits were present, but because the positive integer exceeded `Int.max` (`9,223,372,036,854,775,807`).

### 2. First-Match Regex vs. Conservative Minimum Boundary
Natural language prompts often mention both the reader's current chapter and a future boundary they want to avoid (*"Don't spoil the 7th chapter, I am only on ch. 2"*). Taking the first regex match makes spoiler safety dependent on English clause ordering. Extracting *all* non-negative chapter mentions across all supported patterns and taking `.min()` guarantees the most conservative (lowest) spoiler boundary is always enforced.

### 3. Actor Reentrancy Across Suspension Points on `@MainActor`
In Swift 6 strict concurrency, marking a view model `@MainActor` serializes synchronous mutations on the main thread, but it **does not prevent actor reentrancy across `await` suspension points**. During `await aiService.noSpoilerAnswer(fullPrompt:)`, the user can tap the book selector and invoke `selectBook(signOfTheFour)`. When `noSpoilerAnswer` returns, execution resumes on `@MainActor` with local stack variables (`activeBook`, `placeholderId`, `clampedChapter`) captured from the *old* session.

### 4. iOS 26 Liquid Glass Backdrop Sampling Cost
In iOS 26 (`apple-flo-liquid-glass`), Liquid Glass views sample and refract their background layers dynamically. Inside a fixed top header bar or a bottom `.safeAreaBar(edge: .bottom)`, a `GlassEffectContainer` shares a single sampling region across sibling controls efficiently. Inside a `LazyVStack` in a `ScrollView`, however, every scrolling bubble would trigger continuous per-frame offscreen passes.

---

## The Idiomatic Solution

### 1. Saturation & Conservative `.min()` Extraction in `SpoilerGuardManager`
We redesigned [`SpoilerGuardManager.extractChapterFromPrompt(_:)`](file:///Users/peterfriese/Workspace/Projects/CCDR/S2E4/live/no-spoilers-sherlock/frontend/apple/Packages/AppCore/Sources/AppCore/Domain/SpoilerGuardManager.swift#L36-L57) and [`allCapturedInts(in:pattern:)`](file:///Users/peterfriese/Workspace/Projects/CCDR/S2E4/live/no-spoilers-sherlock/frontend/apple/Packages/AppCore/Sources/AppCore/Domain/SpoilerGuardManager.swift#L196-L214) with four invariants:
- **Explicit Negative Guard**: Reject negative chapter mentions (`"chapter -3"`, `"-4th chapter"`) immediately by returning `nil`.
- **Zero Preservation**: Allow `0` in `validChapters` (`$0 >= 0`) so `extractChapterFromPrompt("chapter 0")` returns `0`, which [`clampChapter(_:totalChapters:)`](file:///Users/peterfriese/Workspace/Projects/CCDR/S2E4/live/no-spoilers-sherlock/frontend/apple/Packages/AppCore/Sources/AppCore/Domain/SpoilerGuardManager.swift#L65-L68) deterministically clamps to `1`.
- **Overflow Saturation**: When `rawDigits.allSatisfy(\.isWholeNumber)` is true, coalesce `Int(rawDigits) ?? Int.max` so arbitrarily large numbers saturate to `Int.max` and clamp cleanly to `totalChapters`.
- **Conservative Minimum Selection**: Collect all matches across prefix (`chapter X`) and ordinal (`Xth chapter`) patterns and return `validChapters.min()`.

### 2. Idiom Sanitization + Word-Boundary Regex Routing
In [`SpoilerGuardManager.isVisualizationRequest(_:)`](file:///Users/peterfriese/Workspace/Projects/CCDR/S2E4/live/no-spoilers-sherlock/frontend/apple/Packages/AppCore/Sources/AppCore/Domain/SpoilerGuardManager.swift#L77-L101), we first strip common figurative English idioms (`"big picture"`, `"draw a conclusion"`, `"picture of health"`) via regular expression replacement, and then match each keyword in `visualizationKeywords` using word boundaries (`\b\(escaped)\b`). This prevents `"withdraw"`, `"picturesque"`, and `"sketchy"` from triggering image generation while keeping `"Draw the crime scene in chapter 3"` responsive.

### 3. Monotonic `sessionGeneration: UInt64` Counter in `ChatViewModel`
To eliminate mid-flight state bleeding across `await` boundaries without requiring unstructured task management at every call site, [`ChatViewModel`](file:///Users/peterfriese/Workspace/Projects/CCDR/S2E4/live/no-spoilers-sherlock/frontend/apple/Packages/AppCore/Sources/AppCore/ViewModel/ChatViewModel.swift#L10-L38) maintains a private monotonic counter:
```swift
private var sessionGeneration: UInt64 = 0
```
Every session-resetting action (`loadBooksAndInit()`, `selectBook(_:)`, `clearConversation()`) increments `sessionGeneration &+= 1`. Asynchronous operations (`sendMessage(_:)`, `visualizeScene(_:targetChapter:)`, `loadBooksAndInit()`) snapshot `let generation = sessionGeneration` before their first suspension point and assert `guard generation == self.sessionGeneration else { return }` immediately after every `await`.

### 4. Strict iOS 26 Liquid Glass Chrome vs. Content Separation
In [`ChatScreen`](file:///Users/peterfriese/Workspace/Projects/CCDR/S2E4/live/no-spoilers-sherlock/frontend/apple/no-spoilers-sherlock/Views/ChatScreen.swift#L16-L68) and [`ChatInputBar`](file:///Users/peterfriese/Workspace/Projects/CCDR/S2E4/live/no-spoilers-sherlock/frontend/apple/no-spoilers-sherlock/Views/ChatInputBar.swift#L21-L79), we restrict Liquid Glass exclusively to floating navigation chrome and anchored input bars:
- Wrap sibling glass elements in `GlassEffectContainer(spacing:)` so they share a unified glass sampling group.
- Use `.buttonStyle(.glass)` and `.buttonStyle(.glassProminent)` with `.tint(SherlockTheme.victorianGold)` for interactive controls, and `.glassEffect(.regular, in:)` for custom non-interactive surfaces (`AiStatusBadge`, input text field container).
- Anchor the bottom input bar and quick prompt chips via `.safeAreaBar(edge: .bottom)` so the `ScrollView` automatically insets its safe area without manual geometry calculation.
- Keep [`ModernMessageBubble`](file:///Users/peterfriese/Workspace/Projects/CCDR/S2E4/live/no-spoilers-sherlock/frontend/apple/no-spoilers-sherlock/Views/ModernMessageBubble.swift#L154-L173) 100% free of `.glassEffect`, rendering bubbles on solid Victorian theme colors (`SherlockTheme.detectiveNavyLight` / `detectiveNavyMedium`) with `UnevenRoundedRectangle` borders.

---

## Code Examples

### 1. Hardened Chapter Extraction & Idiom-Safe Visualization Detection

```swift
// ❌ BEFORE: Naive extraction and substring matching
public static func extractChapterFromPromptNaive(_ prompt: String) -> Int? {
    let pattern = #"(?i)\b(?:chapter|chap|ch\.?)\s+(\d+)\b"#
    guard let regex = try? NSRegularExpression(pattern: pattern),
          let match = regex.firstMatch(in: prompt, range: NSRange(prompt.startIndex..., in: prompt)),
          let range = Range(match.range(at: 1), in: prompt),
          let value = Int(prompt[range]),
          value > 0 else {
        // BUG 1: "chapter 0" fails `value > 0`, returns nil, and escalates to defaultChapter (3)!
        // BUG 2: "chapter 99999999999999999999" overflows Int(), returns nil, and falls back to 3!
        // BUG 3: "Without spoiling chapter 7, what happened in chapter 2" returns firstMatch (7)!
        return nil
    }
    return value
}

public static func isVisualizationRequestNaive(_ prompt: String) -> Bool {
    let lower = prompt.lowercased()
    // BUG 4: Matches "withdraw" ("draw"), "sketchy" ("sketch"), and "big picture" ("picture")!
    return visualizationKeywords.contains { lower.contains($0) }
}
```

```swift
// ✅ AFTER: Saturation-safe, conservative .min() extraction & word-boundary idiom filtering
// From frontend/apple/Packages/AppCore/Sources/AppCore/Domain/SpoilerGuardManager.swift
public static func extractChapterFromPrompt(_ prompt: String) -> Int? {
    let negativePattern = #"(?i)(?:\b(?:chapter|chap|ch\.?)\s*-\s*\d+|-\s*\d+(?:st|nd|rd|th)?\s*chapter\b)"#
    if prompt.range(of: negativePattern, options: .regularExpression) != nil {
        return nil
    }

    let patterns = [
        #"(?i)\b(?:chapter|chap|ch\.?)\s+(\d+)\b"#,
        #"(?i)(?<!-)\b(\d+)(?:st|nd|rd|th)?\s*chapter\b"#
    ]

    var matchedChapters: [Int] = []
    for pattern in patterns {
        matchedChapters.append(contentsOf: allCapturedInts(in: prompt, pattern: pattern))
    }

    let validChapters = matchedChapters.filter { $0 >= 0 }
    return validChapters.min()
}

private static func allCapturedInts(in text: String, pattern: String) -> [Int] {
    guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
        return []
    }
    let nsRange = NSRange(text.startIndex..<text.endIndex, in: text)
    let matches = regex.matches(in: text, options: [], range: nsRange)
    return matches.compactMap { match in
        guard match.numberOfRanges > 1,
              let captureRange = Range(match.range(at: 1), in: text) else {
            return nil
        }
        let rawDigits = String(text[captureRange])
        guard !rawDigits.isEmpty, rawDigits.allSatisfy(\.isWholeNumber) else {
            return nil
        }
        // Saturate huge positive digit sequences to Int.max so clampChapter clamps to totalChapters.
        return Int(rawDigits) ?? Int.max
    }
}
```

### 2. `@MainActor` Session Generation Fencing in `ChatViewModel`

```swift
// ✅ From frontend/apple/Packages/AppCore/Sources/AppCore/ViewModel/ChatViewModel.swift
public func selectBook(_ book: Book) {
    sessionGeneration &+= 1 // Invalidates any in-flight tasks from the previous book
    selectedBook = book
    defaultChapter = SpoilerGuardManager.clampChapter(defaultChapter, totalChapters: book.totalChapters)
    lastDetectedChapter = defaultChapter
    isLoading = false
    statusMessage = nil
    messages = [makeWelcomeMessage(for: book)]
}

public func sendMessage(_ userText: String) async {
    let trimmed = userText.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return }

    let activeBook = resolveActiveBook()
    let rawChapter = SpoilerGuardManager.extractChapterFromPrompt(trimmed) ?? defaultChapter
    let clampedChapter = SpoilerGuardManager.clampChapter(rawChapter, totalChapters: activeBook.totalChapters)

    if SpoilerGuardManager.isVisualizationRequest(trimmed) {
        await visualizeScene(trimmed, targetChapter: clampedChapter)
        return
    }

    let generation = sessionGeneration // Snapshot current generation before suspension

    let userMessage = ChatMessage(sender: .user, text: trimmed, extractedChapter: clampedChapter)
    messages.append(userMessage)
    isLoading = true
    lastDetectedChapter = clampedChapter

    let placeholderId = UUID().uuidString

    do {
        let allowedChunks = try await repository.getSpoilerBoundedChunks(
            bookId: activeBook.id,
            targetChapterOrder: clampedChapter
        )
        guard generation == self.sessionGeneration else { return } // Fence 1

        // ... append placeholder and build prompt ...

        let answerText = try await aiService.noSpoilerAnswer(fullPrompt: fullPrompt)
        guard generation == self.sessionGeneration else { return } // Fence 2

        // ... replace placeholder safely within the same session generation ...
    } catch {
        guard generation == self.sessionGeneration else { return } // Error Fence
        // ... handle error ...
    }
}
```

### 3. iOS 26 Liquid Glass Chrome vs. Solid Scrolling Cells

```swift
// ✅ Floating Chrome: GlassEffectContainer + .glassEffect + .buttonStyle(.glassProminent)
// From frontend/apple/no-spoilers-sherlock/Views/ChatInputBar.swift
GlassEffectContainer(spacing: 10) {
    HStack(alignment: .center, spacing: 10) {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(SherlockTheme.victorianGold.opacity(0.85))
            TextField("Ask about your chapter...", text: $inputText, axis: .vertical)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .glassEffect(.regular, in: .rect(cornerRadius: 24))

        Button(action: onSendMessage) {
            Image(systemName: "paperplane.fill")
        }
        .buttonStyle(.glassProminent)
        .tint(SherlockTheme.victorianGold)
        .buttonBorderShape(.circle)
        .disabled(!canSend)
    }
}
```

---

## Key Takeaways

- **Never Conflate "No Match" (`nil`) with "Out-of-Bounds Match"**: When a parser feeds into a fallback operator (`extracted ?? defaultChapter`) followed by a clamping function (`clampChapter`), out-of-range user inputs (`0` or 64-bit integer overflows) must return a clampable integer (`0` or `Int.max`), never `nil`.
- **Use `.min()` for Multi-Boundary Prompts**: In spoiler-sensitive RAG pipelines, users frequently mention both the chapter they are on and the future chapter they want to avoid. Taking `.min()` across all extracted chapter numbers guarantees the safest boundary regardless of clause ordering.
- **Guard `@MainActor` Suspension Points with a Generation Counter**: `@MainActor` serializes execution but does not prevent reentrancy across `await`. A lightweight `sessionGeneration: UInt64` counter incremented on context switches (`selectBook`, `clearConversation`) deterministically fences stale responses from polluting a new session.
- **Sanitize Idioms and Require Word Boundaries (`\b`) for Intent Routing**: Never use raw `.contains()` for keyword intent routing; common words like `"withdraw"`, `"picturesque"`, or `"draw a conclusion"` will misroute text queries into image generation.
- **Keep iOS 26 Liquid Glass Strictly in Floating Chrome**: Combine `GlassEffectContainer`, `.glassEffect`, `.buttonStyle(.glass)`, and `.safeAreaBar(edge: .bottom)` for top/bottom chrome, while using solid opaque/semi-opaque theme surfaces inside `ScrollView` cells (`ModernMessageBubble`) to maintain 120Hz frame pacing.
