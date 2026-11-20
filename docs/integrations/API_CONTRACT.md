# CRM to SukunLife API contract (v1)

Base: `https://<project-ref>.supabase.co/functions/v1/crm-integration`
(Production ref and rules: `docs/PRODUCTION_ENVIRONMENT.md`. Use staging first.)

Machine readable contracts: `docs/integrations/schemas/*.json`.
Worked examples: `docs/integrations/fixtures/*.json`.

## Authentication

Every request carries:

| Header | Value |
| --- | --- |
| `X-Sukun-Key-Id` | id of the signing key (supports rotation) |
| `X-Sukun-Timestamp` | unix seconds, accepted within 5 minutes |
| `X-Sukun-Request-Id` | your unique id, `[A-Za-z0-9._:-]`, max 128 |
| `X-Sukun-Signature` | `v1=` + lowercase hex HMAC-SHA256 |

Signed string, lines joined by `\n`:

```
v1
<timestamp>
<request id>
<METHOD upper case>
<path and query, e.g. /crm-integration/prescriptions>
<lowercase hex SHA-256 of the exact raw body bytes (empty for GET)>
```

Any failure returns `401 {"code":"unauthorized"}`. The signed path starts at the
function name; confirm it once against the deployed runtime.

## Routes

### GET /templates
Query: `updated_since` (ISO time), `after_id` (cursor from `next_cursor`), `limit` (1 to 500).
Returns the catalog document (`template_catalog.v1`). `catalog_version` changes only when
template content changes; `template_revision` identifies one template's content. Hidden
templates come back with `active:false`; never delete a mirrored template because a
request failed or because it is hidden. Supports `ETag` / `If-None-Match` (304).
Recovery from missed syncs: do a full sync (no `updated_since`) and compare `catalog_version`.

### POST /patients/link
Body: `{ "sukun_patient_id": uuid, "crm_patient_id": "...", "crm_customer_id": "...?", "crm_family_id": "...?", "relationship_label": "...?" }`.
Maps a SukunLife profile to CRM ids. `409 identity_conflict` if the CRM id already points to a
different profile (never merged), `404 patient_not_found`.


### POST /patients/provision
Body: `{ "request_id": uuid, "crm_patient_id", "full_name", "phone": "01XXXXXXXXX (any common spelling)", "crm_customer_id?", "crm_family_id?", "relationship_label?" }`.
Creates the patient if the CRM id is not mapped yet, maps the ids, and sends a one-time activation
link by WhatsApp. Safe to repeat: it never creates a second patient and never resets a password.
A repeat call is also how you resend (the previous link stops working).

- New single patient, or the first member of a new family: a login is created with a random
  password nobody knows; `phone` is required (Bangladesh mobile).
- A new member of an existing family (`crm_family_id` already known): a profile without its own
  login, no link is sent (`activation.status = "no_login"`); the family login is used.
- An account that already chose its password: `activation.status = "already_active"`, nothing changes.
- `activation.delivery` is `sent`, `failed` or `not_configured`. The link itself is never returned.
- Errors: `409 account_exists_for_phone`, `409 identity_conflict`, `400 invalid_phone | phone_required`.

The patient opens `<app>/activate#token=...`, which calls the public `account-activate` function
with `{token, new_password}`; the link is valid 24 hours and works once.

### POST /prescriptions
Body: `prescription_event.v1`. Only final, confirmed prescriptions. Drafts are never sent.

| Result | HTTP | Meaning |
| --- | --- | --- |
| `{"status":"applied", ...}` | 200 | new care plan version is active; ids and `warnings` returned |
| same, `"replayed":true` | 200 | the event id was already applied with the same content |
| `{"status":"stale"}` | 409 | version is not newer than what is applied; nothing changed |
| `{"status":"rejected","code":...}` | 422 / 409 | see codes below; fix and resend (same `event_id` is fine) |

Rejection codes: `invalid_event`, `patient_not_mapped`, `family_mismatch`,
`prescription_not_found` (cancel before issue), `prescription_not_final`, `missing_start_date`,
`invalid_date_range`, `no_items`, `invalid_item`, `template_not_found`, `template_inactive`,
`missing_parameter`, `missing_frequency`, `missing_reminder_times`, `invalid_reminder_time`,
`invalid_parameter`, `event_id_reuse_conflict` (same id, different body: use a new id).

Rules that protect patients: counts, days, minutes, frequency and reminder times are never
guessed or defaulted from the template; a missing one rejects the whole event and nothing is
partly applied. One plan action is created per item and reminder time. Linked resources that are
unpublished or staff-only are skipped and listed in `warnings`.
Staff-only notes have no field: keep them in the CRM.

### GET /progress?crm_patient_id=...&from=YYYY-MM-DD&to=YYYY-MM-DD
At most 93 days. Returns `progress_summary.v1`. `adherence_percent = completed / total`
(cancelled tasks excluded). This is the only adherence rule; do not recompute it in the CRM.

### Progress push (SukunLife to CRM)
Each task completion, skip or snooze of a CRM-linked patient is queued and delivered to your
webhook as `progress_event.v1`, signed with the same scheme using a key id and secret the CRM
gives us. Deduplicate on `event_id`. Reply any 2xx to acknowledge; anything else is retried
with exponential backoff and finally dead-lettered. Also available by pull through `/progress`.

## .NET: signing a request

```csharp
using System.Security.Cryptography;
using System.Text;

static string Sign(string secret, string timestamp, string requestId,
                   string method, string pathAndQuery, string body)
{
    var bodyHash = Convert.ToHexString(
        SHA256.HashData(Encoding.UTF8.GetBytes(body))).ToLowerInvariant();
    var canonical = string.Join("\n",
        "v1", timestamp, requestId, method.ToUpperInvariant(), pathAndQuery, bodyHash);
    using var hmac = new HMACSHA256(Encoding.UTF8.GetBytes(secret));
    return "v1=" + Convert.ToHexString(
        hmac.ComputeHash(Encoding.UTF8.GetBytes(canonical))).ToLowerInvariant();
}

// usage
var body = JsonSerializer.Serialize(evt);                 // send exactly these bytes
var ts = DateTimeOffset.UtcNow.ToUnixTimeSeconds().ToString();
var rid = Guid.NewGuid().ToString("N");
var req = new HttpRequestMessage(HttpMethod.Post, baseUrl + "/prescriptions")
{
    Content = new StringContent(body, Encoding.UTF8, "application/json")
};
req.Headers.Add("X-Sukun-Key-Id", keyId);
req.Headers.Add("X-Sukun-Timestamp", ts);
req.Headers.Add("X-Sukun-Request-Id", rid);
req.Headers.Add("X-Sukun-Signature",
    Sign(secret, ts, rid, "POST", "/crm-integration/prescriptions", body));
```

Keep the secret in the CRM backend only, never in the React app.
Retry rule: on timeout or 5xx resend the identical event (same `event_id`, same body).
