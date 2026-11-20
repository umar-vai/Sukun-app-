// CRM-triggered patient provisioning and one-time activation.
//
// Safe to call again for the same crm_patient_id: it never creates a second
// patient, never resets an activated account's password, and a repeat call
// simply issues a fresh activation link (the old one stops working).
// The activation token is NEVER returned to the CRM; it only travels in the
// WhatsApp message to the patient.
import type { SupabaseClient } from "@supabase/supabase-js";
import {
  buildActivationLink,
  generateActivationToken,
  generatePatientCode,
  generateUnknownPassword,
  hashActivationToken,
  normalizeBangladeshPhone,
  readWhatsAppConfig,
  sendActivationWhatsApp,
} from "./activation.ts";

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
  env: { activationBaseUrl: string; getEnv: (n: string) => string | undefined },
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
      // 2b. New login with a random password nobody knows.
      const seed = crypto.randomUUID();
      const { data: created, error } = await db.auth.admin.createUser({
        email: `patient-${
          seed.replaceAll("-", "")
        }@patients.auth.sukunlife.invalid`,
        phone: phone.e164,
        password: generateUnknownPassword(),
        email_confirm: true,
        phone_confirm: true,
        user_metadata: { full_name: fullName, patient_phone: phone.e164 },
      });
      if (error || !created.user) {
        // 422 means the phone already has an account: report, never merge.
        return error?.status === 422
          ? fail(409, "account_exists_for_phone")
          : fail(503, "provision_failed");
      }
      userId = created.user.id;
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

  // 4. Activation link, only for an account that has not chosen a password.
  const token = generateActivationToken();
  const { data: issued, error: issueError } = await db.rpc(
    "integration_issue_activation",
    {
      p_actor_user_id: actorUserId,
      p_patient_id: patientId,
      p_token_hash: await hashActivationToken(token),
      p_phone_digits: phone?.digits ?? null,
      p_ttl_minutes: 1440,
    },
  );
  if (issueError) return fail(503, "activation_failed");

  const out: Record<string, unknown> = { patient_id: patientId };
  if (issued.status !== "issued") {
    // already_active (keeps its password) or no_login (family profile).
    out.activation = { status: issued.status };
    return { status: 200, body: out };
  }

  // The number to message: the one in this request, else the stored one.
  let digits = phone?.digits ?? null;
  if (!digits) {
    const { data: p } = await db.from("patients").select("phone")
      .eq("id", patientId).maybeSingle();
    digits = p?.phone
      ? normalizeBangladeshPhone(p.phone)?.digits ?? null
      : null;
  }
  let delivery = "not_configured" as "sent" | "failed" | "not_configured";
  if (digits && env.activationBaseUrl) {
    delivery = await sendActivationWhatsApp({
      config: readWhatsAppConfig(env.getEnv),
      toDigits: digits,
      link: buildActivationLink(env.activationBaseUrl, token),
    });
  }
  await db.rpc("integration_set_activation_delivery", {
    p_activation_id: issued.activation_id,
    p_status: delivery,
  });
  out.activation = {
    status: "issued",
    delivery,
    expires_at: issued.expires_at,
  };
  return { status: 200, body: out };
}
