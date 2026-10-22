# 📚 Engineering Learnings Index

Welcome to the **No Spoilers, Sherlock** architectural learnings catalog. Each article documents high-signal debugging breakthroughs, concurrency patterns, adversarial hardening techniques, and platform UI best practices discovered while building the project.

---

## 2026

| Date | Article | Summary | Tags |
| :--- | :--- | :--- | :--- |
| **2026-10-21** | [Adversarial Hardening of Spoiler Guardrails, `@MainActor` Session Generation Counters, and iOS 26 Liquid Glass Hygiene](./2026-10-21-spoiler-guardrail-and-liquid-glass-ios26.md) | How to eliminate natural-language spoiler boundary escalations (`"chapter 0"`, 64-bit overflows, multi-chapter prompts, and figurative idioms), prevent mid-flight `await` state bleeding across book switches with a monotonic `sessionGeneration` counter, and structure iOS 26 SwiftUI Liquid Glass (`GlassEffectContainer`, `.safeAreaBar`) for 120Hz scroll performance. | `swift-6`, `swiftui`, `ios-26`, `liquid-glass`, `concurrency`, `rag-guardrails`, `adversarial-testing` |
