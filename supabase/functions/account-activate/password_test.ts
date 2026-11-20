import test from "node:test";
import assert from "node:assert/strict";
import { validateNewPassword, validateToken } from "./password.ts";

test("password limits", () => {
  assert.equal(validateNewPassword("short"), null);
  assert.equal(validateNewPassword("aaaaaaaaaa"), null);
  assert.equal(validateNewPassword("x".repeat(73)), null);
  assert.equal(validateNewPassword(1234), null);
  assert.equal(validateNewPassword("Good-pass-12"), "Good-pass-12");
});

test("token shape", () => {
  assert.equal(validateToken("a".repeat(43)), "a".repeat(43));
  assert.equal(validateToken("a".repeat(42)), null);
  assert.equal(validateToken("a b" + "a".repeat(40)), null);
  assert.equal(validateToken(undefined), null);
});
