---
name: Android Jetpack Compose Standards
description: Modern Android Jetpack Compose declarative UI, state hoisting, and lifecycle guidelines
---

# Android Jetpack Compose Standards

- Use Material 3 design tokens and theme color systems.
- Hoist state to callers; composables should be stateless whenever possible.
- Ensure all models passed into `@Composable` functions are `@Immutable` or `@Stable`.
- Use `collectAsStateWithLifecycle()` when collecting StateFlow in Compose views.
