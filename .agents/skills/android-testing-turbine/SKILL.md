---
name: Turbine Flow Testing & Compose Rules
description: Flow testing with Cash App's Turbine, Compose test rules (createComposeRule).
---

# Turbine Flow Testing & Compose Rules

Standards for testing asynchronous reactive flows and Jetpack Compose user interfaces.

## Key Principles

1. **Turbine Flow Testing**: Use Cash App's `test` extension on any `Flow` inside `runTest`:
   ```kotlin
   viewModel.uiState.test {
       assertEquals(UiState.Loading, awaitItem())
       assertEquals(UiState.Success(data), awaitItem())
       cancelAndIgnoreRemainingEvents()
   }
   ```
2. **Strict Event Accounting**: Verify all emitted items, completion signals, or exceptions explicitly. Do not leave unconsumed events unverified.
3. **Compose UI Testing**: Use `createComposeRule()` for headless UI component tests and `createAndroidComposeRule<MainActivity>()` for activity-integrated testing.
4. **Semantic Locators**: Query composables using accessibility semantics (`onNodeWithText`, `onNodeWithContentDescription`, `hasTestTag`) rather than internal implementation details.
5. **Virtual Time & Schedulers**: Rely on Kotlinx Coroutines `TestScope` and `advanceUntilIdle()` to control asynchronous virtual time deterministically.
