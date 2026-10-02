import { assertEquals, assertThrows } from "jsr:@std/assert@1";
import { parseGenerateActionsInput } from "./validation.ts";

Deno.test("accepts only UUID identifiers for generation", () => {
  const input = parseGenerateActionsInput({
    prescription_id: "10000000-0000-4000-8000-000000000001",
    care_plan_id: "20000000-0000-4000-8000-000000000001",
    request_id: "30000000-0000-4000-8000-000000000001",
  });
  assertEquals(input.carePlanId, "20000000-0000-4000-8000-000000000001");
});

Deno.test("rejects raw text and missing identifiers", () => {
  assertThrows(
    () => parseGenerateActionsInput({ raw_text: "sensitive prescription" }),
    Error,
    "prescription identifier",
  );
});
