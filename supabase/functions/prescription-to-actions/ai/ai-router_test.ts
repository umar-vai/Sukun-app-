import { assert, assertEquals } from "jsr:@std/assert@1";
import {
  AiRouter,
  type GeminiKeySlot,
  InMemorySlotHealthStore,
} from "./ai-router.ts";
import {
  GeminiMalformedOutputError,
  GeminiProviderError,
  GeminiTimeoutError,
} from "./error-classifier.ts";
import type { GeminiClient, GeminiRequest } from "./gemini-client.ts";
import type { SuggestedActions } from "./output-schema.ts";

const slots: GeminiKeySlot[] = [1, 2, 3, 4].map((id) => ({
  id: id as 1 | 2 | 3 | 4,
  apiKey: `secret-key-${id}`,
  quotaScope: `project-${id}`,
}));

const fixture: SuggestedActions = {
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

Deno.test("slot 1 success does not call later slots", async () => {
  const client = new FakeGeminiClient({ "secret-key-1": [fixture] });
  const result = await router(client).generate("source", "request-1");
  assertEquals(result.status, "generated");
  assertEquals(client.calls, ["secret-key-1"]);
});

for (const failedSlots of [1, 2, 3]) {
  Deno.test(`${failedSlots} exhausted slot(s) fail over to slot ${failedSlots + 1}`, async () => {
    const behavior: Record<string, unknown[]> = {};
    for (let index = 1; index <= failedSlots; index += 1) {
      behavior[`secret-key-${index}`] = [
        new GeminiProviderError(429, "RESOURCE_EXHAUSTED", null),
      ];
    }
    behavior[`secret-key-${failedSlots + 1}`] = [fixture];
    const client = new FakeGeminiClient(behavior);
    const result = await router(client).generate(
      "source",
      `request-${failedSlots}`,
    );
    assertEquals(result.status, "generated");
    assertEquals(client.calls.at(-1), `secret-key-${failedSlots + 1}`);
  });
}

Deno.test("all exhausted returns neutral manual fallback", async () => {
  const error = new GeminiProviderError(429, "RESOURCE_EXHAUSTED", null);
  const client = new FakeGeminiClient(Object.fromEntries(
    slots.map((slot) => [slot.apiKey, [error]]),
  ));
  const result = await router(client).generate("source", "request-all");
  assertEquals(result.status, "manual_required");
  assert(!JSON.stringify(result).match(/429|quota|key|RESOURCE_EXHAUSTED/i));
});

Deno.test("invalid credential is disabled and skipped on the next request", async () => {
  const health = new InMemorySlotHealthStore();
  const client = new FakeGeminiClient({
    "secret-key-1": [new GeminiProviderError(403, "PERMISSION_DENIED", null)],
    "secret-key-2": [fixture, fixture],
  });
  const first = router(client, health);
  await first.generate("source", "request-invalid-1");
  await first.generate("source", "request-invalid-2");
  assertEquals(client.calls, ["secret-key-1", "secret-key-2", "secret-key-2"]);
});

Deno.test("timeout retries once then falls through", async () => {
  const client = new FakeGeminiClient({
    "secret-key-1": [new GeminiTimeoutError(), new GeminiTimeoutError()],
    "secret-key-2": [fixture],
  });
  await router(client).generate("source", "request-timeout");
  assertEquals(client.calls, ["secret-key-1", "secret-key-1", "secret-key-2"]);
});

Deno.test("provider outage does not poison a key for the next request", async () => {
  const health = new InMemorySlotHealthStore();
  const client = new FakeGeminiClient({
    "secret-key-1": [
      new GeminiProviderError(503, "UNAVAILABLE", null),
      new GeminiProviderError(503, "UNAVAILABLE", null),
      fixture,
    ],
    "secret-key-2": [fixture],
  });
  const aiRouter = router(client, health);

  await aiRouter.generate("source", "request-provider-outage-1");
  await aiRouter.generate("source", "request-provider-outage-2");

  assertEquals(client.calls, [
    "secret-key-1",
    "secret-key-1",
    "secret-key-2",
    "secret-key-1",
  ]);
});

Deno.test("cooling slot is skipped", async () => {
  const health = new InMemorySlotHealthStore();
  await health.markFailure(
    [1],
    "quota",
    new Date("2026-10-03T00:00:00Z"),
    false,
    new Date("2026-10-02T00:00:00Z"),
  );
  const client = new FakeGeminiClient({ "secret-key-2": [fixture] });
  await router(client, health).generate("source", "request-cooling");
  assertEquals(client.calls, ["secret-key-2"]);
});

Deno.test("quota failure cools every slot in the same declared scope", async () => {
  const sharedSlots: GeminiKeySlot[] = [
    { id: 1, apiKey: "secret-key-1", quotaScope: "shared-project" },
    { id: 2, apiKey: "secret-key-2", quotaScope: "shared-project" },
    { id: 3, apiKey: "secret-key-3", quotaScope: "independent-project" },
  ];
  const client = new FakeGeminiClient({
    "secret-key-1": [
      new GeminiProviderError(429, "RESOURCE_EXHAUSTED", null),
    ],
    "secret-key-3": [fixture],
  });
  const aiRouter = new AiRouter(
    sharedSlots,
    client,
    new InMemorySlotHealthStore(),
    {
      model: "test-model",
      timeoutMs: 100,
      cooldownMs: 60000,
      maxRetryPerKey: 1,
      now: () => new Date("2026-10-02T00:00:00Z"),
    },
  );

  await aiRouter.generate("source", "request-shared-scope");

  assertEquals(client.calls, ["secret-key-1", "secret-key-3"]);
});

Deno.test("malformed output is retried then fails over", async () => {
  const client = new FakeGeminiClient({
    "secret-key-1": [
      new GeminiMalformedOutputError(),
      new GeminiMalformedOutputError(),
    ],
    "secret-key-2": [fixture],
  });
  await router(client).generate("source", "request-malformed");
  assertEquals(client.calls, ["secret-key-1", "secret-key-1", "secret-key-2"]);
});

Deno.test("logs contain slot ids but never key secrets or prescription text", async () => {
  const logs: Record<string, unknown>[] = [];
  const client = new FakeGeminiClient({ "secret-key-1": [fixture] });
  await router(client, new InMemorySlotHealthStore(), logs).generate(
    "private prescription text",
    "request-logs",
  );
  const serialized = JSON.stringify(logs);
  assert(!serialized.includes("secret-key"));
  assert(!serialized.includes("private prescription text"));
  assert(serialized.includes('"slot_id":1'));
});

function router(
  client: GeminiClient,
  health = new InMemorySlotHealthStore(),
  logs: Record<string, unknown>[] = [],
): AiRouter {
  return new AiRouter(slots, client, health, {
    model: "test-model",
    timeoutMs: 100,
    cooldownMs: 60000,
    maxRetryPerKey: 1,
    now: () => new Date("2026-10-02T00:00:00Z"),
    log: (event) => logs.push(event),
  });
}

class FakeGeminiClient implements GeminiClient {
  readonly calls: string[] = [];

  constructor(private readonly behavior: Record<string, unknown[]>) {}

  generate(request: GeminiRequest): Promise<SuggestedActions> {
    this.calls.push(request.apiKey);
    const next = this.behavior[request.apiKey]?.shift();
    if (next instanceof Error) return Promise.reject(next);
    if (next) return Promise.resolve(next as SuggestedActions);
    return Promise.reject(new GeminiProviderError(503, "UNAVAILABLE", null));
  }
}
