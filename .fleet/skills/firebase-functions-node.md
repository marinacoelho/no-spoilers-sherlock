---
id: "firebase-functions-node"
name: "Firebase Cloud Functions (Node.js / TypeScript 2nd Gen)"
author: "firebase"
platform: "universal"
default: true
description: "2nd Gen Cloud Functions for Firebase in TypeScript/Node.js: HTTPS onRequest/onCall, Firestore/Auth/Scheduler triggers, Secret Manager, cold-start lazy init, idempotency, and Emulator testing."
---

# Firebase Cloud Functions (Node.js / TypeScript 2nd Gen)

Authoritative engineering standards for designing, securing, optimizing, and testing **2nd Gen Cloud Functions for Firebase** in TypeScript and Node.js (`firebase-functions/v2`).

---

## 1. Strict 2nd Gen Modular Imports

Always import exclusively from modular **2nd Gen (`v2`)** subpaths. Never import from legacy `firebase-functions/v1` unless maintaining an existing 1st Gen trigger that has no Eventarc equivalent.

```ts
import { onRequest, onCall, HttpsError } from 'firebase-functions/v2/https';
import {
  onDocumentCreated,
  onDocumentUpdated,
  onDocumentWritten,
} from 'firebase-functions/v2/firestore';
import { beforeUserCreated, beforeUserSignedIn } from 'firebase-functions/v2/identity';
import { onSchedule } from 'firebase-functions/v2/scheduler';
import { onTaskDispatched } from 'firebase-functions/v2/tasks';
import { onMessagePublished } from 'firebase-functions/v2/pubsub';
import { onObjectFinalized } from 'firebase-functions/v2/storage';
import { defineSecret, defineString, defineInt } from 'firebase-functions/params';
import * as logger from 'firebase-functions/logger';
```

---

## 2. Secret Manager & Parameterized Configuration

- **Prohibition of `functions.config()`**: `functions.config()` is deprecated and prohibited in 2nd Gen functions. Always use `defineSecret()`, `defineString()`, or `defineInt()` from `firebase-functions/params`.
- **Runtime-Only Secret Resolution**: Never call `secret.value()` at the module top level (import time). `secret.value()` **MUST** only be accessed inside the function handler at runtime, and the function must bind the secret in its options (`{ secrets: [WEBHOOK_SECRET] }`).
- **Zero Secret Logging**: Never log secret values or full authorization headers in `logger.info` / `logger.error`.

```ts
import { onRequest } from 'firebase-functions/v2/https';
import { defineSecret, defineString } from 'firebase-functions/params';

const WEBHOOK_SECRET = defineSecret('WEBHOOK_SECRET');
const ALLOWED_ORIGIN = defineString('ALLOWED_ORIGIN', { default: 'https://example.com' });

export const webhookReceiver = onRequest(
  {
    region: 'us-central1',
    secrets: [WEBHOOK_SECRET],
    maxInstances: 10,
    timeoutSeconds: 30,
    memory: '256MiB',
  },
  async (req, res) => {
    // SAFE: Resolved only inside the runtime invocation handler
    const expectedSecret = WEBHOOK_SECRET.value();
    const signature = req.header('x-webhook-secret');

    if (!signature || signature !== expectedSecret) {
      res.status(401).json({ error: 'Unauthorized webhook signature' });
      return;
    }

    res.status(200).json({ received: true });
  }
);
```

---

## 3. Least-Privilege Resource & Billing Guardrails

Unbounded serverless concurrency can lead to denial-of-wallet amplification during traffic spikes or infinite trigger loops. Every 2nd Gen function (or `setGlobalOptions`) MUST explicitly bound its execution profile:

- `region`: Pin functions close to your Firestore location (e.g., `'us-central1'` or `'europe-west1'`).
- `maxInstances`: Cap maximum container scaling (e.g., `10` for internal/webhook endpoints, `50`–`100` for public APIs) to prevent runaway billing.
- `concurrency`: Configure per-instance concurrent requests (`80` default on 2nd Gen Cloud Run when CPU >= 1, or lower `1`–`20` for CPU/memory-intensive workloads).
- `timeoutSeconds`: Set tight timeouts (`15`–`60` seconds for HTTP/Callable handlers; avoid the 540s/3600s ceiling unless running batch jobs).
- `memory`: Right-size memory (`'256MiB'` or `'512MiB'`).
- `cors`: Restrict CORS to explicit origin allowlists (`cors: ['https://app.example.com']`) rather than wildcard `true` on sensitive endpoints.

---

## 4. Cold-Start Optimization & Lazy Singleton Initialization

Never initialize `firebase-admin`, Firestore clients, or heavy third-party SDKs (Stripe, OpenAI, Vertex AI) at module import time. Why:
1. Firebase CLI imports `src/index.ts` during deployment discovery; eager initialization slows down deploys and can fail when credentials are absent.
2. A cold boot for a lightweight HTTP function should not pay the initialization cost of SDKs only used by a background trigger.
3. Unit tests (`vitest`) must be able to import `src/index.ts` offline without live GCP credentials.

```ts
import { getApps, getApp, initializeApp, type App } from 'firebase-admin/app';
import { getFirestore, type Firestore } from 'firebase-admin/firestore';

let cachedDb: Firestore | undefined;

export function ensureFirebaseApp(): App {
  return getApps().length === 0 ? initializeApp() : getApp();
}

export function getDb(): Firestore {
  if (!cachedDb) {
    ensureFirebaseApp();
    cachedDb = getFirestore();
  }
  return cachedDb;
}
```

---

## 5. Callable (`onCall`) Security, Validation & App Check

Callable functions automatically deserialize requests and attach Firebase Auth and App Check context. Always enforce:
1. `enforceAppCheck: true` in production to block abusive non-app traffic.
2. Explicit authentication checks (`if (!request.auth)`) throwing typed `HttpsError('unauthenticated', ...)`.
3. Strict payload validation throwing `HttpsError('invalid-argument', ...)`—never throw raw `Error` objects that leak internal stack traces to clients.

```ts
import { onCall, HttpsError } from 'firebase-functions/v2/https';

export const createProfile = onCall(
  {
    region: 'us-central1',
    maxInstances: 20,
    timeoutSeconds: 30,
    memory: '256MiB',
    enforceAppCheck: true,
  },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'Authentication is required.');
    }

    const displayName = request.data?.displayName;
    if (typeof displayName !== 'string' || displayName.trim().length < 2) {
      throw new HttpsError(
        'invalid-argument',
        'A valid displayName (at least 2 characters) is required.'
      );
    }

    return {
      uid: request.auth.uid,
      displayName: displayName.trim(),
    };
  }
);
```

---

## 6. Event-Driven Idempotency & Infinite-Loop Prevention

Background triggers (`onDocumentCreated`, `onDocumentUpdated`, `onMessagePublished`) have **at-least-once** delivery guarantees. Duplicate deliveries WILL happen under retries or network partitions.

1. **Deduplicate by `event.id`**: Record processed `event.id` values inside a Firestore transaction (`_processed_events/{eventId}`) or verify a state transition flag on the target document before applying side effects (emails, billing charges, counters).
2. **Prevent Infinite Write Loops**: If an `onDocumentUpdated` trigger writes back to the same document or collection, always compare `event.data?.before.data()` and `event.data?.after.data()` and exit immediately if the relevant fields did not change or if the update already reflects the processed state.

```ts
import { onDocumentCreated } from 'firebase-functions/v2/firestore';
import * as logger from 'firebase-functions/logger';
import { getDb } from './admin.js';

export const onOrderCreated = onDocumentCreated(
  {
    document: 'orders/{orderId}',
    region: 'us-central1',
    maxInstances: 20,
    timeoutSeconds: 60,
    memory: '256MiB',
  },
  async (event) => {
    const snapshot = event.data;
    if (!snapshot) return;

    const db = getDb();
    const eventRef = db.collection('_processed_events').doc(event.id);

    const shouldProcess = await db.runTransaction(async (tx) => {
      const existing = await tx.get(eventRef);
      if (existing.exists) {
        return false;
      }
      tx.set(eventRef, {
        eventId: event.id,
        orderId: event.params.orderId,
        processedAt: new Date().toISOString(),
      });
      return true;
    });

    if (!shouldProcess) {
      logger.info('Skipping duplicate event delivery', { eventId: event.id });
      return;
    }

    logger.info('Processed new order', { orderId: event.params.orderId, eventId: event.id });
  }
);
```

---

## 7. Offline Unit Testing (Vitest) & Emulator Integration Testing

1. **Extract Pure Handler Functions for Instant Unit Tests**:
   Separate business validation, auth checks, and payload transformation into exported pure functions (`handleHealthRequest`, `validateGreetingPayload`, `handleCreateProfileCall`) that `onRequest` / `onCall` wrap. This enables `vitest run` (`npm test`) to execute in milliseconds with zero network or Emulator daemon dependencies.
2. **Local Emulator Integration Testing**:
   For end-to-end trigger and Firestore rules verification, run tests inside the Firebase Local Emulator Suite:
   ```bash
   firebase emulators:exec --only functions,firestore "npm test"
   ```
