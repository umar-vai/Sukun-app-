import { assertEquals, assertMatch } from "jsr:@std/assert@1";
import { createInternalPatientEmail } from "./auth-identity.ts";

Deno.test("creates a stable private patient auth email from a seed", () => {
  assertEquals(
    createInternalPatientEmail("10000000-0000-4000-8000-000000000001"),
    "patient-10000000000040008000000000000001@patients.auth.sukunlife.invalid",
  );
});

Deno.test("creates an opaque private patient auth email by default", () => {
  assertMatch(
    createInternalPatientEmail(),
    /^patient-[0-9a-f]{32}@patients\.auth\.sukunlife\.invalid$/,
  );
});
