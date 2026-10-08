import { assert, assertEquals, assertRejects } from "jsr:@std/assert@1";
import { RestGeminiClient } from "./gemini-client.ts";
import { GeminiMalformedOutputError } from "./error-classifier.ts";

for (
  const [body, category] of [
    [{ outputs: [{ text: "private prescription" }] }, "output_text_missing"],
    [{ output_text: "private prescription" }, "output_json_invalid"],
    [{
      output_text: JSON.stringify({
        actions: [{
          type: "amal",
          title: "private prescription",
          instruction: null,
          count_target: null,
          duration_minutes: null,
          frequency: "daily",
          time_window: null,
          exact_time: null,
          resource_match_query: null,
          source_evidence: "private prescription",
          confidence: 2,
          needs_review: false,
          ambiguities: [],
        }],
      }),
    }, "action_schema_invalid"],
  ] as const
) {
  Deno.test(`safe diagnostics distinguish ${category} without content`, async () => {
    const events: Record<string, unknown>[] = [];
    const client = new RestGeminiClient(
      () => Promise.resolve(Response.json(body)),
      (event) => events.push(event),
    );
    await assertRejects(() =>
      client.generate({
        apiKey: "secret-key",
        model: "gemini-3.5-flash-lite",
        prescriptionText: "private prescription",
        timeoutMs: 1000,
      }), GeminiMalformedOutputError);
    assertEquals(events[0].validation_category, category);
    const serialized = JSON.stringify(events);
    assert(!serialized.includes("private prescription"));
    assert(!serialized.includes("secret-key"));
  });
}
