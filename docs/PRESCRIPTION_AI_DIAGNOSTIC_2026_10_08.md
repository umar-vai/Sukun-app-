# Prescription AI investigation — 2026-10-08

Status: diagnosis in progress, **not a verified fix**. Work is isolated to
`web-preview`; the interrupted local `main` checkout is preserved separately.

## Confirmed evidence

- Inspected production document function v14 and typed function v10 in
  `vydfafumxptanpkmtrpr` before changes.
- Private upload, authorization and transcription succeed. Successful runtime
  logs identify `gemini-3.5-flash-lite`, using `POST /v1beta/interactions`.
- The subsequent parser logs `malformed_output` on all four slots, including
  same-slot retries. This follows successful HTTP responses, but could mean
  missing response text, invalid JSON, or an invalid action schema.
- Earlier `gemini-3.5-flash` attempts returned 400 `INVALID_ARGUMENT`. This
  alone does not prove model unavailability. No model was changed here.
- v14's action request sends `model`, `store:false`, and text `input` only.
  Its prompt refers to a supplied schema but no schema is supplied. The
  exported `geminiResponseSchema` is unused. This is a confirmed contract gap,
  but the exact production rejection still needs diagnostics.
- Existing tests return hand-authored valid action JSON, not captured live
  response shapes.
- Typed AI is deployed as a separate v10 bundle using `generateContent`, not
  the Interactions client on this branch. There are no recorded typed-only
  `ai_generation_requests` in production. Typed AI success is unverified.

## End-to-end trace

1. Flutter validates bytes and calls `create_prescription_attachment`.
2. The RPC requires Super Admin and creates an audited upload intent.
3. Flutter uploads privately and sends only attachment/request identifiers to
   `prescription-document-to-actions`.
4. The function verifies user/role, claims processing, downloads privately,
   and validates signature and size.
5. Bytes are base64-encoded **server-side only** for transcription.
6. The transcript goes through the shared four-slot router, Gemini adapter,
   and `parseSuggestedActions`.
7. Only validated output reaches service-only `finalize_prescription_attachment`.
   The transaction preserves the source/transcription, stores suggestions and
   creates a **draft** care plan. It neither approves actions nor publishes.
8. Flutter seeds `AiActionReviewScreen` with those suggestions. Imported
   actions remain unapproved; explicit approval occurs in the plan builder.

The observed failure is step 6, before finalization. Live finalization and
Flutter review still require verification.

## Diagnostic-only deployment

Document **v15** adds `ai_response_diagnostic`. No endpoint, model, prompt,
parser behavior, role check, migration or patient-care behavior changed.
Only allowlisted envelope/expected-action field names, primitive frequency
shape, HTTP status, model, endpoint and request ID are recorded.

Categories: `output_text_missing`, `output_json_invalid`,
`action_schema_invalid`, `valid`. Never log provider bodies/errors, prescription
text, document bytes, credentials or signed URLs.

Three tests assert categories and absence of input text/keys. All 38 Edge
tests and all six function entry-point type checks pass locally. Formatting
passes after normalizing Windows checkout line endings. No Flutter code changed.

## Still required

- Retry the authenticated request against v15; inspect the safe diagnostics.
  The connected phone's stored session is expired; it was not manually
  refreshed or changed.
- Establish the actual live output envelope and precise validation failure.
- Reproduce that failure in a regression before applying a behavioral fix.
- Validate the structured request contract using the configured runtime model
  and keys server-side, without cycling model names.
- Verify document finalization, explicit human review and real typed AI.

Reference: [Google Interactions structured output](https://ai.google.dev/gemini-api/docs/structured-output)
documents `response_format: {type: "text", mime_type: "application/json", schema: ...}`.
Documentation support alone is not proof of runtime acceptance.
