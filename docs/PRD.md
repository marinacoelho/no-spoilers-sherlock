# Product Requirement Document (PRD) & Technical Architecture
## "No Spoilers, Sherlock" Android Application

### Executive Summary
*No Spoilers, Sherlock* is an Android application designed for book lovers reading single novels or multi-book fictional universes (such as Sir Arthur Conan Doyle's *Sherlock Holmes* canon). The app provides an AI-powered Q&A interface that lets users ask questions about characters, plot details, clues, and lore while **guaranteeing 100% spoiler prevention** beyond the chapter specified in their prompt.

---

### Key Requirements & Feature Specifications

#### 1. Chapter Identification & Context Scoping (No Progress Tracking DB)
- **Prompt-Based Chapter Detection**: The app does not track persistent reading progress in a database. Instead, it extracts the target chapter directly from the user's query/prompt (e.g. *"In Chapter 5, why did Holmes..."* or explicit prompt context).
- **Multi-Book & Chapter Boundary**: Content accessible to the AI query is strictly bounded to Chapters $1 \dots C_{prompt}$ of Book $N$ (and all chapters of preceding Books $1 \dots N-1$). Anything after $C_{prompt}$ is strictly excluded.

#### 2. Spoiler Guard & Context Filtering
- **Metadata Tagging**: Pre-computed book text chunks in Cloud Firestore are tagged with `universe_id`, `book_order`, `chapter_order`, and `chunk_index`.
- **Filtered Context Queries**: Queries filter Firestore collections strictly by the chapter extracted from the user's prompt (`book_order < target_book` OR `(book_order = target_book AND chapter_order <= target_chapter)`).
- **Guardrail System Prompting**: Instructs the LLM to strictly decline answering questions or predicting outcomes that rely on future unread chapters beyond $C_{prompt}$.

#### 3. Database Architecture: Cloud Firestore with Native Offline Persistence
- **No SQL Database**: The app uses **Cloud Firestore exclusively** as its database. No Room or SQLite database is used.
- **Pre-computed RAG Data in Firestore**: Chapter texts, chunk metadata, and pre-computed vector embeddings are stored directly in Cloud Firestore collections.
- **SDK Native Offline Persistence**: The app enables Cloud Firestore's native offline persistent cache (`persistentCache` / `enablePersistence()`). When offline, the Firestore SDK transparently reads pre-computed chapter data directly from its local persistent cache on device.

#### 4. AI Engine: Firebase AI Logic (`PREFER_ON_DEVICE` + Gemini Developer API Cloud Fallback)
- **SDK**: Built with **Firebase AI Logic SDK** configured in **`PREFER_ON_DEVICE`** inference mode.
- **On-Device Execution**: Runs inference locally using Gemini Nano when offline or available.
- **Cloud Fallback**: Uses the **Gemini Developer API** provider via Firebase AI Logic (defaulting to `gemini-flash-latest`) when online or falling back to cloud inference.

---

### Tech Stack Summary
- **Language & Framework**: Kotlin, Jetpack Compose, Material 3, Coroutines, Flow, Hilt Dependency Injection.
- **Database**: Cloud Firestore (with SDK Persistent Offline Cache enabled — no SQL/Room database).
- **AI / ML**: Firebase AI Logic SDK (`PREFER_ON_DEVICE` inference mode with Gemini Nano local execution / **Gemini Developer API** for cloud fallback).
