import {
  classifyFailure,
  type FailureType,
  GeminiProviderError,
} from "./error-classifier.ts";
import type { GeminiClient, GeminiDocument } from "./gemini-client.ts";
import type { SuggestedActions } from "./output-schema.ts";

export type GeminiKeySlot = {
  id: 1 | 2 | 3 | 4;
  apiKey: string;
  quotaScope: string;
};

export interface SlotHealthStore {
  isAvailable(slotId: number, now: Date): Promise<boolean>;
  markHealthy(slotId: number, now: Date): Promise<void>;
  markFailure(
    slotIds: number[],
    failureType: FailureType,
    retryAt: Date | null,
    disabled: boolean,
    now: Date,
  ): Promise<void>;
}

export type AiRouterResult =
  | {
    status: "generated";
    actions: SuggestedActions["actions"];
    source_text: string | null;
  }
  | { status: "manual_required"; actions: []; message: string };

export type AiRouterOptions = {
  model: string;
  timeoutMs: number;
  cooldownMs: number;
  maxRetryPerKey: number;
  now?: () => Date;
  log?: (event: Record<string, unknown>) => void;
};

export class AiRouter {
  constructor(
    private readonly slots: GeminiKeySlot[],
    private readonly client: GeminiClient,
    private readonly health: SlotHealthStore,
    private readonly options: AiRouterOptions,
  ) {}

  async generate(
    prescriptionText: string,
    requestId: string,
    document?: GeminiDocument,
  ): Promise<AiRouterResult> {
    const now = this.options.now ?? (() => new Date());
    for (
      const slot of this.slots.toSorted((left, right) => left.id - right.id)
    ) {
      if (!await this.health.isAvailable(slot.id, now())) {
        this.log({
          event: "ai_slot_skipped",
          request_id: requestId,
          slot_id: slot.id,
        });
        continue;
      }

      for (
        let attempt = 0;
        attempt <= this.options.maxRetryPerKey;
        attempt += 1
      ) {
        const startedAt = Date.now();
        try {
          const result = await this.client.generate({
            apiKey: slot.apiKey,
            model: this.options.model,
            prescriptionText,
            document,
            timeoutMs: this.options.timeoutMs,
          });
          await this.health.markHealthy(slot.id, now());
          this.log({
            event: "ai_request_succeeded",
            request_id: requestId,
            slot_id: slot.id,
            fallback_count: slot.id - 1,
            latency_ms: Date.now() - startedAt,
          });
          return {
            status: "generated",
            actions: result.actions,
            source_text: result.source_text,
          };
        } catch (error) {
          const decision = classifyFailure(error);
          const providerDiagnostics = error instanceof GeminiProviderError
            ? {
              http_status: error.status,
              provider_status: error.providerStatus,
            }
            : {};
          this.log({
            event: "ai_slot_failed",
            request_id: requestId,
            slot_id: slot.id,
            failure_type: decision.type,
            attempt,
            latency_ms: Date.now() - startedAt,
            ...providerDiagnostics,
          });
          if (!decision.failover) throw error;
          if (decision.retrySameSlot && attempt < this.options.maxRetryPerKey) {
            continue;
          }

          const shouldPersistSlotFailure = decision.type === "quota" ||
            decision.type === "rate_limit" ||
            decision.type === "invalid_credential";
          if (shouldPersistSlotFailure) {
            const retryAfterMs = error instanceof GeminiProviderError
              ? error.retryAfterMs
              : null;
            const cooldownMs = Math.max(
              this.options.cooldownMs,
              retryAfterMs ?? 0,
            );
            const retryAt = decision.disableSlot
              ? null
              : new Date(now().getTime() + cooldownMs);
            const affectedSlots =
              decision.type === "quota" || decision.type === "rate_limit"
                ? this.slots
                  .filter((candidate) =>
                    candidate.quotaScope === slot.quotaScope
                  )
                  .map((candidate) => candidate.id)
                : [slot.id];
            await this.health.markFailure(
              affectedSlots,
              decision.type,
              retryAt,
              decision.disableSlot,
              now(),
            );
          }
          break;
        }
      }
    }

    this.log({ event: "ai_all_slots_unavailable", request_id: requestId });
    return {
      status: "manual_required",
      actions: [],
      message:
        "Automatic action generation is temporarily unavailable. You can continue manually.",
    };
  }

  private log(event: Record<string, unknown>): void {
    this.options.log?.({ model: this.options.model, ...event });
  }
}

type StoredHealth = {
  status: "healthy" | "cooling_down" | "disabled";
  retryAt: Date | null;
};

export class InMemorySlotHealthStore implements SlotHealthStore {
  readonly states = new Map<number, StoredHealth>();

  async isAvailable(slotId: number, now: Date): Promise<boolean> {
    const state = this.states.get(slotId);
    if (!state || state.status === "healthy") return true;
    if (state.status === "disabled") return false;
    return state.retryAt !== null && state.retryAt <= now;
  }

  async markHealthy(slotId: number, _now: Date): Promise<void> {
    this.states.set(slotId, { status: "healthy", retryAt: null });
  }

  async markFailure(
    slotIds: number[],
    _failureType: FailureType,
    retryAt: Date | null,
    disabled: boolean,
    _now: Date,
  ): Promise<void> {
    for (const slotId of slotIds) {
      this.states.set(slotId, {
        status: disabled ? "disabled" : "cooling_down",
        retryAt,
      });
    }
  }
}
