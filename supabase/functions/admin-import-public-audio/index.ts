import { createClient } from "@supabase/supabase-js";
import {
  approvedAudioSource,
  AUDIO_BUCKET,
  boundedAudioBytes,
  MAX_AUDIO_BYTES,
  parseImportRequest,
} from "./validation.ts";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, apikey, x-client-info, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Cache-Control": "no-store",
};

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { ...cors, "Content-Type": "application/json; charset=utf-8" },
  });

function environment(name: string): string {
  const result = Deno.env.get(name);
  if (!result) throw new Error("missing_environment");
  return result;
}

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: cors });
  }
  if (request.method !== "POST") {
    return json({ code: "method_not_allowed" }, 405);
  }
  const authHeader = request.headers.get("Authorization");
  const token = authHeader?.match(/^Bearer\s+(.+)$/i)?.[1];
  if (!token) return json({ code: "authentication_required" }, 401);

  try {
    const url = environment("SUPABASE_URL");
    const anonKey = environment("SUPABASE_ANON_KEY");
    const serviceKey = environment("SUPABASE_SERVICE_ROLE_KEY");
    const callerClient = createClient(url, anonKey, {
      global: { headers: { Authorization: authHeader! } },
      auth: { persistSession: false, autoRefreshToken: false },
    });
    const auth = await callerClient.auth.getUser(token);
    if (auth.error || !auth.data.user) {
      return json({ code: "authentication_required" }, 401);
    }
    const callerId = auth.data.user.id;
    const role = await callerClient.from("user_roles")
      .select("role").eq("user_id", callerId)
      .eq("role", "super_admin").maybeSingle();
    if (role.error || !role.data) return json({ code: "forbidden" }, 403);

    let requestBody;
    try {
      requestBody = parseImportRequest(await request.json());
    } catch {
      return json({ code: "invalid_input_or_rights_not_confirmed" }, 400);
    }

    const admin = createClient(url, serviceKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    });
    const result = await admin.from("content_items")
      .select(
        "id,type,status,visibility,media_source_type,media_url,rights_note",
      )
      .eq("id", requestBody.contentItemId).maybeSingle();
    if (result.error || !result.data) {
      return json({ code: "resource_not_found" }, 404);
    }
    const item = result.data;
    if (
      item.type !== "audio" || item.visibility !== "public" ||
      item.media_source_type !== "direct_audio_url" ||
      !item.rights_note?.trim()
    ) {
      return json({ code: "not_an_approved_public_audio" }, 400);
    }
    const chosenSource = requestBody.sourceUrlOverride ??
      (typeof item.media_url === "string" ? item.media_url : "");
    // The alternative must still be on the exact licensed source hostname,
    // be selected by an authenticated super-admin, and be confirmed manually.
    // No URL redirects, localhost, or arbitrary remote servers are accepted.
    const originalUrl = approvedAudioSource(chosenSource);
    if (!originalUrl) {
      return json({ code: "source_host_not_authorized" }, 400);
    }
    // Only return a previous successful, matching licensed import. This keeps
    // retries idempotent and avoids repeatedly downloading large source files.
    const previous = await admin.from("audio_rehost_imports")
      .select("object_path,byte_size")
      .eq("content_item_id", item.id)
      .eq("original_url", originalUrl.toString())
      .order("created_at", { ascending: false }).limit(1).maybeSingle();
    if (previous.error) return json({ code: "audit_unavailable" }, 503);
    if (previous.data) {
      const { data } = admin.storage.from(AUDIO_BUCKET)
        .getPublicUrl(previous.data.object_path);
      return json({
        status: "previously_imported",
        publicUrl: data.publicUrl,
        originalUrl: originalUrl.toString(),
        byteSize: previous.data.byte_size,
      });
    }

    let audio: Uint8Array;
    try {
      // A HEAD preflight avoids downloading >45MiB media on Free staging,
      // but final streamed byte enforcement remains authoritative.
      try {
        const preflight = await fetch(originalUrl, {
          method: "HEAD",
          redirect: "error",
          signal: AbortSignal.timeout(12000),
          headers: { Accept: "audio/mpeg" },
        });
        if (preflight.ok) {
          const declared = Number(preflight.headers.get("content-length"));
          if (Number.isFinite(declared) && declared > MAX_AUDIO_BYTES) {
            return json({ code: "audio_too_large" }, 413);
          }
        }
      } catch {
        // HEAD is optional; boundedAudioBytes enforces the cap on GET.
      }
      const downloaded = await fetch(originalUrl, {
        method: "GET",
        redirect: "error",
        signal: AbortSignal.timeout(65000),
        headers: { Accept: "audio/mpeg" },
      });
      const mediaType = downloaded.headers.get("content-type") ?? "";
      if (
        !/^(audio\/(mpeg|mp3)|application\/octet-stream)(?:;|$)/i
          .test(mediaType)
      ) {
        await downloaded.body?.cancel();
        return json({ code: "not_an_mp3" }, 415);
      }
      audio = await boundedAudioBytes(downloaded);
    } catch (error) {
      const code = error instanceof Error && error.message === "audio_too_large"
        ? "audio_too_large"
        : "source_download_failed";
      return json({ code }, code === "audio_too_large" ? 413 : 502);
    }

    const hashArray = new Uint8Array(
      await crypto.subtle.digest("SHA-256", audio.buffer as ArrayBuffer),
    );
    const digest = Array.from(
      hashArray,
      (byte) => byte.toString(16).padStart(2, "0"),
    ).join("");
    const objectPath = `ruqyahbd/${item.id}/${digest}.mp3`;
    const upload = await admin.storage.from(AUDIO_BUCKET).upload(
      objectPath,
      audio,
      {
        contentType: "audio/mpeg",
        upsert: false,
        cacheControl: "3600",
      },
    );
    if (
      upload.error && upload.error.message.toLowerCase().indexOf("exists") < 0
    ) {
      return json({ code: "storage_upload_failed" }, 503);
    }

    const audit = await admin.from("audio_rehost_imports").insert({
      content_item_id: item.id,
      original_url: originalUrl.toString(),
      object_path: objectPath,
      byte_size: audio.byteLength,
      content_sha256: digest,
      imported_by: callerId,
      rights_confirmed: true,
    });
    if (audit.error && audit.error.code !== "23505") {
      // Cannot falsely report success without a durable record of permission.
      return json({ code: "storage_audit_failed" }, 503);
    }
    const { data } = admin.storage.from(AUDIO_BUCKET).getPublicUrl(objectPath);
    return json({
      status: "imported",
      publicUrl: data.publicUrl,
      originalUrl: originalUrl.toString(),
      byteSize: audio.byteLength,
    }, 201);
  } catch {
    // Never leak service keys, signed tokens, internal DB errors, or media bytes.
    return json({ code: "service_unavailable" }, 503);
  }
});
