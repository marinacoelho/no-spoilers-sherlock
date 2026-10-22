---
id: firebase-crashlytics
name: Firebase Crashlytics & Real-Time Monitoring
author: Firebase / Google
platform: universal
repository: firebase/skills
path: skills/firebase-crashlytics
default: true
description: Crashlytics provisioning, native SDK configuration, custom log enrichment, and non-fatal issue tracking.
---

# Firebase Crashlytics & Real-Time Monitoring

Guidance for integrating and managing Firebase Crashlytics crash reporting across iOS, Android, and web.

## Key Principles

1. **Symbolication & dSYMs**: Configure build phase scripts or Gradle plugins to automatically upload dSYMs and ProGuard/R8 mapping files on every release build.
2. **Context Enrichment**: Enrich crash reports with actionable metadata: custom keys (`setCustomValue`), breadcrumb logs (`log`), and authenticated user identifiers (`setUserID`).
3. **Non-Fatal Issue Logging**: Explicitly capture and log handled exceptions in catch blocks without crashing the host process (`record(error:)` / `recordException()`).
4. **Data Privacy**: Strictly sanitize user data prior to logging; never record PII (passwords, credit cards, bearer tokens) into Crashlytics keys or logs.
