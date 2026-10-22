import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "@supabase/supabase-js";
import { isApprovedAudioUrl } from "./approved.ts";

// Authenticated downloads ONLY. This endpoint is not a public CORS proxy.
// The publisher does not send browser CORS headers; we fetch server-to-server
// only when the signed-in member can see a published, public CMS recording.
const allowedOrigin = "https://app.sukunlife.com";
const maxMediaBytes = 100 * 1024 * 1024;
const headerNames = "authorization, apikey, content-type";
const cors = {
  "Access-Control-Allow-Origin": allowedOrigin,
  "Access-Control-Allow-Methods": "GET, OPTIONS",
  "Access-Control-Allow-Headers": headerNames,
  "Vary": "Origin",
};
const secured = {
  "Cache-Control": "no-store",
  "X-Content-Type-Options": "nosniff",
  "Referrer-Policy": "no-referrer",
};
function response(status: number, code: string, allowed: boolean): Response {
  return new Response(JSON.stringify({ code }), {
    status,
    headers: {
      "Content-Type": "application/json; charset=utf-8",
      ...secured,
      ...(allowed ? cors : {}),
    },
  });
}
function trustedRequestOrigin(request: Request): boolean {
  // Require exact production Pages Origin; no wildcard/no localhost.
  return request.headers.get("Origin") === allowedOrigin;
}
Deno.serve(async (request) => {
  const validOrigin = trustedRequestOrigin(request);
  if (!validOrigin) return response(403, "untrusted_origin", false);
  if (request.method === "OPTIONS") {
    return new Response(null, {
      status: 204,
      headers: { ...cors, ...secured },
    });
  }
  if (request.method !== "GET") {
    return response(405, "method_not_allowed", true);
  }
  if (request.headers.has("Range")) {
    return response(416, "range_not_supported", true);
  }
  const id = new URL(request.url).searchParams.get("id") || "";
  if (!/^[0-9a-f-]{36}$/i.test(id)) {
    return response(400, "invalid_resource", true);
  }
  const authorization = request.headers.get("Authorization") ?? "";
  if (!/^Bearer [^\s]+$/.test(authorization)) {
    return response(401, "login_required", true);
  }
  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const publishableKey = Deno.env.get("SUPABASE_ANON_KEY");
  if (!supabaseUrl || !publishableKey) {
    return response(503, "gateway_unconfigured", true);
  }
  const token = authorization.slice(7);
  const client = createClient(supabaseUrl, publishableKey, {
    global: { headers: { Authorization: authorization } },
    auth: { persistSession: false, autoRefreshToken: false },
  });
  try {
    // Verify against GoTrue, not caller-supplied metadata or an unchecked JWT.
    const { data: identity, error: authError } = await client.auth.getUser(
      token,
    );
    if (authError || !identity.user?.id || identity.user.is_anonymous) {
      return response(401, "login_required", true);
    }
    const { data: resource, error: cmsError } = await client
      .from("content_items")
      .select("id,status,visibility,type,media_url")
      .eq("id", id)
      .eq("status", "published")
      .eq("visibility", "public")
      .eq("type", "audio")
      .maybeSingle();
    if (cmsError || !resource || !isApprovedAudioUrl(resource.media_url)) {
      return response(404, "approved_media_not_found", true);
    }
    // No request-controlled hostname, path, redirect, cookies or credentials.
    const upstream = await fetch(resource.media_url, {
      method: "GET",
      redirect: "manual",
      headers: { "Accept": "audio/mpeg" },
      signal: AbortSignal.timeout(110_000),
    });
    if (upstream.status !== 200 || !upstream.body) {
      upstream.body?.cancel().catch(() => {});
      return response(502, "publisher_unavailable", true);
    }
    const mediaType = upstream.headers.get("content-type")?.toLowerCase() ?? "";
    const contentLength = Number(upstream.headers.get("content-length"));
    if (
      !Number.isSafeInteger(contentLength) ||
      contentLength < 4 || contentLength > maxMediaBytes ||
      !(mediaType.includes("audio/") ||
        mediaType.includes("application/octet-stream"))
    ) {
      upstream.body.cancel().catch(() => {});
      return response(422, "invalid_or_oversized_media", true);
    }
    // An atomic PostgreSQL reservation enforces both per-member and *global*
    // UTC-day budgets, so a stolen JWT or bot cannot trigger unbounded egress.
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    if (!serviceKey) {
      upstream.body.cancel().catch(() => {});
      return response(503, "gateway_budget_unconfigured", true);
    }
    // Service key stays inside Supabase Edge. Do NOT use user JWT for this
    // RPC: otherwise any member could exhaust the whole project's quota.
    const trustedBudgetClient = createClient(supabaseUrl, serviceKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    });
    const { data: reserved, error: quotaError } = await trustedBudgetClient.rpc(
      "reserve_approved_audio_download",
      { p_user_id: identity.user.id, p_bytes: contentLength },
    );
    if (quotaError || reserved !== true) {
      upstream.body.cancel().catch(() => {});
      return response(429, "daily_media_budget_exhausted", true);
    }
    return new Response(upstream.body, {
      status: 200,
      headers: {
        ...cors,
        ...secured,
        "Content-Type": "audio/mpeg",
        "Content-Length": String(contentLength),
        "Content-Disposition": "attachment",
      },
    });
  } catch (_) {
    // Do not log CMS IDs, JWT, request URLs, filenames or patient metadata.
    return response(502, "media_gateway_unavailable", true);
  }
});
