import { assertEquals } from "jsr:@std/assert@1";
import { createInternalPatientEmail } from "./auth-identity.ts";

Deno.test("creates the migration email from an existing auth user ID", () => {
  assertEquals(
    createInternalPatientEmail("9eafe55b-f31d-4a43-b161-d6e97b4d1bb6"),
    "patient-9eafe55bf31d4a43b161d6e97b4d1bb6@patients.auth.sukunlife.invalid",
  );
});
