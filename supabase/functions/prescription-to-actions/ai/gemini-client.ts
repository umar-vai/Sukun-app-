import {
  GeminiMalformedOutputError,
  GeminiProviderError,
  GeminiTimeoutError,
} from "./error-classifier.ts";
import {
  parseSuggestedActions,
  type SuggestedActions,
} from "./output-schema.ts";
import {
  prescriptionDocumentTranscriptionPrompt,
  prescriptionParserPrompt,
} from "./prompt.ts";

export type GeminiDocument = {
  mimeType: "application/pdf" | "image/jpeg" | "image/png";
  base64Data: string;
};

export type GeminiRequest = {
  apiKey: string;
  model: string;
  prescriptionText: string;
  document?: GeminiDocument;
  timeoutMs: number;
};

export interface GeminiClient {
  generate(request: GeminiRequest): Promise<SuggestedActions>;
}

export class RestGeminiClient implements GeminiClient {
  constructor(
    private readonly fetcher: typeof fetch = fetch,
    private readonly diagnostic?: (event: Record<string, unknown>) => void,
  ) {}

  async generate(request: GeminiRequest): Promise<SuggestedActions> {
    if (request.document) {
      throw new Error(
        "Document inputs must be transcribed before action generation.",
      );
    }

    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), request.timeoutMs);
    try {
      const response = await this.fetcher(
        "https://generativelanguage.googleapis.com/v1beta/interactions",
        {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            "x-goog-api-key": request.apiKey,
          },
          signal: controller.signal,
          body: JSON.stringify({
            model: request.model,
            store: false,
            input: prescriptionParserPrompt(request.prescriptionText),
          }),
        },
      );

      if (!response.ok) {
        const body = await safeJson(response);
        throw new GeminiProviderError(
          response.status,
          providerErrorStatus(body),
          parseRetryAfter(response.headers.get("retry-after")),
        );
      }

      const body = await response.json();
      const text = interactionOutputText(body);
      const report = (category: string, extra = {}) =>
        this.diagnostic?.({
          event: "ai_response_diagnostic",
          endpoint: "/v1beta/interactions",
          model: request.model,
          http_status: response.status,
          response_fields: [
            "output_text",
            "steps",
            "outputs",
            "candidates",
            "status",
            "error",
          ]
            .filter((key) => body && Object.hasOwn(body, key)),
          validation_category: category,
          ...extra,
        });
      if (!text) {
        report("output_text_missing");
        throw new GeminiMalformedOutputError();
      }
      let parsed: unknown;
      try {
        parsed = parseJsonObject(text);
      } catch {
        report("output_json_invalid");
        throw new GeminiMalformedOutputError();
      }
      try {
        const result = parseSuggestedActions(parsed);
        report("valid");
        return result;
      } catch {
        // Only fixed field names/types; never serialize provider text or errors.
        const actions = parsed && typeof parsed === "object"
          ? (parsed as Record<string, unknown>).actions
          : null;
        const fields = [
          "type",
          "title",
          "instruction",
          "count_target",
          "duration_minutes",
          "frequency",
          "time_window",
          "exact_time",
          "resource_match_query",
          "source_evidence",
          "confidence",
          "needs_review",
          "ambiguities",
        ];
        report("action_schema_invalid", {
          actions_array: Array.isArray(actions),
          missing_action_fields: fields.filter((field) =>
            Array.isArray(actions) &&
            actions.some((action) =>
              !action || typeof action !== "object" ||
              !Object.hasOwn(action, field)
            )
          ),
          frequency_shapes: Array.isArray(actions)
            ? [
              ...new Set(actions.map((action) =>
                action?.frequency === null ? "null" : typeof action?.frequency
              )),
            ]
            : [],
        });
        throw new GeminiMalformedOutputError();
      }
    } catch (error) {
      if (error instanceof DOMException && error.name === "AbortError") {
        throw new GeminiTimeoutError();
      }
      throw error;
    } finally {
      clearTimeout(timer);
    }
  }

  async transcribeDocument(request: {
    apiKey: string;
    model: string;
    document: GeminiDocument;
    timeoutMs: number;
  }): Promise<string> {
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), request.timeoutMs);
    try {
      const inputType = request.document.mimeType === "application/pdf"
        ? "document"
        : "image";
      const response = await this.fetcher(
        "https://generativelanguage.googleapis.com/v1beta/interactions",
        {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            "x-goog-api-key": request.apiKey,
          },
          signal: controller.signal,
          body: JSON.stringify({
            model: request.model,
            store: false,
            input: [
              {
                type: "text",
                text: prescriptionDocumentTranscriptionPrompt(),
              },
              {
                type: inputType,
                data: request.document.base64Data,
                mime_type: request.document.mimeType,
              },
            ],
          }),
        },
      );

      if (!response.ok) {
        const body = await safeJson(response);
        throw new GeminiProviderError(
          response.status,
          providerErrorStatus(body),
          parseRetryAfter(response.headers.get("retry-after")),
        );
      }

      const body = await response.json();
      const text = interactionOutputText(body)?.trim();
      if (!text) throw new GeminiMalformedOutputError();
      return text;
    } catch (error) {
      if (error instanceof DOMException && error.name === "AbortError") {
        throw new GeminiTimeoutError();
      }
      throw error;
    } finally {
      clearTimeout(timer);
    }
  }
}

async function safeJson(response: Response): Promise<unknown> {
  try {
    return await response.json();
  } catch {
    return null;
  }
}

function providerErrorStatus(value: unknown): string | null {
  if (!value || typeof value !== "object") return null;
  const error = (value as Record<string, unknown>).error;
  if (!error || typeof error !== "object") return null;
  const status = (error as Record<string, unknown>).status;
  return typeof status === "string" ? status : null;
}

function interactionOutputText(value: unknown): string | null {
  if (!value || typeof value !== "object") return null;
  const direct = (value as Record<string, unknown>).output_text;
  if (typeof direct === "string" && direct.trim()) return direct;

  const steps = (value as Record<string, unknown>).steps;
  if (!Array.isArray(steps)) return candidateText(value);
  const texts: string[] = [];
  for (const step of steps) {
    if (!step || typeof step !== "object") continue;
    const content = (step as Record<string, unknown>).content;
    if (!Array.isArray(content)) continue;
    for (const block of content) {
      if (!block || typeof block !== "object") continue;
      const record = block as Record<string, unknown>;
      if (record.type === "text" && typeof record.text === "string") {
        texts.push(record.text);
      }
    }
  }
  return texts.join("") || candidateText(value);
}

function parseJsonObject(text: string): unknown {
  let candidate = text.trim();
  if (candidate.startsWith("```")) {
    candidate = candidate
      .replace(/^```(?:json)?\s*/i, "")
      .replace(/\s*```$/, "");
  }
  const first = candidate.indexOf("{");
  const last = candidate.lastIndexOf("}");
  if (first < 0 || last < first) {
    throw new Error("No JSON object found.");
  }
  return JSON.parse(candidate.slice(first, last + 1));
}

function candidateText(value: unknown): string | null {
  if (!value || typeof value !== "object") return null;
  const candidates = (value as Record<string, unknown>).candidates;
  if (!Array.isArray(candidates) || candidates.length === 0) return null;
  const content = (candidates[0] as Record<string, unknown>).content;
  if (!content || typeof content !== "object") return null;
  const parts = (content as Record<string, unknown>).parts;
  if (!Array.isArray(parts)) return null;
  const texts = parts
    .map((part) =>
      part && typeof part === "object"
        ? (part as Record<string, unknown>).text
        : null
    )
    .filter((part): part is string => typeof part === "string");
  return texts.join("") || null;
}

function parseRetryAfter(value: string | null): number | null {
  if (!value) return null;
  const seconds = Number(value);
  if (Number.isFinite(seconds) && seconds >= 0) return seconds * 1000;
  const date = Date.parse(value);
  return Number.isNaN(date) ? null : Math.max(0, date - Date.now());
}
