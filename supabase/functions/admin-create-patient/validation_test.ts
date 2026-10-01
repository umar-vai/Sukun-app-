import { assertEquals, assertThrows } from "jsr:@std/assert@1";
import { parseCreatePatientInput } from "./validation.ts";

Deno.test("normalizes valid patient input", () => {
  const input = parseCreatePatientInput({
    full_name: "  Amina Rahman  ",
    phone: "+880 1712-345678",
    temporary_password: "Temporary-123",
    patient_code: " sl-dhaka-12 ",
    request_id: "10000000-0000-4000-8000-000000000001",
  });

  assertEquals(input.fullName, "Amina Rahman");
  assertEquals(input.phone, "+8801712345678");
  assertEquals(input.patientCode, "SL-DHAKA-12");
});

Deno.test("rejects ambiguous local phone numbers", () => {
  assertThrows(
    () =>
      parseCreatePatientInput({
        full_name: "Amina Rahman",
        phone: "01712345678",
        temporary_password: "Temporary-123",
        request_id: "10000000-0000-4000-8000-000000000001",
      }),
    Error,
    "international format",
  );
});

Deno.test("rejects short temporary passwords", () => {
  assertThrows(
    () =>
      parseCreatePatientInput({
        full_name: "Amina Rahman",
        phone: "+8801712345678",
        temporary_password: "short",
        request_id: "10000000-0000-4000-8000-000000000001",
      }),
    Error,
    "between 8 and 72",
  );
});
