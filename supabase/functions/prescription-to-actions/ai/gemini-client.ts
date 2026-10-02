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
import { prescriptionParserPrompt } from "./prompt.ts";

export type GeminiRequest = {
  apiKey: string;
  model: string;
  prescriptionText: string;
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
      const response = await this.fetcher(
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
          body: JSON.stringify({
            contents: [{
              role: "user",
              parts: [{
                text: prescriptionParserPrompt(request.prescriptionText),
              }],
            }],
            generationConfig: {
              responseFormat: {
                text: {
                  mimeType: "application/json",
                  schema: geminiResponseSchema,
                },
              },
            },
          }),
        },
      );
      if (!response.ok) {
        const body = await safeJson(response);
        const providerStatus = providerErrorStatus(body);
        throw new GeminiProviderError(
          response.status,
          providerStatus,
          parseRetryAfter(response.headers.get("retry-after")),
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
