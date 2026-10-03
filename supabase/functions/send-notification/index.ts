import { createClient } from "@supabase/supabase-js";
import {
  buildPlanUpdatedMessage,
  createFirebaseAccessToken,
  parseServiceAccount,
  sendFirebaseMessage,
} from "./firebase_client.ts";
import { parsePlanUpdatedInput } from "./validation.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
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

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (request.method !== "POST") {
    return jsonResponse({ code: "method_not_allowed" }, 405);
  }

  let input;
  try {
    input = parsePlanUpdatedInput(await request.json());
  } catch (error) {
    return jsonResponse({
      code: "invalid_input",
      message: error instanceof Error ? error.message : "Invalid request.",
    }, 400);
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
      global: { headers: { Authorization: authorization! } },
      auth: { persistSession: false, autoRefreshToken: false },
    });
    const { data: { user: caller }, error: callerError } = await callerClient
      .auth.getUser(accessToken);
    if (callerError || !caller) {
      return jsonResponse({ code: "authentication_required" }, 401);
    }
    const { data: role } = await callerClient.from("user_roles").select("role")
      .eq("user_id", caller.id).eq("role", "super_admin").maybeSingle();
    if (!role) return jsonResponse({ code: "forbidden" }, 403);

    const adminClient = createClient(supabaseUrl, serviceRoleKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    });
    const { data: plan } = await adminClient.from("care_plans")
      .select("id,patient_id,status,version").eq("id", input.carePlanId)
      .eq("status", "active").maybeSingle();
    if (!plan) return jsonResponse({ code: "active_plan_not_found" }, 404);

    const rawServiceAccount = Deno.env.get("FIREBASE_SERVICE_ACCOUNT_JSON");
    if (!rawServiceAccount) {
      return jsonResponse(
        { status: "not_configured", sent: 0, failed: 0 },
        202,
      );
    }
    const account = parseServiceAccount(rawServiceAccount);
    const configuredProject = Deno.env.get("FIREBASE_PROJECT_ID");
    if (configuredProject && configuredProject !== account.projectId) {
      return jsonResponse(
        { status: "not_configured", sent: 0, failed: 0 },
        202,
      );
    }
    const firebaseToken = await createFirebaseAccessToken(account);
    const { data: devices, error: devicesError } = await adminClient
      .from("notification_devices")
      .select("id,push_token").eq("patient_id", plan.patient_id)
      .eq("is_active", true);
    if (devicesError) throw new Error("Device lookup failed.");

    let sent = 0;
    let failed = 0;
    for (const device of devices ?? []) {
      const { data: event, error: eventError } = await adminClient
        .from("notification_events").insert({
          patient_id: plan.patient_id,
          device_id: device.id,
          scheduled_at: new Date().toISOString(),
          notification_type: "plan_updated",
          status: "scheduled",
          request_id: input.requestId,
        }).select("id").maybeSingle();
      if (eventError?.code === "23505") continue;
      if (eventError || !event) {
        failed += 1;
        continue;
      }

      let result;
      try {
        result = await sendFirebaseMessage(
          account,
          firebaseToken,
          buildPlanUpdatedMessage(device.push_token, input.carePlanId),
        );
      } catch {
        result = { ok: false, invalidToken: false };
      }
      await adminClient.from("notification_events").update({
        status: result.ok ? "sent" : "failed",
        provider_message_id: result.messageId ?? null,
      }).eq("id", event.id);
      if (result.ok) sent += 1;
      else failed += 1;
      if (result.invalidToken) {
        await adminClient.from("notification_devices")
          .update({ is_active: false }).eq("id", device.id);
      }
    }

    await adminClient.from("admin_audit_logs").insert({
      actor_user_id: caller.id,
      action: "notification.plan_updated_sent",
      entity_type: "care_plan",
      entity_id: plan.id,
      patient_id: plan.patient_id,
      request_id: input.requestId,
      metadata: { plan_version: plan.version, sent, failed },
    });
    return jsonResponse({ status: "accepted", sent, failed });
  } catch {
    return jsonResponse({
      code: "notification_delivery_unavailable",
      message: "The plan was published, but delivery will be retried later.",
    }, 503);
  }
});
