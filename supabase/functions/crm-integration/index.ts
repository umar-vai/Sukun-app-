// CRM/ERP integration gateway (SukunLife side).
//
// Routes (all under /functions/v1/crm-integration):
//   GET  /templates            versioned official template catalog (mirror)
//   POST /patients/link        map a SukunLife profile to CRM ids (+ family)
//   POST /patients/provision   create the patient/login if missing and send the
//                              one-time temporary credential (safe to repeat)
//   POST /prescriptions        final prescription event (issue/revise/cancel)
//   GET  /progress             authoritative adherence summary for one patient
//   POST /outbox/dispatch      push queued progress events to the CRM
//                              (called by a scheduler, not by the CRM)
//
// Every CRM route requires a valid HMAC signature (crm_auth.ts). The Supabase
// service-role key stays inside this function. Verify JWT is OFF in
// config.toml because callers are a backend, not a signed-in user.
//
// STATUS: contract-tested against the SQL layer locally; not yet exercised
// against the real CRM or a deployed Edge runtime.
import { createClient, type SupabaseClient } from "@supabase/supabase-js";
import { provisionPatient } from "./provision.ts";
import {
  parseKeyMap,
  signRequest,
  timingSafeEqual,
  verifyCrmRequest,
} from "./crm_auth.ts";

const MAX_BODY_BYTES = 1_000_000;

function json(body: unknown, status = 200, extra: Record<string, string> = {}) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      "Content-Type": "application/json",
      "Cache-Control": "no-store",
      ...extra,
    },
  });
}

function env(name: string): string {
  const value = Deno.env.get(name);
  if (!value) throw new Error(`Missing server environment variable: ${name}`);
  return value;
}

async function readBody(request: Request): Promise<string> {
  const claimed = Number(request.headers.get("content-length") ?? "0");
  if (Number.isFinite(claimed) && claimed > MAX_BODY_BYTES) {
    throw new Error("request_too_large");
  }
  const text = await request.text();
  if (new TextEncoder().encode(text).byteLength > MAX_BODY_BYTES) {
    throw new Error("request_too_large");
  }
  return text;
}

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const DATE = /^\d{4}-\d{2}-\d{2}$/;

function statusForResult(result: { status: string; code?: string }): number {
  if (result.status === "applied") return 200;
  if (result.status === "stale") return 409;
  if (result.code === "event_id_reuse_conflict") return 409;
  if (result.code === "family_mismatch") return 409;
  return 422;
}

Deno.serve(async (request) => {
  const url = new URL(request.url);
  const route = url.pathname.replace(/^.*\/crm-integration/, "") || "/";

  let rawBody: string;
  try {
    rawBody = request.method === "GET" ? "" : await readBody(request);
  } catch {
    return json({ code: "request_too_large" }, 413);
  }

  let supabase;
  try {
    supabase = createClient(
      env("SUPABASE_URL"),
      env("SUPABASE_SERVICE_ROLE_KEY"),
      {
        auth: { persistSession: false, autoRefreshToken: false },
      },
    );
  } catch {
    return json({ code: "server_not_configured" }, 503);
  }

  // The dispatch route is called by our own scheduler with a separate secret.
  if (route === "/outbox/dispatch" && request.method === "POST") {
    const presented = (request.headers.get("authorization") ?? "").replace(
      /^Bearer /i,
      "",
    );
    const expected = Deno.env.get("CRM_DISPATCH_SECRET") ?? "";
    if (expected.length < 32 || !timingSafeEqual(presented, expected)) {
      return json({ code: "unauthorized" }, 401);
    }
    return await dispatchOutbox(supabase);
  }

  // Everything else is the CRM backend: verify the signature first.
  const keys = parseKeyMap(Deno.env.get("CRM_INTEGRATION_KEYS"));
  if (keys.size === 0) return json({ code: "server_not_configured" }, 503);
  const auth = await verifyCrmRequest({
    method: request.method,
    pathAndQuery: url.pathname + url.search,
    body: rawBody,
    headers: request.headers,
    keys,
    nowSeconds: Math.floor(Date.now() / 1000),
  });
  if (!auth.ok) {
    // Same generic answer for every failure: no oracle for attackers.
    console.warn("crm_auth_rejected", auth.reason);
    return json({ code: "unauthorized" }, 401);
  }

  const actorUserId = Deno.env.get("CRM_INTEGRATION_ACTOR_USER_ID") ?? "";
  if (!UUID.test(actorUserId)) {
    return json({ code: "server_not_configured" }, 503);
  }

  try {
    if (route === "/templates" && request.method === "GET") {
      const updatedSince = url.searchParams.get("updated_since");
      const afterId = url.searchParams.get("after_id");
      const limit = Number(url.searchParams.get("limit") ?? "100");
      if (updatedSince && Number.isNaN(Date.parse(updatedSince))) {
        return json({ code: "invalid_request" }, 400);
      }
      const { data, error } = await supabase.rpc(
        "integration_export_template_catalog",
        {
          p_updated_since: updatedSince,
          p_after_id: afterId,
          p_limit: Number.isFinite(limit) ? limit : 100,
        },
      );
      if (error) throw error;
      const etag = `"${data.catalog_version}:${updatedSince ?? ""}:${
        afterId ?? ""
      }:${limit}"`;
      if (request.headers.get("if-none-match") === etag) {
        return new Response(null, { status: 304, headers: { ETag: etag } });
      }
      return json(data, 200, { ETag: etag });
    }

    if (route === "/patients/link" && request.method === "POST") {
      const body = JSON.parse(rawBody);
      if (
        !UUID.test(body.sukun_patient_id ?? "") ||
        typeof body.crm_patient_id !== "string"
      ) {
        return json({ code: "invalid_request" }, 400);
      }
      const { data, error } = await supabase.rpc("integration_link_patient", {
        p_actor_user_id: actorUserId,
        p_patient_id: body.sukun_patient_id,
        p_crm_patient_id: body.crm_patient_id,
        p_crm_customer_id: body.crm_customer_id ?? null,
        p_crm_family_id: body.crm_family_id ?? null,
        p_relationship_label: body.relationship_label ?? null,
      });
      if (error) {
        // 23505 = identity conflict: report, never merge.
        if (error.code === "23505") {
          return json({ code: "identity_conflict" }, 409);
        }
        if (error.code === "P0002") {
          return json({ code: "patient_not_found" }, 404);
        }
        throw error;
      }
      return json(data);
    }

    if (route === "/patients/provision" && request.method === "POST") {
      let body;
      try {
        body = JSON.parse(rawBody);
      } catch {
        return json({ code: "invalid_json" }, 400);
      }
      const result = await provisionPatient(supabase, actorUserId, body);
      return json(result.body, result.status);
    }

    if (route === "/prescriptions" && request.method === "POST") {
      let event;
      try {
        event = JSON.parse(rawBody);
      } catch {
        return json({ code: "invalid_json" }, 400);
      }
      if (typeof event !== "object" || event === null || Array.isArray(event)) {
        return json({ code: "invalid_request" }, 400);
      }
      const { data, error } = await supabase.rpc(
        "integration_apply_prescription_event",
        {
          p_actor_user_id: actorUserId,
          p_event: event,
        },
      );
      if (error) throw error;
      // The result never echoes prescription text; it holds ids and codes.
      return json(data, statusForResult(data));
    }

    if (route === "/progress" && request.method === "GET") {
      const crmPatientId = url.searchParams.get("crm_patient_id") ?? "";
      const from = url.searchParams.get("from") ?? "";
      const to = url.searchParams.get("to") ?? "";
      if (!crmPatientId || !DATE.test(from) || !DATE.test(to)) {
        return json({ code: "invalid_request" }, 400);
      }
      const { data, error } = await supabase.rpc(
        "integration_patient_progress",
        {
          p_crm_patient_id: crmPatientId,
          p_from: from,
          p_to: to,
        },
      );
      if (error) {
        if (error.code === "P0002") {
          return json({ code: "patient_not_found" }, 404);
        }
        if (error.code === "22023") return json({ code: "invalid_range" }, 400);
        throw error;
      }
      return json(data);
    }

    return json({ code: "not_found" }, 404);
  } catch (error) {
    // Never return database or provider detail to the caller.
    console.error(
      "crm_integration_failed",
      route,
      (error as { code?: string }).code ?? "unknown",
    );
    return json({ code: "internal_error" }, 500);
  }
});

async function dispatchOutbox(supabase: SupabaseClient) {
  const webhookUrl = Deno.env.get("CRM_PROGRESS_WEBHOOK_URL");
  const keyId = Deno.env.get("CRM_PROGRESS_WEBHOOK_KEY_ID");
  const secret = Deno.env.get("CRM_PROGRESS_WEBHOOK_SECRET");
  if (!webhookUrl || !keyId || !secret) {
    // CRM endpoint not configured yet: leave events queued, report it.
    return json({ code: "crm_webhook_not_configured", delivered: 0 }, 503);
  }
  const { data: rows, error } = await supabase.rpc("integration_claim_outbox", {
    p_limit: 50,
    p_lease_seconds: 300,
  });
  if (error) return json({ code: "internal_error" }, 500);

  let delivered = 0;
  let failed = 0;
  for (const row of rows ?? []) {
    const body = JSON.stringify(row.payload);
    const timestamp = String(Math.floor(Date.now() / 1000));
    const requestId = String(row.id);
    const target = new URL(webhookUrl);
    const signature = await signRequest({
      secret,
      timestamp,
      requestId,
      method: "POST",
      pathAndQuery: target.pathname + target.search,
      body,
    });
    try {
      const response = await fetch(webhookUrl, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-Sukun-Key-Id": keyId,
          "X-Sukun-Timestamp": timestamp,
          "X-Sukun-Request-Id": requestId,
          "X-Sukun-Signature": signature,
        },
        body,
        signal: AbortSignal.timeout(10_000),
      });
      if (response.ok) {
        await supabase.rpc("integration_ack_outbox", { p_ids: [row.id] });
        delivered += 1;
      } else {
        await supabase.rpc("integration_fail_outbox", {
          p_id: row.id,
          p_error: `crm_http_${response.status}`,
        });
        failed += 1;
      }
    } catch {
      await supabase.rpc("integration_fail_outbox", {
        p_id: row.id,
        p_error: "crm_unreachable",
      });
      failed += 1;
    }
  }
  return json({ delivered, failed });
}
