import { assertEquals } from "jsr:@std/assert@1";
import {
  normalizeSuggestedActions,
  parseSuggestedActions,
} from "./output-schema.ts";

const quote = "প্রতিদিন সকাল-সন্ধ্যা আয়াতুল কুরসি ৭ বার করে পড়বেন।";

function action(
  sourceEvidence: string,
  extras: Record<string, unknown> = {},
): Record<string, unknown> {
  return {
    type: "recitation",
    title: "আয়াতুল কুরসি",
    instruction: sourceEvidence,
    count_target: 7,
    duration_minutes: null,
    frequency: null,
    time_window: null,
    exact_time: null,
    resource_match_query: "2:255",
    source_evidence: sourceEvidence,
    confidence: 0.94,
    needs_review: false,
    ambiguities: [],
    ...extras,
  };
}

function extract(
  source: string,
  actions: Record<string, unknown>[],
) {
  return parseSuggestedActions(
    normalizeSuggestedActions({ actions }, source),
  ).actions;
}

Deno.test("explicit Bengali morning-evening becomes two source-backed daily sessions", () => {
  const sessions = extract(quote, [action(quote)]);
  assertEquals(sessions.length, 2);
  assertEquals(sessions.map((a) => a.time_window), ["morning", "evening"]);
  assertEquals(sessions.map((a) => a.frequency), [
    { type: "daily", interval: 1 },
    { type: "daily", interval: 1 },
  ]);
  assertEquals(sessions.map((a) => a.count_target), [7, 7]);
  assertEquals(sessions.map((a) => a.exact_time), [null, null]);
  assertEquals(sessions.every((a) => a.source_evidence === quote), true);
  assertEquals(sessions.every((a) => !a.needs_review), true);
});

Deno.test("duplicate suggestions collapse without dropping separate morning and evening sessions", () => {
  const sessions = extract(quote, [
    action(quote),
    action(quote),
    action(quote, { time_window: "morning" }),
    action(quote, { time_window: "evening" }),
  ]);
  assertEquals(sessions.length, 2);
  assertEquals(sessions.map((a) => a.time_window), ["morning", "evening"]);
});

Deno.test("different prescription counts are never deduplicated", () => {
  const sessions = extract(quote, [
    action(quote, { count_target: 7 }),
    action(quote, { count_target: 11 }),
  ]);
  assertEquals(sessions.length, 4);
  assertEquals(sessions.map((a) => a.count_target), [7, 7, 11, 11]);
});

Deno.test("explicit daily recurrence repairs missing frequency without fabricating an exact clock", () => {
  const evidence = "প্রতিদিন সকালে দোয়া পড়বেন।";
  const sessions = extract(evidence, [action(evidence, {
    time_window: "morning",
  })]);
  assertEquals(sessions.length, 1);
  assertEquals(sessions[0].frequency, { type: "daily", interval: 1 });
  assertEquals(sessions[0].exact_time, null);
});

Deno.test("one-time morning alone is not silently assumed to be daily", () => {
  const evidence = "আগামীকাল সকালে দোয়া পড়বেন।";
  const sessions = extract(evidence, [action(evidence)]);
  assertEquals(sessions.length, 1);
  assertEquals(sessions[0].frequency, null);
  assertEquals(sessions[0].needs_review, true);
});

Deno.test("unsupported AI-claimed schedule cannot add a recurrence", () => {
  const evidence = "সকালে আয়াতুল কুরসি পড়বেন।";
  const sessions = extract(evidence, [
    action("প্রতিদিন সকাল-সন্ধ্যা আয়াতুল কুরসি পড়বেন।"),
  ]);
  assertEquals(sessions.length, 1);
  assertEquals(sessions[0].frequency, null);
  assertEquals(sessions[0].needs_review, true);
});

Deno.test("conflicting exact clock on a paired schedule is cleared for Admin review", () => {
  const sessions = extract(quote, [action(quote, {
    exact_time: "07:00",
  })]);
  assertEquals(sessions.length, 2);
  assertEquals(sessions.map((a) => a.exact_time), [null, null]);
  assertEquals(sessions.every((a) => a.needs_review), true);
  assertEquals(
    sessions.every((a) =>
      a.ambiguities.some((reason) =>
        reason.includes("Confirm each reminder time")
      )
    ),
    true,
  );
});

Deno.test("invalid optional AI metadata becomes a source-backed review draft", () => {
  const evidence = "আজ আয়াতুল কুরসি পড়বেন।";
  const sessions = extract(evidence, [action(evidence, {
    count_target: "seven",
    duration_minutes: -4,
    frequency: { type: "weekly", weekdays: [0, 8] },
    time_window: "dawn",
    exact_time: "7 AM",
    confidence: 5,
    needs_review: false,
  })]);

  assertEquals(sessions.length, 1);
  assertEquals(sessions[0].count_target, null);
  assertEquals(sessions[0].duration_minutes, null);
  assertEquals(sessions[0].frequency, null);
  assertEquals(sessions[0].time_window, null);
  assertEquals(sessions[0].exact_time, null);
  assertEquals(sessions[0].confidence, 0);
  assertEquals(sessions[0].source_evidence, evidence);
  assertEquals(sessions[0].needs_review, true);
  assertEquals(
    sessions[0].ambiguities.some((reason) =>
      reason.includes("Unsupported AI metadata cleared:")
    ),
    true,
  );
});

Deno.test("explicit evidence can restore daily frequency but never invented clock time", () => {
  const evidence = "প্রতিদিন দোয়া পড়বেন।";
  const sessions = extract(evidence, [action(evidence, {
    frequency: { type: "daily", interval: 0 },
    exact_time: "7am",
  })]);
  assertEquals(sessions.length, 1);
  assertEquals(sessions[0].frequency, { type: "daily", interval: 1 });
  assertEquals(sessions[0].exact_time, null);
  assertEquals(sessions[0].needs_review, true);
});
