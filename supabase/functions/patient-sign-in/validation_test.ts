import { assertEquals, assertThrows } from "jsr:@std/assert@1";
import { parsePatientSignInInput } from "./validation.ts";

Deno.test("normalizes a valid patient ID", () => {
  assertEquals(
    parsePatientSignInInput({
      patient_code: " sl-test-1 ",
      password: "Pass-1234",
    }),
    {
      identifier: "SL-TEST-1",
      identifierKind: "patient_code",
      password: "Pass-1234",
    },
  );
});

Deno.test("normalizes a patient phone identifier", () => {
  assertEquals(
    parsePatientSignInInput({
      identifier: "+880 1712-345678",
      password: "Pass-1234",
    }),
    {
      identifier: "+8801712345678",
      identifierKind: "phone",
      password: "Pass-1234",
    },
  );
});

Deno.test("rejects malformed identifiers", () => {
  assertThrows(() =>
    parsePatientSignInInput({ patient_code: "bad code", password: "Pass-1234" })
  );
});

Deno.test("normalizes local Bangladesh phone number to E.164", () => {
  assertEquals(
    parsePatientSignInInput({
      identifier: "01712345678",
      password: "Pass-1234",
    }),
    {
      identifier: "+8801712345678",
      identifierKind: "phone",
      password: "Pass-1234",
    },
  );
});

Deno.test("normalizes Bangladesh phone number with unprefixed country code", () => {
  assertEquals(
    parsePatientSignInInput({
      identifier: "8801712345678",
      password: "Pass-1234",
    }),
    {
      identifier: "+8801712345678",
      identifierKind: "phone",
      password: "Pass-1234",
    },
  );
});

Deno.test("preserves hyphenated Sukun patient ID", () => {
  assertEquals(
    parsePatientSignInInput({
      identifier: " sl-2026-test1 ",
      password: "Pass-1234",
    }),
    {
      identifier: "SL-2026-TEST1",
      identifierKind: "patient_code",
      password: "Pass-1234",
    },
  );
});
