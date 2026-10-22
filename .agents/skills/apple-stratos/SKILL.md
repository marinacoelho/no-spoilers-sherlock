---
name: Stratos Core & SwiftUI Architecture
description: Clean modular architecture, FactoryKit DI patterns, and idiomatic SwiftUI state modeling.
---

# Stratos Core & SwiftUI Architecture

Stratos provides architectural foundations and patterns for building scalable, testable, and modular Swift and SwiftUI applications.

## Key Principles

1. **Native State Modeling**: Leverage `@Observable` macro for lightweight view state without legacy Combine boilerplate.
2. **Factory Dependency Injection**: Strict adherence to FactoryKit container registrations with `@ObservationIgnored @Injected` properties.
3. **Modular Local SPM Packages**: Structure features into separate SPM packages under `apps/apple/Packages/` to keep build times fast and prevent circular dependencies.
4. **Mocked `#Preview` Standards**: Every view must construct instant previews with mock data registered into Factory's preview container.
