---
id: firebase-ai-logic
name: Firebase AI Logic & Gemini Integration
author: Firebase / Google
platform: universal
repository: firebase/skills
path: skills/firebase-ai-logic-basics
default: true
description: Multimodal AI inference, structured JSON output, streaming responses, and Gemini model integration via Firebase AI Logic SDKs.
---

# Firebase AI Logic & Gemini Integration

Standards for integrating Google Gemini AI models directly into client and web applications using Firebase AI Logic (formerly Vertex AI for Firebase).

## Key Principles

1. **Direct Client Inference**: Call Gemini models directly from client applications without provisioning custom backend proxy servers using the official Firebase AI Logic SDKs.
2. **Provider Selection**: Use the Gemini Developer API provider for lightweight prototyping, and switch to Agent Platform Gemini API for enterprise production scale and SLAs.
3. **Structured Outputs**: Enforce deterministic JSON output schemas using response schema declarations (`responseSchema`) for robust parsing.
4. **Streaming Completions**: Deliver real-time, low-latency UI updates using streaming generation (`generateContentStream`) rather than blocking on full model completions.
5. **Safety & App Check**: Protect AI endpoints against unauthorized scraping and abuse by enforcing Firebase App Check with DeviceCheck / Play Integrity.
