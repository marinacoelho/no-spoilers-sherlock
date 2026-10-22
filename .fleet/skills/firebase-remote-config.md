---
id: firebase-remote-config
name: Firebase Remote Config & Feature Flags
author: Firebase / Google
platform: universal
repository: firebase/skills
path: skills/firebase-remote-config-basics
default: true
description: Remote Config templates, feature flags, loading strategies (fetchAndActivate), in-app defaults, and real-time listeners.
---

# Firebase Remote Config & Feature Flags

Best practices for dynamic app configuration, feature gating, and staged rollouts using Firebase Remote Config.

## Key Principles

1. **In-App Defaults First**: Always bundle bundled in-app defaults (XML/plist/JSON) before invoking remote fetch calls so the application functions instantly without network delays.
2. **Loading Strategy**: Call `fetchAndActivate()` upon application startup or resume. For sensitive UI flows, activate on the next application launch to prevent jarring visual changes while a user is interacting.
3. **Real-Time Config Updates**: Use real-time listeners (`addOnConfigUpdateListener`) on supported platforms to react instantly to server-side parameter mutations.
4. **Type-Safe Accessors**: Wrap raw Remote Config accessors in strongly typed feature flag classes or enum abstractions rather than querying arbitrary string keys throughout UI views.
5. **Template Versioning**: Track remote template versions and rollbacks via the Firebase CLI or REST API.
