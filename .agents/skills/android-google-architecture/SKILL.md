---
name: Google Android — Modern Android Architecture & Coroutines
description: Architecture Components, ViewModel, StateFlow, Coroutines, Repository pattern, and Dependency Injection.
---

# Google Android — Modern Architecture & Coroutines

Guidelines for structuring robust, scalable Android applications using Kotlin Coroutines, StateFlow, and Clean Architecture.

## Key Guidance

- **Unidirectional Data Flow (UDF)**: Expose UI state via `StateFlow` and handle user events through ViewModel functions.
- **Structured Concurrency**: Launch coroutines in `viewModelScope` and collect state in Compose using `collectAsStateWithLifecycle()`.
- **Zero Main Thread Blocking**: Always dispatch I/O work (network, Room database) to `Dispatchers.IO`.
