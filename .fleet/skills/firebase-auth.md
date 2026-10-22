---
id: firebase-auth
name: Firebase Authentication & Identity
author: Firebase / Google
platform: universal
repository: firebase/skills
path: skills/firebase-auth-basics
default: true
description: Setup and integration of Firebase Authentication, OAuth providers, passkeys, user session state, and security rules tokens.
---

# Firebase Authentication & Identity

Guidelines for implementing authentication, multi-factor verification, and identity state management across client and server environments.

## Key Principles

1. **Provider Configuration**: Enable and manage identity providers (Email/Password, Google, Apple, GitHub, Anonymous) in the Firebase console or CLI.
2. **Session & Token Management**: Listen to auth state changes using reactive listeners (`onAuthStateChanged` / `authStateStream`). Always rely on short-lived ID tokens and automated refresh loops.
3. **Security Rules Synchronization**: Rely on `request.auth.uid` and custom claims (`request.auth.token`) in Security Rules to authorize read/write operations.
4. **Credential Linking**: Support progressive authentication by converting anonymous sessions into authenticated permanent accounts via credential linking.
