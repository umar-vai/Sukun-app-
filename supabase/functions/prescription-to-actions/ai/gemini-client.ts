import {
  GeminiMalformedOutputError,
  GeminiProviderError,
  GeminiTimeoutError,
} from "./error-classifier.ts";
import {
  geminiResponseSchema,
  parseSuggestedActions,
  type SuggestedActions,
} from "./output-schema.ts";
import {
  prescriptionDocumentParserPrompt,
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
  constructor(private readonly fetcher: typeof fetch = fetch) {}

  async generate(request: GeminiRequest): Promise<SuggestedActions> {
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), request.timeoutMs);
    try {
      if (request.document) {
        return await this.generateDocumentInteraction(
          request,
          controller.signal,
        );
      }

      const contents = [{
        role: "user",
        parts: [{
          text: prescriptionParserPrompt(request.prescriptionText),
        }],
      }];
      const configurations: Record<string, unknown>[] = [
        {
          responseFormat: {
            text: {
              mimeType: "application/json",
              schema: geminiResponseSchema,
            },
          },
        },
        {
          responseMimeType: "application/json",
          responseJsonSchema: geminiResponseSchema,
        },
      ];
      let response: Response | null = null;
      for (const generationConfig of configurations) {
        response = await this.fetcher(
          `https://generativelanguage.googleapis.com/v1beta/models/${
            encodeURIComponent(request.model)
          }:generateContent`,
          {
            method: "POST",
            headers: {
              "Content-Type": "application/json",
              "x-goog-api-key": request.apiKey,
              "X-Server-Timeout": String(
                Math.max(1, Math.floor(request.timeoutMs / 1000)),
              ),
            },
            signal: controller.signal,
            body: JSON.stringify({ contents, generationConfig }),
          },
        );
        if (response.ok) break;
        const body = await safeJson(response);
        const providerStatus = providerErrorStatus(body);
        if (response.status === 400 && providerStatus === "INVALID_ARGUMENT") {
          continue;
        }
        throw new GeminiProviderError(
          response.status,
          providerStatus,
          parseRetryAfter(response.headers.get("retry-after")),
        );
      }
      if (response == null || !response.ok) {
        throw new GeminiProviderError(
          response?.status ?? 500,
          "INVALID_ARGUMENT",
          null,
        );
      }
      const body = await response.json();
      const text = candidateText(body);
      if (!text) throw new GeminiMalformedOutputError();
      try {
        return parseSuggestedActions(JSON.parse(text));
      } catch {
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

  private async generateDocumentInteraction(
    request: GeminiRequest,
    signal: AbortSignal,
  ): Promise<SuggestedActions> {
    const document = request.document!;
    const inputType = document.mimeType === "application/pdf"
      ? "document"
      : "image";
    const response = await this.fetcher(
      "https://generativelanguage.googleapis.com/v1beta2/interactions",
      {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "x-goog-api-key": request.apiKey,
        },
        signal,
        body: JSON.stringify({
          model: request.model,
          store: false,
          input: [
            {
              type: inputType,
              data: document.base64Data,
              mime_type: document.mimeType,
            },
            {
              type: "text",
              text: prescriptionDocumentParserPrompt(),
            },
          ],
          response_format: [{
            type: "text",
            mime_type: "application/json",
            schema: geminiResponseSchema,
          }],
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
    if (!text) throw new GeminiMalformedOutputError();
    try {
      return parseSuggestedActions(JSON.parse(text));
    } catch {
      throw new GeminiMalformedOutputError();
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
  if (!Array.isArray(steps)) return null;
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
  return texts.join("") || null;
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
