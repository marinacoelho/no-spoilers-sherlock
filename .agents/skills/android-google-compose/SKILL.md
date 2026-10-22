---
name: Google Android — Jetpack Compose Idioms & Stability
description: Official Google guidance for Jetpack Compose, Material 3 design, state hoisting, and recomposition hygiene.
---

# Google Android — Jetpack Compose Skill

Official best practices from the Android team for building fluid, modern Android user interfaces.

## Key Guidance

- **State Hoisting**: Keep Composables stateless by passing state down and events up (`(value: T, onValueChange: (T) -> Unit)`).
- **Stability**: Mark external data models with `@Immutable` or `@Stable` to prevent redundant recomposition.
- **Recomposition Hygiene**: Use `remember` with explicit keys and `derivedStateOf` for calculated values.
