import { createClient } from "@supabase/supabase-js";
import { parseChangePasswordInput } from "./validation.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
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
  if (request.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (request.method !== "POST") return response({ code: "method_not_allowed" }, 405);

  const authorization = request.headers.get("Authorization");
  const accessToken = authorization?.match(/^Bearer\s+(.+)$/i)?.[1];
  if (!accessToken) return response({ code: "authentication_required" }, 401);

  let input;
  try {
    input = parseChangePasswordInput(await request.json());
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
    const callerClient = createClient(supabaseUrl, anonKey, {
      global: { headers: { Authorization: authorization! } },
      auth: { persistSession: false, autoRefreshToken: false },
    });
    const { data: userData, error: userError } = await callerClient.auth.getUser(accessToken);
    if (userError || !userData.user) return response({ code: "authentication_required" }, 401);

    const { data: patient } = await callerClient
      .from("patients")
      .select("id")
      .eq("user_id", userData.user.id)
      .eq("status", "active")
      .maybeSingle();
    if (!patient) return response({ code: "forbidden" }, 403);

    const authResponse = await fetch(`${supabaseUrl}/auth/v1/user`, {
      method: "PUT",
      headers: {
        Authorization: authorization!,
        apikey: anonKey,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        password: input.newPassword,
        current_password: input.currentPassword,
      }),
    });
    if (!authResponse.ok) {
      return response({
        code: "invalid_credentials",
        message: "The temporary password is incorrect or the new password was not accepted.",
      }, 400);
    }

    const adminClient = createClient(supabaseUrl, serviceRoleKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    });
    const { error: profileError } = await adminClient
      .from("profiles")
      .update({ requires_credential_change: false })
      .eq("id", userData.user.id);
    if (profileError) {
      return response({
        code: "credential_update_incomplete",
        message: "Password changed, but setup could not finish. Sign in with the new password and try again.",
      }, 503);
    }
    return response({ changed: true });
  } catch {
    return response({
      code: "service_unavailable",
      message: "Password change is temporarily unavailable. Please try again.",
    }, 503);
  }
});
