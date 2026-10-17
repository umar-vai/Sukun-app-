import { createClient } from "@supabase/supabase-js";
import {
  createFirebaseAccessToken,
  parseServiceAccount,
} from "../send-notification/firebase_client.ts";

type ClaimedNotice = {
  job_id: string;
  notice_id: string;
  notice_title: string;
};

function response(body: unknown, status = 200): Response {
  return Response.json(body, {
    status,
    headers: { "Cache-Control": "no-store" },
  });
}

async function validCronToken(request: Request): Promise<boolean> {
  const secret = Deno.env.get("SUKUN_UNIVERSAL_BROADCAST_CRON_TOKEN");
  const supplied = request.headers.get("X-Sukun-Universal-Cron");
  if (!secret || secret.length < 32 || !supplied) return false;
  const digest = (value: string) =>
    crypto.subtle.digest("SHA-256", new TextEncoder().encode(value));
  const a = new Uint8Array(await digest(secret));
  const b = new Uint8Array(await digest(supplied));
  return a.length === b.length &&
    a.reduce((diff, byte, i) => diff | (byte ^ b[i]), 0) === 0;
}

async function sendPublicNotice(
  firebaseProjectId: string,
  firebaseAccessToken: string,
  notice: ClaimedNotice,
): Promise<{ ok: boolean; messageId: string | null }> {
  if (
    !/^[0-9a-f-]{36}$/i.test(notice.notice_id) ||
    !notice.notice_title.trim()
  ) throw new Error("Invalid queued public notice.");

  // FCM topic is a public-only channel. Do not include sensitive clinical
  // content, uploaded image URLs, internal routes, arbitrary URLs or tokens.
  const result = await fetch(
    "https://fcm.googleapis.com/v1/projects/" +
      encodeURIComponent(firebaseProjectId) + "/messages:send",
    {
      method: "POST",
      headers: {
        Authorization: "Bearer " + firebaseAccessToken,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        message: {
          topic: "sukun_public_notices_v1",
          notification: {
            title: "সুকুন লাইফ • গুরুত্বপূর্ণ নোটিশ",
            body: notice.notice_title.slice(0, 110),
          },
          data: {
            type: "universal_announcement",
            announcement_id: notice.notice_id,
          },
          android: {
            priority: "high",
            notification: {
              channel_id: "care_updates",
              sound: "default",
            },
          },
          apns: {
            payload: { aps: { sound: "default" } },
          },
        },
      }),
    },
  );
  if (!result.ok) return { ok: false, messageId: null };
  const body = await result.json() as { name?: unknown };
  return {
    ok: true,
    messageId: typeof body.name === "string" ? body.name : null,
  };
}

Deno.serve(async (request) => {
  if (request.method !== "POST") {
    return response({ code: "method_not_allowed" }, 405);
  }
  if (!await validCronToken(request)) {
    return response({ code: "unauthorized" }, 401);
  }
  if (Deno.env.get("SUKUN_UNIVERSAL_PUSH_RELEASE_READY") !== "true") {
    return response({ code: "release_gate_closed" }, 503);
  }
  const key = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  const url = Deno.env.get("SUPABASE_URL");
  const rawFirebase = Deno.env.get("FIREBASE_SERVICE_ACCOUNT_JSON");
  if (!key || !url || !rawFirebase) {
    return response({ code: "delivery_not_configured" }, 503);
  }

  try {
    const account = parseServiceAccount(rawFirebase);
    if (account.projectId !== Deno.env.get("FIREBASE_PROJECT_ID")) {
      return response({ code: "firebase_project_mismatch" }, 503);
    }
    const token = await createFirebaseAccessToken(account);
    const supabase = createClient(url, key, {
      auth: { persistSession: false, autoRefreshToken: false },
    });
    const { data: claimed, error } = await supabase.rpc(
      "claim_universal_announcement_batch",
      { p_batch_size: 10 },
    );
    if (error) throw new Error("Notice claim rejected.");

    let accepted = 0;
    let failed = 0;
    for (const notice of (claimed ?? []) as ClaimedNotice[]) {
      let providerAccepted = false;
      let messageId: string | null = null;
      try {
        const result = await sendPublicNotice(
          account.projectId,
          token,
          notice,
        );
        providerAccepted = result.ok;
        messageId = result.messageId;
      } catch {
        providerAccepted = false;
      }
      const { data: completed, error: completeError } = await supabase.rpc(
        "complete_universal_announcement_broadcast",
        {
          p_job_id: notice.job_id,
          p_delivered_to_provider: providerAccepted,
          p_provider_message_id: messageId,
        },
      );
      if (completeError || completed !== true) {
        throw new Error("Notice acknowledgement failed.");
      }
      if (providerAccepted) accepted++;
      else failed++;
    }
    // Provider acceptance is NOT per-device delivery or a recipient count.
    return response({ status: "processed", accepted, failed });
  } catch {
    return response({ code: "broadcast_unavailable" }, 503);
  }
});
