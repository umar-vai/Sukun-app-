import type { SupabaseClient } from "@supabase/supabase-js";
import type { FailureType } from "./error-classifier.ts";
import type { SlotHealthStore } from "./ai-router.ts";

export class SupabaseSlotHealthStore implements SlotHealthStore {
  constructor(private readonly client: SupabaseClient) {}

  async isAvailable(slotId: number, now: Date): Promise<boolean> {
    const { data, error } = await this.client
      .from("ai_provider_slot_health")
      .select("status,retry_after")
      .eq("slot_id", slotId)
      .single();
    if (error || !data) return true;
    if (data.status === "healthy") return true;
    if (data.status === "disabled") return false;
    return typeof data.retry_after === "string" &&
      new Date(data.retry_after) <= now;
  }

  async markHealthy(slotId: number, now: Date): Promise<void> {
    await this.client.from("ai_provider_slot_health").update({
      status: "healthy",
      failure_type: null,
      failed_at: null,
      retry_after: null,
      consecutive_failures: 0,
      updated_at: now.toISOString(),
    }).eq("slot_id", slotId);
  }

  async markFailure(
    slotIds: number[],
    failureType: FailureType,
    retryAt: Date | null,
    disabled: boolean,
    now: Date,
  ): Promise<void> {
    for (const slotId of slotIds) {
      const { data } = await this.client.from("ai_provider_slot_health")
        .select("consecutive_failures").eq("slot_id", slotId).single();
      await this.client.from("ai_provider_slot_health").update({
        status: disabled ? "disabled" : "cooling_down",
        failure_type: failureType,
        failed_at: now.toISOString(),
        retry_after: retryAt?.toISOString() ?? null,
        consecutive_failures: (data?.consecutive_failures ?? 0) + 1,
        updated_at: now.toISOString(),
      }).eq("slot_id", slotId);
    }
  }
}
