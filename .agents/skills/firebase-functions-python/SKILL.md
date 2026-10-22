---
name: Firebase Cloud Functions (Python 2nd Gen & Polyglot Cloud Run)
description: 2nd Gen Cloud Functions for Firebase in Python (https_fn, firestore_fn, pubsub_fn, scheduler_fn, SecretParam) plus polyglot Go/Container Cloud Run integration.
---

# Firebase Cloud Functions (Python 2nd Gen & Polyglot Cloud Run)

Authoritative engineering standards for building **2nd Gen Cloud Functions for Firebase in Python** (`firebase-functions`) and integrating **polyglot Go / containerized Cloud Run services** with Firebase Hosting, Firebase Auth, Firestore, and Eventarc.

---

## 1. Python 2nd Gen Decorator API (`firebase_functions`)

Always use the official 2nd Gen decorators from `firebase_functions`:

```python
from firebase_functions import (
    https_fn,
    firestore_fn,
    pubsub_fn,
    scheduler_fn,
    identity_fn,
    options,
    params,
)
```

- **HTTP Request Endpoints**: `@https_fn.on_request(...)` receiving `req: https_fn.Request` and returning `https_fn.Response`.
- **Callable Endpoints**: `@https_fn.on_call(...)` receiving `req: https_fn.CallableRequest` and returning JSON-serializable dictionaries or raising `https_fn.HttpsError`.
- **Firestore Event Triggers**: `@firestore_fn.on_document_created(document="items/{item_id}")`, `@firestore_fn.on_document_updated(...)`, `@firestore_fn.on_document_written(...)`.
- **Pub/Sub & Scheduler Triggers**: `@pubsub_fn.on_message_published(topic="...")` and `@scheduler_fn.on_schedule(schedule="every 1 hours")`.

---

## 2. Secret Manager & Typed Parameters (`params`)

- Define secrets and environment parameters declaratively using `params.SecretParam`, `params.StringParam`, and `params.IntParam`.
- **Strict Runtime Resolution Rule**: Never read `SECRET.value` at module import time. Always bind `secrets=[WEBHOOK_SECRET]` in the decorator and read `WEBHOOK_SECRET.value` **only inside the function handler** at runtime. Never log secret values.

```python
from firebase_functions import https_fn, options, params

WEBHOOK_SECRET = params.SecretParam("WEBHOOK_SECRET")
ENVIRONMENT = params.StringParam("ENVIRONMENT", default="production")

@https_fn.on_request(
    secrets=[WEBHOOK_SECRET],
    region=options.SupportedRegion.US_CENTRAL1,
    memory=options.MemoryOption.MB_256,
    max_instances=10,
    timeout_sec=30,
)
def verify_webhook(req: https_fn.Request) -> https_fn.Response:
    # SAFE: Accessed only at runtime inside the request handler
    expected = WEBHOOK_SECRET.value
    provided = req.headers.get("X-Webhook-Secret", "")
    if not provided or provided != expected:
        return https_fn.Response("Unauthorized", status=401)
    return https_fn.Response('{"status":"verified"}', status=200, mimetype="application/json")
```

---

## 3. Lazy `firebase_admin` Initialization for Fast Cold Starts & Offline Tests

Never call `firebase_admin.initialize_app()` or `firestore.client()` at the top level of `main.py`.
1. During `firebase deploy`, the Firebase CLI imports `main.py` in an isolated discovery step to inspect decorated functions.
2. During `pytest` runs, unit tests import `main.py` offline without live Google Cloud Application Default Credentials (ADC).
3. Lazy initialization ensures cold starts only initialize the SDK clients required by the executed function.

```python
import firebase_admin
from firebase_admin import firestore

def get_firebase_app() -> firebase_admin.App:
    """Lazily initialize the default Firebase Admin app on first runtime use."""
    if not firebase_admin._apps:
        return firebase_admin.initialize_app()
    return firebase_admin.get_app()

def get_firestore_client():
    get_firebase_app()
    return firestore.client()
```

---

## 4. Least-Privilege Resource & Concurrency Options

Always configure global defaults and per-function resource limits to prevent runaway scaling and denial-of-wallet attacks:

```python
from firebase_functions import https_fn, options

options.set_global_options(
    region=options.SupportedRegion.US_CENTRAL1,
    max_instances=10,
)

@https_fn.on_call(
    memory=options.MemoryOption.MB_256,
    max_instances=20,
    timeout_sec=30,
    concurrency=80,
    enforce_app_check=True,
    cors=options.CorsOptions(
        cors_origins=["https://app.example.com"],
        cors_methods=["POST", "OPTIONS"],
    ),
)
def create_profile(req: https_fn.CallableRequest) -> dict:
    if req.auth is None:
        raise https_fn.HttpsError(
            code=https_fn.FunctionsErrorCode.UNAUTHENTICATED,
            message="Authentication is required.",
        )
    display_name = (req.data or {}).get("displayName", "")
    if not isinstance(display_name, str) or len(display_name.strip()) < 2:
        raise https_fn.HttpsError(
            code=https_fn.FunctionsErrorCode.INVALID_ARGUMENT,
            message="displayName must be at least 2 characters.",
        )
    return {"uid": req.auth.uid, "displayName": display_name.strip()}
```

---

## 5. Virtual Environment Layout (`venv/`) & Offline `pytest` Verification

- **Firebase CLI Virtual Environment Requirement**: Firebase CLI expects a local `venv/` directory inside the Python functions source folder (`python3 -m venv venv && source venv/bin/activate && pip install -r requirements.txt`). Always exclude `venv/` and `.venv/` in `firebase.json` `functions[].ignore` and `.gitignore`.
- **Pure Testable Helpers**: Factor business validation, payload formatting, and event deduplication into pure Python functions (`build_health_payload()`, `handle_greet_payload(data)`, `validate_create_profile(auth_uid, data)`) so `pytest` runs deterministically in < 1 second without requiring live GCP credentials or a running Emulator Suite.

---

## 6. Polyglot Go & Containerized Cloud Run Interoperability

Because 2nd Gen Firebase Cloud Functions are built directly on **Google Cloud Run** and **Eventarc**, Go backend services (`go-service-starter` or `functions-framework-go`) integrate as first-class citizens in a Firebase architecture:

### 6.1 Firebase Hosting Rewrites to Go Cloud Run Services (`firebase.json`)
Route API paths from Firebase Hosting directly to a containerized Go Cloud Run service:

```json
{
  "hosting": {
    "public": "dist",
    "rewrites": [
      {
        "source": "/api/**",
        "run": {
          "serviceId": "go-api-service",
          "region": "us-central1"
        }
      }
    ]
  }
}
```

### 6.2 Firebase Admin Go SDK (`firebase.google.com/go/v4`)
Verify Firebase Auth ID tokens (`Authorization: Bearer <idToken>`) and interact with Firestore in Go:

```go
package authmw

import (
	"context"
	"net/http"
	"strings"

	firebase "firebase.google.com/go/v4"
	"firebase.google.com/go/v4/auth"
)

func NewFirebaseAuthClient(ctx context.Context) (*auth.Client, error) {
	app, err := firebase.NewApp(ctx, nil)
	if err != nil {
		return nil, err
	}
	return app.Auth(ctx)
}

func VerifyBearerToken(ctx context.Context, client *auth.Client, r *http.Request) (*auth.Token, error) {
	raw := strings.TrimPrefix(r.Header.Get("Authorization"), "Bearer ")
	return client.VerifyIDToken(ctx, raw)
}
```

### 6.3 2nd Gen Cloud Run Functions in Go (`functions-framework-go` & Eventarc)
For event-driven background triggers in Go (such as Firestore document mutations or Pub/Sub events delivered via Eventarc CloudEvents), register a CloudEvent handler with `github.com/GoogleCloudPlatform/functions-framework-go/functions`:

```go
package function

import (
	"context"
	"log/slog"

	"github.com/GoogleCloudPlatform/functions-framework-go/functions"
	cloudevents "github.com/cloudevents/sdk-go/v2"
)

func init() {
	functions.CloudEvent("OnItemCreated", onItemCreated)
}

func onItemCreated(ctx context.Context, event cloudevents.Event) error {
	slog.InfoContext(ctx, "received firestore cloudevent",
		"event_id", event.ID(),
		"source", event.Source(),
		"subject", event.Subject(),
	)
	// Enforce idempotency using event.ID() before mutating downstream state
	return nil
}
```
