import { assertEquals } from "jsr:@std/assert@1";
import { isVerifiedCurrentPassword } from "./password-proof.ts";

const userA = "11111111-1111-4111-8111-111111111111";
const userB = "22222222-2222-4222-8222-222222222222";

Deno.test("correct password proof must also match the authenticated Patient", () => {
  assertEquals(
    isVerifiedCurrentPassword(
      {
        user: { id: userA },
        session: { access_token: "synthetic" },
        error: null,
      },
      userA,
    ),
    true,
  );
});

Deno.test("wrong password is rejected even if bearer session was valid", () => {
  assertEquals(
    isVerifiedCurrentPassword(
      { user: null, session: null, error: new Error("invalid credentials") },
      userA,
    ),
    false,
  );
});

Deno.test("proof for another account cannot rotate Patient password", () => {
  assertEquals(
    isVerifiedCurrentPassword(
      {
        user: { id: userB },
        session: { access_token: "synthetic" },
        error: null,
      },
      userA,
    ),
    false,
  );
});

Deno.test("missing independent sign-in session fails closed", () => {
  assertEquals(
    isVerifiedCurrentPassword(
      { user: { id: userA }, session: null, error: null },
      userA,
    ),
    false,
  );
});

Deno.test("Auth API error overrides otherwise plausible proof", () => {
  assertEquals(
    isVerifiedCurrentPassword(
      {
        user: { id: userA },
        session: { access_token: "synthetic" },
        error: new Error("sign-in unavailable"),
      },
      userA,
    ),
    false,
  );
});
