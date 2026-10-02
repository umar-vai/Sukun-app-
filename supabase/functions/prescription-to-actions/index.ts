import { createClient, type SupabaseClient } from "@supabase/supabase-js";
import { AiRouter, type GeminiKeySlot } from "./ai/ai-router.ts";
import { RestGeminiClient } from "./ai/gemini-client.ts";
import { SupabaseSlotHealthStore } from "./ai/supabase-health-store.ts";
import {
  type GenerateActionsInput,
  parseGenerateActionsInput,
} from "./validation.ts";

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

  let input: GenerateActionsInput;
  let adminClient: SupabaseClient | null = null;
  let requestStarted = false;
  try {
    input = parseGenerateActionsInput(await request.json());
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
      global: { headers: { Authorization: authorization } },
      auth: { persistSession: false, autoRefreshToken: false },
    });
    const { data: { user }, error: userError } = await callerClient.auth
      .getUser(
        accessToken,
      );
    if (userError || !user) {
      return jsonResponse({ code: "authentication_required" }, 401);
    }
    const { data: role } = await callerClient.from("user_roles").select("role")
      .eq("user_id", user.id).eq("role", "super_admin").maybeSingle();
    if (!role) return jsonResponse({ code: "forbidden" }, 403);

    const { data: plan } = await callerClient.from("care_plans")
      .select("id,prescription_id,status").eq("id", input.carePlanId)
      .maybeSingle();
    if (
      !plan || plan.status !== "draft" ||
      plan.prescription_id !== input.prescriptionId
    ) {
      return jsonResponse({
        code: "invalid_plan",
        message: "Select a draft plan linked to this prescription.",
      }, 400);
    }
    const { data: prescription } = await callerClient.from("prescriptions")
      .select("id,raw_text").eq("id", input.prescriptionId).maybeSingle();
    if (!prescription) {
      return jsonResponse({ code: "prescription_not_found" }, 404);
    }

    adminClient = createClient(supabaseUrl, serviceRoleKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    });
    const { data: existing } = await adminClient
      .from("ai_generation_requests")
      .select("requested_by,status,normalized_result")
      .eq("request_id", input.requestId).maybeSingle();
    if (existing) {
      if (existing.requested_by !== user.id) {
        return jsonResponse({ code: "request_conflict" }, 409);
      }
      if (existing.status === "processing") {
        return jsonResponse({
          code: "request_processing",
          message: "Action generation is already in progress.",
        }, 409);
      }
      return jsonResponse(existing.normalized_result);
    }

    const { error: insertError } = await adminClient
      .from("ai_generation_requests").insert({
        request_id: input.requestId,
        care_plan_id: input.carePlanId,
        prescription_id: input.prescriptionId,
        requested_by: user.id,
      });
    if (insertError) return jsonResponse({ code: "request_conflict" }, 409);
    requestStarted = true;

    const slots = configuredSlots();
    const router = new AiRouter(
      slots,
      new RestGeminiClient(),
      new SupabaseSlotHealthStore(adminClient),
      {
        model: Deno.env.get("GEMINI_MODEL") ?? "gemini-3.8-flash",
        timeoutMs: positiveInteger("AI_REQUEST_TIMEOUT_MS", 25000),
        cooldownMs: positiveInteger("AI_KEY_COOLDOWN_SECONDS", 3600) * 1000,
        maxRetryPerKey: nonnegativeInteger("AI_MAX_RETRY_PER_KEY", 1),
        log: (event) => console.log(JSON.stringify(event)),
      },
    );
    const result = slots.length === 0
      ? {
        status: "manual_required" as const,
        actions: [] as [],
        message:
          "Automatic action generation is temporarily unavailable. You can continue manually.",
      }
      : await router.generate(prescription.raw_text, input.requestId);
    const response = { request_id: input.requestId, ...result };
    await adminClient.from("ai_generation_requests").update({
      status: result.status === "generated" ? "succeeded" : "manual_required",
      normalized_result: response,
      updated_at: new Date().toISOString(),
    }).eq("request_id", input.requestId);
    return jsonResponse(response);
  } catch {
    const fallback = {
      request_id: input.requestId,
      status: "manual_required",
      actions: [] as [],
      message:
        "Automatic action generation is temporarily unavailable. You can continue manually.",
    };
    if (adminClient && requestStarted) {
      await adminClient.from("ai_generation_requests").update({
        status: "manual_required",
        normalized_result: fallback,
        updated_at: new Date().toISOString(),
      }).eq("request_id", input.requestId);
    }
    return jsonResponse(fallback);
  }
});

function configuredSlots(): GeminiKeySlot[] {
  const slots: GeminiKeySlot[] = [];
  for (const id of [1, 2, 3, 4] as const) {
    const apiKey = Deno.env.get(`GEMINI_API_KEY_${id}`)?.trim();
    if (!apiKey) continue;
    slots.push({
      id,
      apiKey,
      // Missing scope information is conservatively treated as shared quota.
      quotaScope: Deno.env.get(`GEMINI_QUOTA_SCOPE_${id}`)?.trim() ||
        "unverified-shared-quota",
    });
  }
  return slots;
}

function positiveInteger(name: string, fallback: number): number {
  const parsed = Number(Deno.env.get(name));
  return Number.isInteger(parsed) && parsed > 0 ? parsed : fallback;
}

function nonnegativeInteger(name: string, fallback: number): number {
  const parsed = Number(Deno.env.get(name));
  return Number.isInteger(parsed) && parsed >= 0 ? parsed : fallback;
}
