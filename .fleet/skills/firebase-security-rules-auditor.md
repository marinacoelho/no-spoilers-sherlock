---
id: firebase-security-rules-auditor
name: Firebase Security Rules Auditor & Red Team
author: Firebase / Google
platform: universal
repository: firebase/skills
path: skills/firebase-security-rules-auditor
default: true
description: Audits Firebase security rules for vulnerabilities, privilege escalation, role bypasses, and data injection holes.
---

# Firebase Security Rules Auditor & Red Team

Rigorous auditing protocols and adversarial test vectors for Cloud Firestore and Storage security rules.

## Key Principles

1. **Update Bypass Detection**: Verify whether an unprivileged user can create a valid resource and subsequently modify restricted attributes (e.g., `role`, `isAdmin`, `isPaid`) on update.
2. **Authority Source Auditing**: Ensure authorization decisions rely exclusively on server-verified data (`request.auth.token`, `get(/databases/$(database)/documents/users/$(request.auth.uid)).data`) rather than untrusted client payload values.
3. **Resource Exhaustion Checks**: Verify that strings, lists, and maps enforce upper bound limits to prevent database denial-of-service or billing abuse.
4. **HasOnly Ownership Enforcement**: Check that client updates cannot inject unexpected, unvalidated fields into documents.
5. **Local Rules Emulation**: Test rules suites against the Firebase Rules Unit Testing library (`@firebase/rules-unit-testing`) before deployment.
