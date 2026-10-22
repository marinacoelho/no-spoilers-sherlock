---
id: swift-6-concurrency
name: Swift 6 Concurrency Standards
author: Peter Friese
repository: peterfriese/Stratos
path: skills/swift-concurrency-pro
description: Strict Swift 6 concurrency, Sendable verification, structured concurrency, and isolation
---

# Swift 6 Concurrency Standards

- Compile with Swift 6 mode / strict concurrency enabled.
- All types passed across task or actor boundaries must be verified `Sendable`.
- Prefer value types (structs, enums) for state sharing.
- Use structured concurrency (`async let`, `withTaskGroup`) rather than uncoordinated `Task {}` blocks whenever possible.
- Avoid unchecked Sendable (`@unchecked Sendable`) unless protecting thread safety with an OSAllocatedUnfairLock or Mutex.
