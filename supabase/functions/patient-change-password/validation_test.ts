import { assertEquals, assertThrows } from "jsr:@std/assert@1";
import { parseChangePasswordInput } from "./validation.ts";

Deno.test("accepts a distinct strong-enough replacement", () => {
  assertEquals(
    parseChangePasswordInput({ current_password: "Temp-1234", new_password: "Fresh-5678" }),
    { currentPassword: "Temp-1234", newPassword: "Fresh-5678" },
  );
});

Deno.test("rejects reuse of the temporary password", () => {
  assertThrows(() =>
    parseChangePasswordInput({ current_password: "Temp-1234", new_password: "Temp-1234" })
  );
});
