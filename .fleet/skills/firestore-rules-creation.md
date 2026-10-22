---
id: firestore-rules-creation
name: Cloud Firestore Security Rules Creation
author: Firebase / Google
platform: universal
repository: firebase/skills
path: skills/firestore-rules-creation
default: true
description: Designs, authors, refactors, and hardens production-grade Cloud Firestore Security Rules (firestore.rules).
---

# Cloud Firestore Security Rules Creation

Standards for generating robust, secure, and production-ready Firestore Security Rules (`firestore.rules`).

## Key Principles

1. **Default Deny Baseline**: Start every ruleset with a global deny rule (`match /{document=**} { allow read, write: if false; }`) and selectively permit access.
2. **Granular Operations**: Split rules into granular permissions (`get`, `list`, `create`, `update`, `delete`) rather than blanket `read` and `write` blocks.
3. **Strict Schema & Type Validation**: Validate all incoming payload fields on `create` and `update` using helper functions checking data types, string lengths, and required attributes (`request.resource.data`).
4. **Update Immutability**: Enforce immutable fields during `update` operations (e.g. `request.resource.data.authorId == resource.data.authorId`).
5. **Query Alignment**: Ensure rules accommodate query constraints (`request.query.limit <= 50`) so client queries do not fail due to missing or overly restrictive rule conditions.
