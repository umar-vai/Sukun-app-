import { assertEquals, assertThrows } from "jsr:@std/assert@1";
import { parsePatientSignInInput } from "./validation.ts";

Deno.test("normalizes a valid patient ID", () => {
  assertEquals(
    parsePatientSignInInput({ patient_code: " sl-test-1 ", password: "Pass-1234" }),
    { patientCode: "SL-TEST-1", password: "Pass-1234" },
  );
});

Deno.test("rejects malformed identifiers", () => {
  assertThrows(() =>
    parsePatientSignInInput({ patient_code: "bad code", password: "Pass-1234" })
  );
});
