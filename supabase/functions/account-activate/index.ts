// Public one-time account activation. The patient opens the WhatsApp link,
// chooses a permanent password, then signs in normally with their patient ID.
//
// POST { token, new_password } -> { patient_code }
// Always answers with one generic error for a bad, used, revoked or expired
// link. Per IP rate limited with the same server side limiter as sign in.
// STATUS: type checked and unit tested only; not exercised on a deployed
// runtime, and WhatsApp delivery is not yet tested with a real account.
import { createClient } from "@supabase/supabase-js";
import { validateNewPassword, validateToken } from "./password.ts";
import { hashedLimiterKey, trustedClientIp } from "./rate-limit.ts";

const MAX_BODY_BYTES = 2048;
const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...cors,
      "Content-Type": "application/json",
      "Cache-Control": "no-store",
    },
  });
}

async function sha256Hex(value: string): Promise<string> {
  const digest = await crypto.subtle.digest(
    "SHA-256",
    new TextEncoder().encode(value),
  );
  return [...new Uint8Array(digest)].map((n) => n.toString(16).padStart(2, "0"))
    .join("");
}

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: cors });
  }
  if (request.method !== "POST") {
    return json({ code: "method_not_allowed" }, 405);
  }

  let input: { token: string; password: string };
  try {
    const text = await request.text();
    if (new TextEncoder().encode(text).byteLength > MAX_BODY_BYTES) {
      return json({ code: "request_too_large" }, 413);
    }
    const body = JSON.parse(text);
    const token = validateToken(body?.token);
    const password = validateNewPassword(body?.new_password);
    if (!token || !password) return json({ code: "invalid_input" }, 400);
    input = { token, password };
  } catch {
    return json({ code: "invalid_input" }, 400);
  }

  const invalidLink = () =>
    json({
      code: "invalid_or_expired_link",
      message: "This link is no longer valid. Ask Sukun Life for a new one.",
    }, 400);

  try {
    const url = Deno.env.get("SUPABASE_URL");
    const key = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    const secret = Deno.env.get("SIGN_IN_RATE_LIMIT_SECRET");
    if (!url || !key || !secret) {
      return json({ code: "service_unavailable" }, 503);
    }
    const db = createClient(url, key, {
      auth: { persistSession: false, autoRefreshToken: false },
    });

    // Fail closed when the limiter is unavailable.
    const ipHash = await hashedLimiterKey(
      secret,
      "ip",
      trustedClientIp(request),
    );
    const identityHash = await hashedLimiterKey(
      secret,
      "identity",
      "activation:" + await sha256Hex(trustedClientIp(request)),
    );
    const { data: allowed, error: limitError } = await db.rpc(
      "check_patient_login_rate_limit",
      { p_ip_hash: ipHash, p_identity_hash: identityHash },
    );
    if (limitError) return json({ code: "service_unavailable" }, 503);
    if (allowed !== true) return json({ code: "too_many_attempts" }, 429);

    const { data: spent, error: consumeError } = await db.rpc(
      "integration_consume_activation",
      { p_token_hash: await sha256Hex(input.token) },
    );
    if (consumeError) return json({ code: "service_unavailable" }, 503);
    if (!spent) return invalidLink();

    const { error: passwordError } = await db.auth.admin.updateUserById(
      spent.user_id,
      { password: input.password },
    );
    if (passwordError) {
      // Do not burn the link when the password could not be saved.
      await db.rpc("integration_reopen_activation", {
        p_activation_id: spent.activation_id,
      });
      return json({ code: "service_unavailable" }, 503);
    }
    await db.rpc("integration_complete_activation", {
      p_user_id: spent.user_id,
    });
    return json({ patient_code: spent.patient_code });
  } catch {
    return json({ code: "service_unavailable" }, 503);
  }
});
