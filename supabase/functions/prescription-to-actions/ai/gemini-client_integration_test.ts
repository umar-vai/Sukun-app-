import { assert, assertEquals } from "jsr:@std/assert@1";
import {
  AiRouter,
  type GeminiKeySlot,
  InMemorySlotHealthStore,
} from "./ai-router.ts";
import { RestGeminiClient } from "./gemini-client.ts";

const slots: GeminiKeySlot[] = [1, 2, 3, 4].map((id) => ({
  id: id as 1 | 2 | 3 | 4,
  apiKey: `slot-${id}-secret`,
  quotaScope: `project-${id}`,
}));

const generatedPayload = {
  source_text: null,
  actions: [{
    type: "amal",
    title: "Ayatul Kursi",
    instruction: "৩ বার পড়বেন",
    count_target: 3,
    duration_minutes: null,
    frequency: { type: "daily", interval: 1 },
    time_window: "morning",
    exact_time: null,
    resource_match_query: "Ayatul Kursi",
    source_evidence: "৩ বার পড়বেন",
    confidence: 0.95,
    needs_review: false,
    ambiguities: [],
  }],
};

Deno.test("HTTP Gemini adapter fails over exhausted slots 1-3 to slot 4", async () => {
  const calls: string[] = [];
  const client = new RestGeminiClient(fakeFetcher(calls, 3));
  const router = new AiRouter(
    slots,
    client,
    new InMemorySlotHealthStore(),
    {
      model: "test-model",
      timeoutMs: 1000,
      cooldownMs: 60000,
      maxRetryPerKey: 0,
      now: () => new Date("2026-10-07T00:00:00Z"),
    },
  );

  const result = await router.generate(
    "সকাল আয়াতুল কুরসি ৩ বার পড়বেন।",
    "integration-failover",
  );

  assertEquals(result.status, "generated");
  assertEquals(calls, [
    "slot-1-secret",
    "slot-2-secret",
    "slot-3-secret",
    "slot-4-secret",
  ]);
  assert(
    !JSON.stringify(result).match(/429|RESOURCE_EXHAUSTED|slot-[1-4]-secret/i),
  );
});

Deno.test("HTTP Gemini adapter returns neutral manual fallback when all slots exhaust", async () => {
  const calls: string[] = [];
  const client = new RestGeminiClient(fakeFetcher(calls, 4));
  const router = new AiRouter(
    slots,
    client,
    new InMemorySlotHealthStore(),
    {
      model: "test-model",
      timeoutMs: 1000,
      cooldownMs: 60000,
      maxRetryPerKey: 0,
      now: () => new Date("2026-10-07T00:00:00Z"),
    },
  );

  const result = await router.generate(
    "private prescription",
    "integration-all",
  );

  assertEquals(result.status, "manual_required");
  assertEquals(calls.length, 4);
  const serialized = JSON.stringify(result);
  assert(!serialized.match(/429|quota|RESOURCE_EXHAUSTED|slot-[1-4]-secret/i));
});

function fakeFetcher(calls: string[], exhaustedSlots: number): typeof fetch {
  return async (_input, init) => {
    const key = new Headers(init?.headers).get("x-goog-api-key") ?? "";
    calls.push(key);
    const slotNumber = Number(key.match(/slot-(\d)-secret/)?.[1] ?? 0);
    if (slotNumber > 0 && slotNumber <= exhaustedSlots) {
      return new Response(
        JSON.stringify({ error: { status: "RESOURCE_EXHAUSTED" } }),
        {
          status: 429,
          headers: { "Content-Type": "application/json", "Retry-After": "1" },
        },
      );
    }
    return new Response(
      JSON.stringify({
        candidates: [{
          content: { parts: [{ text: JSON.stringify(generatedPayload) }] },
        }],
      }),
      { status: 200, headers: { "Content-Type": "application/json" } },
    );
  };
}
