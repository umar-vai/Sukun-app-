// CRM-triggered patient provisioning with a generated temporary credential.
//
// OWNER DECISION: no WhatsApp integration yet. SukunLife generates the patient
// ID and a temporary password and returns them ONCE in this response; the CRM
// shows them to staff, who pass them to the patient by hand. The account is
// forced to change the password at first login.
//
// Safe to call again for the same crm_patient_id: it never creates a second
// patient and never touches an account whose owner already chose a password.
// A repeat call for an account that has not logged in yet issues a NEW
// temporary password (the old one stops working), which is how staff resend.
// The response contains a secret: the CRM must show it once, never store or
// log it. Responses are `Cache-Control: no-store`.
import type { SupabaseClient } from "@supabase/supabase-js";
import {
  generatePatientCode,
  generateTemporaryPassword,
  normalizeBangladeshPhone,
} from "./credentials.ts";

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

type Result = { status: number; body: Record<string, unknown> };
const fail = (status: number, code: string): Result => ({
  status,
  body: { code },
});

function text(value: unknown, max: number): string | null {
  if (typeof value !== "string") return null;
  const trimmed = value.trim();
  return trimmed.length >= 1 && trimmed.length <= max ? trimmed : null;
}

export async function provisionPatient(
  db: SupabaseClient,
  actorUserId: string,
  raw: unknown,
): Promise<Result> {
  if (!raw || typeof raw !== "object" || Array.isArray(raw)) {
    return fail(400, "invalid_request");
  }
  const body = raw as Record<string, unknown>;
  const requestId = typeof body.request_id === "string" ? body.request_id : "";
  const crmPatientId = text(body.crm_patient_id, 128);
  const fullName = text(body.full_name, 160);
  const crmFamilyId = body.crm_family_id === undefined
    ? null
    : text(body.crm_family_id, 128);
  const crmCustomerId = body.crm_customer_id === undefined
    ? null
    : text(body.crm_customer_id, 128);
  if (!UUID.test(requestId) || !crmPatientId || !fullName) {
    return fail(400, "invalid_request");
  }
  const phone = body.phone === undefined || body.phone === null
    ? null
    : normalizeBangladeshPhone(String(body.phone));
  if (body.phone && !phone) return fail(400, "invalid_phone");

  // 1. Existing mapping wins. Never match by phone or name.
  const { data: ref } = await db.from("patient_external_refs")
    .select("patient_id")
    .eq("source_system", "crm_patient")
    .eq("external_id", crmPatientId)
    .maybeSingle();
  let patientId: string | null = ref?.patient_id ?? null;
  let freshPassword: string | null = null;
  let created = false;

  if (!patientId) {
    // 2a. A profile for an existing family has no login of its own.
    let familyExists = false;
    if (crmFamilyId) {
      const { data: family } = await db.from("family_accounts").select("id")
        .eq("crm_family_id", crmFamilyId).maybeSingle();
      familyExists = Boolean(family);
    }

    let userId: string | null = null;
    if (!familyExists) {
      if (!phone) return fail(400, "phone_required");
      // 2b. New login with a generated temporary password.
      freshPassword = generateTemporaryPassword();
      const seed = crypto.randomUUID().replaceAll("-", "");
      const { data: authUser, error } = await db.auth.admin.createUser({
        email: `patient-${seed}@patients.auth.sukunlife.invalid`,
        phone: phone.e164,
        password: freshPassword,
        email_confirm: true,
        phone_confirm: true,
        user_metadata: { full_name: fullName, patient_phone: phone.e164 },
      });
      if (error || !authUser.user) {
        // 422 means the phone already has an account: report, never merge.
        return error?.status === 422
          ? fail(409, "account_exists_for_phone")
          : fail(503, "provision_failed");
      }
      userId = authUser.user.id;
    }

    let patient: { id: string } | null = null;
    for (let attempt = 0; attempt < 4 && !patient; attempt += 1) {
      const { data, error } = await db.rpc("integration_provision_patient", {
        p_actor_user_id: actorUserId,
        p_user_id: userId,
        p_full_name: fullName,
        p_phone: phone?.e164 ?? null,
        p_patient_code: generatePatientCode(),
        p_request_id: requestId,
      });
      if (!error && data) patient = data as { id: string };
      else if (error?.code !== "23505") break;
    }
    if (!patient) {
      if (userId) await db.auth.admin.deleteUser(userId);
      return fail(503, "provision_failed");
    }
    patientId = patient.id;
    created = true;
  }

  // 3. Map ids (and family). A conflict is reported, never merged.
  const { error: linkError } = await db.rpc("integration_link_patient", {
    p_actor_user_id: actorUserId,
    p_patient_id: patientId,
    p_crm_patient_id: crmPatientId,
    p_crm_customer_id: crmCustomerId,
    p_crm_family_id: crmFamilyId,
    p_relationship_label: text(body.relationship_label, 60),
  });
  if (linkError) {
    return linkError.code === "23505"
      ? fail(409, "identity_conflict")
      : fail(503, "provision_failed");
  }

  // 4. Credentials, only for an account that has not chosen its own password.
  const { data: state, error: stateError } = await db.rpc(
    "integration_patient_credential_state",
    { p_actor_user_id: actorUserId, p_patient_id: patientId },
  );
  if (stateError) return fail(503, "provision_failed");

  const out: Record<string, unknown> = {
    patient_id: patientId,
    created,
    patient_code: state.patient_code,
    credentials: { status: state.status },
  };
  if (state.status !== "needs_credentials") {
    // already_active keeps its password; no_login uses the family login.
    return { status: 200, body: out };
  }

  if (!freshPassword) {
    // Existing account that has not logged in yet: issue a new password.
    freshPassword = generateTemporaryPassword();
    const { error } = await db.auth.admin.updateUserById(state.user_id, {
      password: freshPassword,
    });
    if (error) return fail(503, "credential_failed");
  }
  await db.rpc("integration_record_credential_issue", {
    p_actor_user_id: actorUserId,
    p_patient_id: patientId,
    p_reason: created ? "created" : "resent",
  });
  out.credentials = {
    status: "issued",
    login_id: state.patient_code,
    temporary_password: freshPassword,
    must_change_password: true,
  };
  return { status: 200, body: out };
}
