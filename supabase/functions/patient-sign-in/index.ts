import { createClient } from "@supabase/supabase-js";
import { parsePatientSignInInput } from "./validation.ts";
import { createInternalPatientEmail } from "./auth-identity.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function response(body: unknown, status = 200): Response {
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

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (request.method !== "POST") {
    return response({ code: "method_not_allowed" }, 405);
  }

  let input;
  try {
    input = parsePatientSignInInput(await request.json());
  } catch (error) {
    return response({
      code: "invalid_input",
      message: error instanceof Error ? error.message : "Invalid request.",
    }, 400);
  }

  try {
    const supabaseUrl = requiredEnvironment("SUPABASE_URL");
    const anonKey = requiredEnvironment("SUPABASE_ANON_KEY");
    const serviceRoleKey = requiredEnvironment("SUPABASE_SERVICE_ROLE_KEY");
    const adminClient = createClient(supabaseUrl, serviceRoleKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    });
    let patientQuery = adminClient
      .from("patients")
      .select("user_id,status")
      .eq("status", "active");
    patientQuery = input.identifierKind === "phone"
      ? patientQuery.eq("phone", input.identifier)
      : patientQuery.eq("patient_code", input.identifier);
    const { data: patient, error: patientError } = await patientQuery
      .maybeSingle();
    if (patientError || !patient?.user_id) {
      return response({
        code: "invalid_credentials",
        message: "Patient ID or password is incorrect.",
      }, 401);
    }

    const { data: authUserData, error: authUserError } = await adminClient.auth
      .admin.getUserById(patient.user_id);
    if (authUserError || !authUserData.user) {
      return response({
        code: "invalid_credentials",
        message: "Patient ID or password is incorrect.",
      }, 401);
    }

    let loginEmail = authUserData.user.email;
    if (!loginEmail) {
      const migrationEmail = createInternalPatientEmail(patient.user_id);
      const { data: migratedUserData, error: migrationError } =
        await adminClient
          .auth.admin.updateUserById(patient.user_id, {
            email: migrationEmail,
            email_confirm: true,
          });
      if (migrationError || !migratedUserData.user.email) {
        return response({
          code: "service_unavailable",
          message: "Sign in is temporarily unavailable. Please try again.",
        }, 503);
      }
      loginEmail = migratedUserData.user.email;
    }

    const authClient = createClient(supabaseUrl, anonKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    });
    const { data, error } = await authClient.auth.signInWithPassword({
      email: loginEmail,
      password: input.password,
    });
    if (error || !data.session || data.user.id !== patient.user_id) {
      return response({
        code: "invalid_credentials",
        message: "Patient ID or password is incorrect.",
      }, 401);
    }

    return response({
      refresh_token: data.session.refresh_token,
      expires_at: data.session.expires_at,
    });
  } catch {
    return response({
      code: "service_unavailable",
      message: "Sign in is temporarily unavailable. Please try again.",
    }, 503);
  }
});
