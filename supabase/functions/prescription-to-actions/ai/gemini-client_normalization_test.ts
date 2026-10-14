import { assertEquals, assertRejects } from "jsr:@std/assert@1";
import { GeminiMalformedOutputError } from "./error-classifier.ts";
import { RestGeminiClient } from "./gemini-client.ts";

Deno.test("incomplete Gemini action metadata is normalized for human review", async () => {
  const fetcher: typeof fetch = async () =>
    Response.json({
      output_text: JSON.stringify({
        actions: [{
          instruction: "Repeat the source instruction.",
          frequency: null,
          time_window: "morning",
          exact_time: null,
          resource_match_query: "source phrase",
          source_evidence: "visible source phrase",
          needs_review: false,
          ambiguities: [],
        }],
      }),
    });

  const client = new RestGeminiClient(fetcher);
  const result = await client.generate({
    apiKey: "test-key",
    model: "gemini-3.5-flash-lite",
    prescriptionText: "source",
    timeoutMs: 1000,
  });

  assertEquals(result.actions.length, 1);
  const action = result.actions[0];
  assertEquals(action.type, "other");
  assertEquals(action.title, "visible source phrase");
  assertEquals(action.count_target, null);
  assertEquals(action.duration_minutes, null);
  assertEquals(action.confidence, 0);
  assertEquals(action.needs_review, true);
  assertEquals(action.ambiguities.length > 0, true);
});

const completeAction = {
  type: "amal",
  title: "Read the prescribed dua",
  instruction: "সকাল ৩ বার পড়বেন",
  count_target: 3,
  duration_minutes: null,
  frequency: { type: "daily", interval: 1 },
  time_window: "morning",
  exact_time: null,
  resource_match_query: null,
  source_evidence: "সকাল ৩ বার পড়বেন",
  confidence: 0.97,
  needs_review: false,
  ambiguities: [] as string[],
};

function mockClient(response: Record<string, unknown>): RestGeminiClient {
  return new RestGeminiClient(
    () => Promise.resolve(Response.json({ output_text: JSON.stringify(response) })),
  );
}

Deno.test("supported prescription quote remains an editable review draft", async () => {
  const result = await mockClient({ actions: [completeAction] }).generate({
    apiKey: "fake-key",
    model: "test-model",
    prescriptionText: "সকাল ৩ বার পড়বেন",
    timeoutMs: 1000,
  });
  assertEquals(result.actions[0].needs_review, false);
  assertEquals(result.actions[0].confidence, 0.97);
});

Deno.test("invented source quotation is flagged rather than trusted", async () => {
  const result = await mockClient({ actions: [completeAction] }).generate({
    apiKey: "fake-key",
    model: "test-model",
    prescriptionText: "সন্ধ্যায় ১ বার পড়বেন",
    timeoutMs: 1000,
  });
  assertEquals(result.actions.length, 1);
  assertEquals(result.actions[0].needs_review, true);
  assertEquals(result.actions[0].confidence, 0.5);
  assertEquals(
    result.actions[0].ambiguities.some((reason) =>
      reason.includes("source quotation")
    ),
    true,
  );
});

Deno.test("missing evidence and unexplained uncertainty do not abort parsing", async () => {
  const result = await mockClient({
    actions: [{
      ...completeAction,
      source_evidence: "",
      needs_review: true,
    }],
  }).generate({
    apiKey: "fake-key",
    model: "test-model",
    prescriptionText: "সকাল ৩ বার পড়বেন",
    timeoutMs: 1000,
  });
  assertEquals(result.actions[0].needs_review, true);
  assertEquals(result.actions[0].ambiguities.length > 0, true);
});

Deno.test("model returning no actions fails closed to manual handling", async () => {
  await assertRejects(
    () => mockClient({ actions: [] }).generate({
      apiKey: "fake-key",
      model: "test-model",
      prescriptionText: "সকাল ৩ বার পড়বেন",
      timeoutMs: 1000,
    }),
    GeminiMalformedOutputError,
  );
});
