import { createClient, type SupabaseClient } from "@supabase/supabase-js";
import {
  AiRouter,
  type GeminiKeySlot,
} from "../prescription-to-actions/ai/ai-router.ts";
import { RestGeminiClient } from "../prescription-to-actions/ai/gemini-client.ts";
import {
  classifyFailure,
  GeminiProviderError,
} from "../prescription-to-actions/ai/error-classifier.ts";
import { SupabaseSlotHealthStore } from "../prescription-to-actions/ai/supabase-health-store.ts";
import {
  InvalidDocumentError,
  parseDocumentExtractionInput,
  validateDocumentBytes,
} from "./validation.ts";

const bucketId = "prescription-private";
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
    input = parseDocumentExtractionInput(await request.json());
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

  let adminClient: SupabaseClient | null = null;
  let actorId: string | null = null;
  let patientId: string | null = null;
  let processingStarted = false;
  try {
    const supabaseUrl = requiredEnvironment("SUPABASE_URL");
    const anonKey = requiredEnvironment("SUPABASE_ANON_KEY");
    const serviceRoleKey = requiredEnvironment("SUPABASE_SERVICE_ROLE_KEY");
    const callerClient = createClient(supabaseUrl, anonKey, {
      global: { headers: { Authorization: authorization } },
      auth: { persistSession: false, autoRefreshToken: false },
    });
    const { data: { user }, error: userError } = await callerClient.auth
      .getUser(accessToken);
    if (userError || !user) {
      return jsonResponse({ code: "authentication_required" }, 401);
    }
    actorId = user.id;
    const { data: role } = await callerClient.from("user_roles").select("role")
      .eq("user_id", user.id).eq("role", "super_admin").maybeSingle();
    if (!role) return jsonResponse({ code: "forbidden" }, 403);

    const { data: attachment } = await callerClient
      .from("prescription_attachments")
      .select(
        "id,patient_id,bucket_id,storage_path,original_filename,mime_type,byte_size,extraction_status,processing_request_id,processing_started_at,prescription_id,care_plan_id,normalized_result",
      )
      .eq("id", input.attachmentId)
      .maybeSingle();
    if (!attachment) {
      return jsonResponse({ code: "attachment_not_found" }, 404);
    }
    patientId = attachment.patient_id;
    if (attachment.extraction_status === "succeeded") {
      return jsonResponse({
        ...attachment.normalized_result,
        attachment_id: attachment.id,
        prescription_id: attachment.prescription_id,
        care_plan_id: attachment.care_plan_id,
      });
    }
    if (attachment.extraction_status === "processing") {
      const startedAt = Date.parse(attachment.processing_started_at ?? "");
      const stale = Number.isFinite(startedAt) &&
        Date.now() - startedAt >= 2 * 60 * 1000;
      if (attachment.processing_request_id !== input.requestId || !stale) {
        return jsonResponse({ code: "request_processing" }, 409);
      }
    }

    adminClient = createClient(supabaseUrl, serviceRoleKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    });
    let processingQuery = adminClient.from("prescription_attachments").update({
      extraction_status: "processing",
      processing_request_id: input.requestId,
      uploaded_at: new Date().toISOString(),
      processing_started_at: new Date().toISOString(),
      normalized_result: null,
      updated_at: new Date().toISOString(),
    }).eq("id", input.attachmentId);
    processingQuery = attachment.extraction_status === "processing"
      ? processingQuery
        .eq("extraction_status", "processing")
        .eq("processing_request_id", input.requestId)
        .lt(
          "processing_started_at",
          new Date(Date.now() - 2 * 60 * 1000).toISOString(),
        )
      : processingQuery.in("extraction_status", [
        "pending_upload",
        "failed",
        "manual_required",
      ]);
    const { data: processingAttachment, error: processingError } =
      await processingQuery.select().maybeSingle();
    if (processingError || !processingAttachment) {
      return jsonResponse({ code: "request_processing" }, 409);
    }
    processingStarted = true;

    await adminClient.from("admin_audit_logs").insert([
      {
        actor_user_id: user.id,
        action: "prescription_attachment.uploaded",
        entity_type: "prescription_attachment",
        entity_id: attachment.id,
        patient_id: attachment.patient_id,
        request_id: input.requestId,
        metadata: {
          mime_type: attachment.mime_type,
          byte_size: attachment.byte_size,
        },
      },
      {
        actor_user_id: user.id,
        action: "prescription_attachment.extraction_requested",
        entity_type: "prescription_attachment",
        entity_id: attachment.id,
        patient_id: attachment.patient_id,
        request_id: input.requestId,
        metadata: {},
      },
    ]);

    const { data: file, error: downloadError } = await adminClient.storage
      .from(bucketId).download(attachment.storage_path);
    if (downloadError || !file) throw new InvalidDocumentError();
    const bytes = new Uint8Array(await file.arrayBuffer());
    validateDocumentBytes(bytes, attachment.mime_type, attachment.byte_size);

    const slots = configuredSlots();
    const configuredDocumentModel = Deno.env.get("GEMINI_DOCUMENT_MODEL")
      ?.trim();
    const documentModel = !configuredDocumentModel ||
        configuredDocumentModel === "gemini-2.5-flash"
      ? "gemini-3.5-flash-lite"
      : configuredDocumentModel;
    const healthStore = new SupabaseSlotHealthStore(adminClient);
    const geminiClient = new RestGeminiClient(
      fetch,
      (event) =>
        console.log(JSON.stringify({ ...event, request_id: input.requestId })),
    );
    const timeoutMs = positiveInteger("AI_DOCUMENT_TIMEOUT_MS", 35000);
    const cooldownMs = positiveInteger("AI_KEY_COOLDOWN_SECONDS", 3600) * 1000;
    const document = {
      mimeType: attachment.mime_type,
      base64Data: bytesToBase64(bytes),
    } as const;

    const transcription = slots.length === 0
      ? null
      : await transcribeDocumentWithFailover({
        slots,
        client: geminiClient,
        health: healthStore,
        model: documentModel,
        document,
        timeoutMs,
        cooldownMs,
        requestId: input.requestId,
      });

    if (!transcription?.trim()) {
      const fallback = {
        request_id: input.requestId,
        ...manualRequired(),
        attachment_id: attachment.id,
      };
      await adminClient.from("prescription_attachments").update({
        extraction_status: "manual_required",
        normalized_result: fallback,
        processed_at: new Date().toISOString(),
        updated_at: new Date().toISOString(),
      }).eq("id", attachment.id);
      await recordFailure(
        adminClient,
        user.id,
        attachment.patient_id,
        attachment.id,
        input.requestId,
        "transcription_failed",
      );
      return jsonResponse(fallback);
    }

    const configuredParserModel = Deno.env.get("GEMINI_PARSER_MODEL")?.trim();
    const parserModel = configuredParserModel || documentModel;
    const router = new AiRouter(
      slots,
      geminiClient,
      healthStore,
      {
        model: parserModel,
        timeoutMs: positiveInteger("AI_TIMEOUT_MS", 20000),
        cooldownMs,
        maxRetryPerKey: nonnegativeInteger("AI_MAX_RETRY_PER_KEY", 1),
        log: (event) => console.log(JSON.stringify(event)),
      },
    );
    const result = await router.generate(transcription, input.requestId);

    if (result.status === "manual_required") {
      const fallback = {
        request_id: input.requestId,
        ...manualRequired(),
        attachment_id: attachment.id,
      };
      await adminClient.from("prescription_attachments").update({
        extraction_status: "manual_required",
        normalized_result: fallback,
        processed_at: new Date().toISOString(),
        updated_at: new Date().toISOString(),
      }).eq("id", attachment.id);
      await recordFailure(
        adminClient,
        user.id,
        attachment.patient_id,
        attachment.id,
        input.requestId,
        "action_generation_failed",
      );
      return jsonResponse(fallback);
    }

    const normalizedResult = {
      request_id: input.requestId,
      status: "generated",
      source_text: transcription,
      actions: result.actions,
    };
    const { data: finalized, error: finalizeError } = await adminClient.rpc(
      "finalize_prescription_attachment",
      {
        p_attachment_id: attachment.id,
        p_actor_user_id: user.id,
        p_request_id: input.requestId,
        p_extracted_text: transcription,
        p_normalized_result: normalizedResult,
        p_provider_model: `${documentModel} -> ${parserModel}`,
      },
    );
    if (finalizeError || !finalized) throw new Error("finalization_failed");
    return jsonResponse({
      ...normalizedResult,
      attachment_id: finalized.attachment_id,
      prescription_id: finalized.prescription_id,
      care_plan_id: finalized.care_plan_id,
    });
  } catch (error) {
    const invalidDocument = error instanceof InvalidDocumentError;
    if (adminClient && processingStarted && actorId && patientId) {
      await adminClient.from("prescription_attachments").update({
        extraction_status: "failed",
        processed_at: new Date().toISOString(),
        updated_at: new Date().toISOString(),
      }).eq("id", input.attachmentId);
      await recordFailure(
        adminClient,
        actorId,
        patientId,
        input.attachmentId,
        input.requestId,
        invalidDocument ? "invalid_file" : "processing_failed",
      );
    }
    console.log(JSON.stringify({
      event: "prescription_document_processing_failed",
      request_id: input.requestId,
      attachment_id: input.attachmentId,
      failure_type: invalidDocument ? "invalid_file" : "processing_failed",
    }));
    if (invalidDocument) {
      return jsonResponse({
        code: "invalid_file",
        message: (error as InvalidDocumentError).message,
      }, 400);
    }
    return jsonResponse({
      request_id: input.requestId,
      ...manualRequired(),
      attachment_id: input.attachmentId,
    });
  }
});

async function transcribeDocumentWithFailover(args: {
  slots: GeminiKeySlot[];
  client: RestGeminiClient;
  health: SupabaseSlotHealthStore;
  model: string;
  document: {
    mimeType: "application/pdf" | "image/jpeg" | "image/png";
    base64Data: string;
  };
  timeoutMs: number;
  cooldownMs: number;
  requestId: string;
}): Promise<string | null> {
  const now = () => new Date();
  for (const slot of args.slots.toSorted((left, right) => left.id - right.id)) {
    if (!await args.health.isAvailable(slot.id, now())) {
      console.log(JSON.stringify({
        model: args.model,
        event: "document_transcription_slot_skipped",
        request_id: args.requestId,
        slot_id: slot.id,
      }));
      continue;
    }

    const startedAt = Date.now();
    try {
      const text = await args.client.transcribeDocument({
        apiKey: slot.apiKey,
        model: args.model,
        document: args.document,
        timeoutMs: args.timeoutMs,
      });
      await args.health.markHealthy(slot.id, now());
      console.log(JSON.stringify({
        model: args.model,
        event: "document_transcription_succeeded",
        request_id: args.requestId,
        slot_id: slot.id,
        latency_ms: Date.now() - startedAt,
      }));
      return text;
    } catch (error) {
      const decision = classifyFailure(error);
      const providerDiagnostics = error instanceof GeminiProviderError
        ? {
          http_status: error.status,
          provider_status: error.providerStatus,
        }
        : {};
      console.log(JSON.stringify({
        model: args.model,
        event: "document_transcription_failed",
        request_id: args.requestId,
        slot_id: slot.id,
        failure_type: decision.type,
        latency_ms: Date.now() - startedAt,
        ...providerDiagnostics,
      }));

      if (decision.type === "invalid_credential") {
        await args.health.markFailure(
          [slot.id],
          decision.type,
          null,
          true,
          now(),
        );
      } else if (
        decision.type === "quota" || decision.type === "rate_limit"
      ) {
        const retryAfterMs = error instanceof GeminiProviderError
          ? error.retryAfterMs
          : null;
        const retryAt = new Date(
          now().getTime() + Math.max(args.cooldownMs, retryAfterMs ?? 0),
        );
        const affectedSlots = args.slots
          .filter((candidate) => candidate.quotaScope === slot.quotaScope)
          .map((candidate) => candidate.id);
        await args.health.markFailure(
          affectedSlots,
          decision.type,
          retryAt,
          false,
          now(),
        );
      }

      if (!decision.failover) return null;
    }
  }
  return null;
}

function configuredSlots(): GeminiKeySlot[] {
  const slots: GeminiKeySlot[] = [];
  for (const id of [1, 2, 3, 4] as const) {
    const apiKey = Deno.env.get(`GEMINI_API_KEY_${id}`)?.trim();
    if (!apiKey) continue;
    slots.push({
      id,
      apiKey,
      quotaScope: Deno.env.get(`GEMINI_QUOTA_SCOPE_${id}`)?.trim() ||
        "unverified-shared-quota",
    });
  }
  return slots;
}

function manualRequired() {
  return {
    status: "manual_required" as const,
    actions: [] as [],
    message:
      "We could not read this prescription safely. The original file is preserved; continue with manual action entry.",
  };
}

async function recordFailure(
  client: SupabaseClient,
  actorUserId: string,
  patientId: string,
  attachmentId: string,
  requestId: string,
  reason: string,
): Promise<void> {
  await client.from("admin_audit_logs").insert({
    actor_user_id: actorUserId,
    action: "prescription_attachment.extraction_failed",
    entity_type: "prescription_attachment",
    entity_id: attachmentId,
    patient_id: patientId,
    request_id: requestId,
    metadata: { reason },
  });
}

function bytesToBase64(bytes: Uint8Array): string {
  const chunks: string[] = [];
  for (let offset = 0; offset < bytes.length; offset += 0x8000) {
    chunks.push(
      String.fromCharCode(...bytes.subarray(offset, offset + 0x8000)),
    );
  }
  return btoa(chunks.join(""));
}

function positiveInteger(name: string, fallback: number): number {
  const parsed = Number(Deno.env.get(name));
  return Number.isInteger(parsed) && parsed > 0 ? parsed : fallback;
}

function nonnegativeInteger(name: string, fallback: number): number {
  const parsed = Number(Deno.env.get(name));
  return Number.isInteger(parsed) && parsed >= 0 ? parsed : fallback;
}
