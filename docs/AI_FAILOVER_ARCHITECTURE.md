# Sukun Life — AI Failover Architecture

This document is a mandatory implementation specification for the Prescription → Action AI subsystem.

## Goal

The Super Admin must **never see Gemini quota/credit/rate-limit/provider errors** during normal use.

The backend must detect an exhausted/unavailable Gemini credential and automatically retry the same request with the next configured Gemini API credential.

The Flutter app must not know which key/provider slot was used.

## Required architecture

```text
Flutter Admin UI
      |
      | Generate Actions
      v
Supabase Edge Function / Server AI Router
      |
      +--> Gemini Key Slot 1
      |       |
      |       +-- success --> validate JSON --> return draft actions
      |       |
      |       +-- quota/rate limit/unavailable --> silently fail over
      |
      +--> Gemini Key Slot 2
      |       |
      |       +-- success --> validate JSON --> return draft actions
      |       +-- quota/rate limit/unavailable --> silently fail over
      |
      +--> Gemini Key Slot 3
      |       |
      |       +-- success --> validate JSON --> return draft actions
      |       +-- quota/rate limit/unavailable --> silently fail over
      |
      +--> Gemini Key Slot 4
              |
              +-- success --> validate JSON --> return draft actions
              +-- unavailable --> manual-action fallback
```

## Four Gemini credentials

Use four server-side secret slots:

```text
GEMINI_API_KEY_1
GEMINI_API_KEY_2
GEMINI_API_KEY_3
GEMINI_API_KEY_4
```

Optional configuration:

```text
GEMINI_MODEL=
AI_KEY_COOLDOWN_SECONDS=3600
AI_REQUEST_TIMEOUT_MS=25000
AI_MAX_RETRY_PER_KEY=1
```

These values are **server-only secrets/configuration**. Never put Gemini keys in Flutter, Dart source, committed `.env` files, remote config readable by clients, logs, analytics, crash reports, or UI error text.

## Important quota assumption

Do **not** assume that four API keys automatically mean four independent quota pools.

Before production, verify how quota is scoped for the chosen Gemini setup. If independent failover capacity is required, configure the credentials in independent quota scopes/projects where permitted and compliant with Google's terms. If multiple keys share the same quota scope, the router must treat them as one effective quota pool because they may become exhausted together.

Do not build a system intended to evade provider restrictions or terms. The purpose of this design is legitimate availability/redundancy across properly configured credentials.

## Key selection

Create a server-side `GeminiKeyPool` / `AiRouter` abstraction.

The Flutter application must call one endpoint such as:

```text
POST /functions/v1/prescription-to-actions
```

It must never select API keys itself.

The backend should try healthy slots in priority order:

```text
1 -> 2 -> 3 -> 4
```

A later version may use round-robin/least-recently-used selection, but deterministic priority order is preferred for the MVP.

## Failure classification

The router must distinguish failures before deciding what to do.

### Fail over to next key silently

Examples:

- quota exhausted / resource exhausted
- HTTP 429 / rate limit
- daily or request limit exhausted
- temporary provider-side capacity/unavailable errors
- repeated timeout after the allowed retry
- server 5xx after allowed retry

### Disable/skip a broken key and fail over

Examples:

- invalid/revoked credential
- permission error caused by credential configuration
- malformed server configuration

These should be logged internally as operational issues, but the raw error must not be shown to the Super Admin.

### Do not hide application/input errors by cycling all keys unnecessarily

Examples:

- prescription text is empty
- request schema is invalid
- output schema validation fails because of our own code contract

Handle these as application validation problems. If an AI response is malformed, one controlled retry may be attempted; then try the next healthy slot if appropriate.

## Cooldown / health state

When a slot returns a quota/rate-limit/provider exhaustion error, mark it unavailable in a short-lived server-side health cache:

```text
slot_id
status: healthy | cooling_down | disabled
failure_type
failed_at
retry_after / exhausted_until
consecutive_failures
```

During cooldown, requests should skip that slot rather than repeatedly wasting latency on a known exhausted key.

Use provider `Retry-After` information when available. Otherwise use a configurable backoff/cooldown.

Do not store the API key itself in database health tables.

## Admin UX rule — mandatory

Never surface messages such as:

- `429 RESOURCE_EXHAUSTED`
- `quota exceeded`
- `daily limit reached`
- `Gemini key exhausted`
- key number/provider credentials
- provider stack traces

The normal success path must look identical regardless of whether slot 1 or slot 4 generated the result.

If all four AI slots are unavailable, the app must **not expose the provider/quota failure**. Instead:

1. record the failure internally;
2. keep the original prescription safe;
3. open/offer the existing manual Action Builder;
4. show at most a neutral product-level message such as `Automatic action generation is temporarily unavailable. You can continue manually.`

Prefer an even smoother UX where the manual builder opens with the prescription already attached, so the admin's workflow does not stop.

## Human-review rule remains unchanged

Failover does not change medical/religious safety requirements.

AI output is always a draft suggestion.

```text
AI result
   -> schema validation
   -> draft / needs_review
   -> Super Admin review/edit
   -> explicit approval
   -> publish to patient
```

No Gemini slot may auto-publish a patient plan.

AI must never invent:

- dosage
- exact times not present in the source
- treatment instructions
- religious rulings
- missing prescription facts

Ambiguous values must be `null` and/or `needs_review=true`.

## Stable output contract

Every Gemini key slot must use the same model settings, prompt contract and JSON schema so failover is invisible to the rest of the system.

The AI Router must normalize the result into the app's canonical Prescription → Action schema before returning it.

Do not let provider-specific response objects leak beyond the server adapter.

## Idempotency

A failover can cause more than one provider request for one user action. Use a client/server request ID so repeated attempts do not create duplicate prescription/action records.

Recommended request metadata:

```text
request_id UUID
prescription_id UUID
requested_by UUID
created_at
```

Only persist the accepted normalized result once.

## Logging and observability

Operational logs may record:

- request ID
- key slot number (1-4, never the secret)
- model
- latency
- success/failure class
- fallback count
- schema-validation result
- timestamp

Do not log raw API keys.

Avoid logging full prescription text to third-party analytics/error trackers. Prescription data can be sensitive.

Recommended internal metrics:

```text
ai_requests_total
ai_requests_success
ai_fallback_count
ai_slot_1_failures
ai_slot_2_failures
ai_slot_3_failures
ai_slot_4_failures
ai_all_slots_unavailable
ai_schema_validation_failures
ai_latency_ms
```

## Suggested server structure

```text
supabase/functions/prescription-to-actions/
  index.ts
  ai/
    ai-router.ts
    gemini-client.ts
    gemini-key-pool.ts
    error-classifier.ts
    output-schema.ts
    prompt.ts
  tests/
    ai-router.test.ts
    fixtures/
```

Keep the provider/key-routing code independent from prescription domain logic.

## Required tests

At minimum test:

1. Slot 1 succeeds -> slots 2-4 are not called.
2. Slot 1 quota-exhausted -> slot 2 succeeds -> UI receives normal result.
3. Slots 1-2 exhausted -> slot 3 succeeds.
4. Slots 1-3 exhausted -> slot 4 succeeds.
5. All four exhausted -> no raw quota error reaches Flutter; manual fallback is returned.
6. Invalid/revoked slot is skipped and recorded internally.
7. Timed-out slot falls through according to retry policy.
8. A known cooling-down slot is skipped.
9. Malformed AI JSON is rejected by schema validation.
10. Multiple failover attempts do not create duplicate actions.
11. API keys never appear in API responses or logs.
12. Approved-action human review is still required after any successful slot.

## Definition of done

The feature is complete only when an automated integration test can simulate quota exhaustion on keys 1, 2 and 3, obtain a valid result through key 4, and prove that the Flutter-facing response contains no quota/provider/key error details.
