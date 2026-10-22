---
name: Modern SwiftUI Standards
description: Modern declarative SwiftUI patterns, @Observable macro, and view composition standards
---

# Modern SwiftUI Standards

- Use the `@Observable` macro for view models; avoid legacy `ObservableObject` and `@Published`.
- Use `#Preview` macros with lightweight mock states.
- Avoid heavyweight computation or allocations in view body evaluation.
- Keep view hierarchies modular with localized subviews.
