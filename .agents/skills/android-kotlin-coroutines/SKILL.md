---
name: Kotlin Coroutines & Flow Lifecycle Architecture
description: Structured concurrency, StateFlow vs SharedFlow, lifecycle scopes (repeatOnLifecycle, viewModelScope).
---

# Kotlin Coroutines & Flow Lifecycle Architecture

Authoritative patterns for asynchronous Kotlin development and lifecycle-aware reactive streams in Android.

## Key Principles

1. **Structured Concurrency**: Never use `GlobalScope`. Always launch coroutines from structured scopes (`viewModelScope`, `lifecycleScope`) so cancellation propagates reliably.
2. **StateFlow vs SharedFlow**:
   - Use `StateFlow` with an initial value for continuous UI state modeling.
   - Use `SharedFlow` with `extraBufferCapacity` or channels for transient, one-off UI events (e.g., snackbars, navigation).
3. **Lifecycle-Aware Collection**: In Jetpack Compose, collect flows with `collectAsStateWithLifecycle()` to automatically halt emissions when the app is backgrounded. In Fragments/Views, use `viewLifecycleOwner.lifecycleScope.launch { viewLifecycleOwner.repeatOnLifecycle(Lifecycle.State.STARTED) { ... } }`.
4. **Dispatcher Discipline**: Confine UI mutations to `Dispatchers.Main.immediate`. Offload heavy compute to `Dispatchers.Default` and disk/network I/O to `Dispatchers.IO`.
5. **Cooperative Cancellation**: Ensure long-running loops periodically invoke `ensureActive()` or `yield()` to honor coroutine cancellation requests.
