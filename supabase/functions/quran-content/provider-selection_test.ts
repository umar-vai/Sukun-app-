import { assertEquals } from "jsr:@std/assert";
import { useAttributedPublicQuran } from "./provider-selection.ts";

Deno.test("uses attributed public Quran source when QF keys are missing", () => {
  assertEquals(useAttributedPublicQuran(undefined, undefined, undefined), true);
  assertEquals(useAttributedPublicQuran("production", "", ""), true);
  assertEquals(useAttributedPublicQuran("production", "id", ""), true);
  assertEquals(
    useAttributedPublicQuran("production", undefined, "secret"),
    true,
  );
});

Deno.test("retains approved Quran Foundation when both credentials exist", () => {
  assertEquals(useAttributedPublicQuran("production", "id", "secret"), false);
  assertEquals(useAttributedPublicQuran("prelive", "id", "secret"), true);
});
