import { assertEquals, assertThrows } from "jsr:@std/assert@1";
import { parseSuggestedActions } from "./output-schema.ts";

Deno.test("marks ambiguous output for review", () => {
  const output = parseSuggestedActions({
    actions: [{
      type: "amal",
      title: "Recite an approved dua",
      instruction: "কয়েকবার পড়বেন",
      count_target: null,
      duration_minutes: null,
      frequency: null,
      time_window: null,
      exact_time: null,
      resource_match_query: null,
      confidence: 0.5,
      needs_review: false,
      ambiguities: ["Repetition count is not explicit"],
    }],
  });
  assertEquals(output.actions[0].needs_review, true);
  assertEquals(output.actions[0].count_target, null);
});

Deno.test("rejects malformed dosage-like numeric output", () => {
  assertThrows(
    () =>
      parseSuggestedActions({
        actions: [{
          type: "supplement",
          title: "Supplement",
          instruction: null,
          count_target: 0,
          duration_minutes: null,
          frequency: null,
          time_window: null,
          exact_time: null,
          resource_match_query: null,
          confidence: 0.8,
          needs_review: true,
          ambiguities: [],
        }],
      }),
    Error,
    "positive integer",
  );
});
