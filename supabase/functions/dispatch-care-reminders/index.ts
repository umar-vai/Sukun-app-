import { createClient } from "@supabase/supabase-js";
import {
  buildWebCareReminderMessage,
  createFirebaseAccessToken,
  parseServiceAccount,
  sendFirebaseMessage,
} from "../send-notification/firebase_client.ts";

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      "Content-Type": "application/json",
      "Cache-Control": "no-store",
    },
  });
}

async function authorized(request: Request): Promise<boolean> {
  const secret = Deno.env.get("CARE_REMINDER_DISPATCH_TOKEN");
  const supplied = request.headers.get("X-Sukun-Cron-Token");
  if (!secret || secret.length < 32 || !supplied) return false;
  const digest = async (input: string) =>
    new Uint8Array(
      await crypto.subtle.digest(
        "SHA-256",
        new TextEncoder().encode(input),
      ),
    );
  const a = await digest(secret);
  const b = await digest(supplied);
  return a.length === b.length && a.reduce(
        (difference, byte, index) => difference | (byte ^ b[index]),
        0,
      ) === 0;
}

type ClaimedReminder = {
  event_id: string;
  task_id: string;
  push_token: string;
};

Deno.serve(async (request) => {
  if (request.method !== "POST") {
    return json({ code: "method_not_allowed" }, 405);
  }
  if (!await authorized(request)) return json({ code: "unauthorized" }, 401);

  // Fail closed before claiming events. No role token or Firebase credentials
  // may be supplied by the browser or written into a public Pages artifact.
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const rawFirebase = Deno.env.get("FIREBASE_SERVICE_ACCOUNT_JSON");
  if (!serviceKey || !supabaseUrl || !rawFirebase) {
    return json({ code: "delivery_not_configured" }, 503);
  }

  try {
    const account = parseServiceAccount(rawFirebase);
    if (Deno.env.get("FIREBASE_PROJECT_ID") !== account.projectId) {
      return json({ code: "firebase_project_mismatch" }, 503);
    }
    const firebaseAccessToken = await createFirebaseAccessToken(account);
    const supabase = createClient(supabaseUrl, serviceKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    });
    const { data: claimed, error } = await supabase.rpc(
      "claim_due_web_care_reminders",
      { p_batch_size: 50 },
    );
    if (error) throw new Error("Reminder claim unavailable.");

    let sent = 0;
    let failed = 0;
    for (const event of (claimed ?? []) as ClaimedReminder[]) {
      let delivered = false;
      let invalidToken = false;
      let messageId: string | undefined;
      try {
        const result = await sendFirebaseMessage(
          account,
          firebaseAccessToken,
          buildWebCareReminderMessage(event.push_token, event.task_id),
        );
        delivered = result.ok;
        invalidToken = result.invalidToken;
        messageId = result.messageId;
      } catch {
        delivered = false;
      }
      const { error: updateError } = await supabase.from("notification_events")
        .update({
          status: delivered ? "sent" : "failed",
          provider_message_id: messageId ?? null,
        }).eq("id", event.event_id);
      if (updateError) throw new Error("Reminder status update failed.");
      if (delivered) sent++;
      else failed++;
      if (invalidToken) {
        await supabase.from("notification_devices")
          .update({ is_active: false })
          .eq("push_token", event.push_token);
      }
    }
    // Aggregate counters only. Never return prescription, device, token,
    // task identifiers, or protected records in this endpoint response.
    return json({ status: "processed", sent, failed });
  } catch {
    return json({ code: "reminder_dispatch_unavailable" }, 503);
  }
});
