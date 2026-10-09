import { assertEquals } from "jsr:@std/assert@1";
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
