---
id: apple-twostraws-testing
name: TwoStraws Swift Testing Agent Skill
author: Paul Hudson
platform: apple
repository: twostraws/Swift-Testing-Agent-Skill
path: swift-testing-pro
default: true
description: Modern Swift Testing framework macros (@Test, #expect, #require, parameterized tests).
---

# TwoStraws Swift Testing Agent Skill

Expert patterns for writing tests using Apple's modern Swift Testing framework (`import Testing`).

## Key Guidance

- Use `@Test` macro instead of legacy `XCTestCase` methods.
- Use `#expect(...)` for non-halting assertions and `#require(...)` when unwrap failures should abort the test.
- Use parameterized testing `@Test(arguments: [...])` for table-driven testing.
