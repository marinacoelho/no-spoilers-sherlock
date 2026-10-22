---
id: firebase-basics
name: Firebase CLI & Project Foundations
author: Firebase / Google
platform: universal
repository: firebase/skills
path: skills/firebase-basics
default: true
description: Foundational Firebase CLI setup, version checks, CLI login, project creation/selection (firebase use), and config downloads.
---

# Firebase CLI & Project Foundations

Provides foundational Firebase CLI setup, project creation, environment configuration, and credential management.

## Key Principles

1. **CLI Verification**: Ensure Firebase CLI is accessible via `firebase --version` or fallback `npx -y firebase-tools@latest --version`.
2. **Authentication**: Authenticate using `firebase login` (or `firebase login --no-localhost` in headless CI/CD environments).
3. **Active Project Selection**: Confirm the active project context via `firebase use` or `firebase use <project-id>`.
4. **Configuration Artifacts**: Fetch necessary configuration files (`google-services.json` for Android, `GoogleService-Info.plist` for Apple platforms) directly through the CLI or console.
5. **Scoped Usage**: Use this skill solely for project configuration and environment bootstrapping; delegate specific database, auth, or hosting workflows to their respective domain skills.
