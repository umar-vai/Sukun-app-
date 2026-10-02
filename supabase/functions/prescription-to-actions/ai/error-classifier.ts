export type FailureType =
  | "quota"
  | "rate_limit"
  | "timeout"
  | "provider_unavailable"
  | "invalid_credential"
  | "malformed_output"
  | "application";

export type FailureDecision = {
  type: FailureType;
  failover: boolean;
  retrySameSlot: boolean;
  disableSlot: boolean;
};

export class GeminiProviderError extends Error {
  constructor(
    readonly status: number,
    readonly providerStatus: string | null,
    readonly retryAfterMs: number | null,
  ) {
    super("Gemini provider request failed.");
  }
}

export class GeminiTimeoutError extends Error {
  constructor() {
    super("Gemini provider request timed out.");
  }
}

export class GeminiMalformedOutputError extends Error {
  constructor() {
    super("Gemini returned malformed structured output.");
  }
}

export function classifyFailure(error: unknown): FailureDecision {
  if (error instanceof GeminiTimeoutError) {
    return {
      type: "timeout",
      failover: true,
      retrySameSlot: true,
      disableSlot: false,
    };
  }
  if (error instanceof GeminiMalformedOutputError) {
    return {
      type: "malformed_output",
      failover: true,
      retrySameSlot: true,
      disableSlot: false,
    };
  }
  if (error instanceof GeminiProviderError) {
    if (error.status === 401 || error.status === 403) {
      return {
        type: "invalid_credential",
        failover: true,
        retrySameSlot: false,
        disableSlot: true,
      };
    }
    if (error.status === 429) {
      const quota = error.providerStatus === "RESOURCE_EXHAUSTED";
      return {
        type: quota ? "quota" : "rate_limit",
        failover: true,
        retrySameSlot: false,
        disableSlot: false,
      };
    }
    if (error.status === 408 || error.status >= 500) {
      return {
        type: "provider_unavailable",
        failover: true,
        retrySameSlot: true,
        disableSlot: false,
      };
    }
  }
  return {
    type: "application",
    failover: false,
    retrySameSlot: false,
    disableSlot: false,
  };
}
