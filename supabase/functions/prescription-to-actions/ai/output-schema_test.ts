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

Deno.test("preserves Bangla and mixed-language action text", () => {
  const output = parseSuggestedActions({
    actions: [{
      type: "recitation",
      title: "আয়াতুল কুরসি recitation",
      instruction: "সকাল ৩ বার পড়বেন",
      count_target: 3,
      duration_minutes: null,
      frequency: { type: "daily", interval: 1 },
      time_window: "morning",
      exact_time: null,
      resource_match_query: "Ayatul Kursi আয়াতুল কুরসি",
      confidence: 0.92,
      needs_review: false,
      ambiguities: [],
    }],
  });

  assertEquals(output.actions[0].title, "আয়াতুল কুরসি recitation");
  assertEquals(output.actions[0].instruction, "সকাল ৩ বার পড়বেন");
  assertEquals(output.actions[0].count_target, 3);
});
