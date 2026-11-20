# CRM developer handoff

What you can build against today: everything in `API_CONTRACT.md`. It is verified on the
SukunLife side only; no CRM has called it yet.

1. Pull the catalog: `GET /templates`, store `template_id`, `template_revision`, `parameters`.
   Show raqis the placeholders as required inputs (count, days, minutes).
2. Template customisation stays inside the prescription item (`patient_instruction`, `title`);
   it never edits the master. To suggest a change to a master template, send it to the
   SukunLife team (a reviewed request process, not an API write).
3. When a patient is registered, call `POST /patients/provision`; show the returned ID and temporary
   password to staff once (never store or log them) so they can hand them to the patient. When a
   prescription is confirmed, call `POST /prescriptions`. (`POST /patients/link` maps an already existing
   SukunLife profile.) Always send explicit counts, frequency and reminder times.
4. Revisions use the same `crm_prescription_id` with a higher `version`. Cancel with
   `prescription.cancelled` and a higher version.
5. Expose a webhook that accepts `progress_event.v1`, verifies our signature (same algorithm,
   your secret), deduplicates on `event_id`, and answers 2xx. Or poll `GET /progress`.
6. Test against the fixtures in `docs/integrations/fixtures/`.

Needed from you: the webhook URL and a key id plus secret for it; the CRM ids you will use for
patient, customer and family; confirmation of the CRM customer to family relationship.
Needed from SukunLife before go-live: the CRM signing key and the staging URL.
