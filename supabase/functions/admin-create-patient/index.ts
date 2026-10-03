import { createClient } from "@supabase/supabase-js";
import {
  type CreatePatientInput,
  parseCreatePatientInput,
} from "./validation.ts";
import { createInternalPatientEmail } from "./auth-identity.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

type PatientRecord = {
  id: string;
  user_id: string;
  patient_code: string;
  full_name: string;
  phone: string;
  status: "active";
  created_at: string;
};

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

function requiredEnvironment(name: string): string {
  const value = Deno.env.get(name);
  if (!value) throw new Error(`Missing server environment variable: ${name}`);
  return value;
}

function generatedPatientCode(): string {
  const alphabet = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
  const bytes = crypto.getRandomValues(new Uint8Array(6));
  const suffix = Array.from(bytes, (value) => alphabet[value % alphabet.length])
    .join("");
  return `SL-${new Date().getUTCFullYear()}-${suffix}`;
}

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (request.method !== "POST") {
    return jsonResponse({ code: "method_not_allowed" }, 405);
  }

  let input: CreatePatientInput;
  try {
    input = parseCreatePatientInput(await request.json());
  } catch (error) {
    return jsonResponse(
      {
        code: "invalid_input",
        message: error instanceof Error ? error.message : "Invalid request.",
      },
      400,
    );
  }

  const authorization = request.headers.get("Authorization");
  const accessToken = authorization?.match(/^Bearer\s+(.+)$/i)?.[1];
  if (!accessToken) {
    return jsonResponse({ code: "authentication_required" }, 401);
  }

  try {
    const supabaseUrl = requiredEnvironment("SUPABASE_URL");
    const anonKey = requiredEnvironment("SUPABASE_ANON_KEY");
    const serviceRoleKey = requiredEnvironment("SUPABASE_SERVICE_ROLE_KEY");

    const callerClient = createClient(supabaseUrl, anonKey, {
      global: { headers: { Authorization: authorization } },
      auth: { persistSession: false, autoRefreshToken: false },
    });
    const {
      data: { user: caller },
      error: callerError,
    } = await callerClient.auth.getUser(accessToken);
    if (callerError || !caller) {
      return jsonResponse({ code: "authentication_required" }, 401);
    }

    const { data: role, error: roleError } = await callerClient
      .from("user_roles")
      .select("role")
      .eq("user_id", caller.id)
      .eq("role", "super_admin")
      .maybeSingle();
    if (roleError || !role) {
      return jsonResponse({ code: "forbidden" }, 403);
    }

    const adminClient = createClient(supabaseUrl, serviceRoleKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    });

    const { data: previousOperation } = await adminClient
      .from("admin_audit_logs")
      .select("entity_id")
      .eq("actor_user_id", caller.id)
      .eq("action", "patient.created")
      .eq("request_id", input.requestId)
      .maybeSingle();
    if (previousOperation?.entity_id) {
      const { data: patient } = await adminClient
        .from("patients")
        .select(
          "id,user_id,patient_code,full_name,phone,status,created_at",
        )
        .eq("id", previousOperation.entity_id)
        .single();
      if (patient) return jsonResponse({ patient });
    }

    const { data: authData, error: authError } = await adminClient.auth.admin
      .createUser({
        email: createInternalPatientEmail(),
        phone: input.phone,
        password: input.temporaryPassword,
        email_confirm: true,
        phone_confirm: true,
        user_metadata: {
          full_name: input.fullName,
          patient_phone: input.phone,
        },
      });
    if (authError || !authData.user) {
      const duplicate = authError?.status === 422;
      return jsonResponse(
        {
          code: duplicate ? "patient_account_exists" : "patient_create_failed",
          message: duplicate
            ? "An account already uses this phone number."
            : "The patient account could not be created. Please try again.",
        },
        duplicate ? 409 : 503,
      );
    }

    const patientUserId = authData.user.id;
    let createdPatient: PatientRecord | null = null;
    let lastErrorCode: string | undefined;
    const attempts = input.patientCode ? 1 : 4;
    for (let attempt = 0; attempt < attempts; attempt += 1) {
      const patientCode = input.patientCode ?? generatedPatientCode();
      const { data, error } = await adminClient.rpc(
        "finalize_patient_provisioning",
        {
          p_actor_user_id: caller.id,
          p_patient_user_id: patientUserId,
          p_full_name: input.fullName,
          p_phone: input.phone,
          p_patient_code: patientCode,
          p_request_id: input.requestId,
        },
      );
      if (!error && data) {
        createdPatient = data as PatientRecord;
        break;
      }
      lastErrorCode = error?.code;
      if (input.patientCode || lastErrorCode !== "23505") break;
    }

    if (createdPatient) {
      if (createdPatient.user_id !== patientUserId) {
        // A concurrent retry completed first; remove this unused Auth account.
        await adminClient.auth.admin.deleteUser(patientUserId);
        return jsonResponse({ patient: createdPatient });
      }
      return jsonResponse({ patient: createdPatient }, 201);
    }

    // Database finalization is transactional, so only the Auth account needs
    // compensation when it fails.
    await adminClient.auth.admin.deleteUser(patientUserId);
    const duplicateCode = input.patientCode && lastErrorCode === "23505";
    return jsonResponse(
      {
        code: duplicateCode ? "patient_code_exists" : "patient_create_failed",
        message: duplicateCode
          ? "This patient ID is already in use."
          : "The patient account could not be created. Please try again.",
      },
      duplicateCode ? 409 : 503,
    );
  } catch {
    return jsonResponse(
      {
        code: "service_unavailable",
        message: "Patient creation is temporarily unavailable.",
      },
      503,
    );
  }
});
