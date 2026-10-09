import { assertEquals, assertRejects } from "jsr:@std/assert@1";
import { hashedLimiterKey, trustedClientIp } from "./rate-limit.ts";

Deno.test("HMAC keys are stable and isolated by namespace", async () => {
  const secret = "test-only-secret-not-for-production-123456789";
  const first = await hashedLimiterKey(secret, "ip", "203.0.113.9");
  const again = await hashedLimiterKey(secret, "ip", "203.0.113.9");
  const identity = await hashedLimiterKey(secret, "identity", "203.0.113.9");
  assertEquals(first, again);
  assertEquals(first.length, 64);
  if (first === identity) throw new Error("Namespace separation failed");
});

Deno.test("missing secret fails closed", async () => {
  await assertRejects(() => hashedLimiterKey("short", "ip", "203.0.113.9"));
});

Deno.test("only trusted proxy IP header is accepted", () => {
  const req = new Request("https://example.test", {
    headers: {
      "cf-connecting-ip": "203.0.113.9",
      "x-forwarded-for": "10.0.0.1",
    },
  });
  assertEquals(trustedClientIp(req), "203.0.113.9");
  const forged = new Request("https://example.test", {
    headers: { "x-forwarded-for": "203.0.113.9" },
  });
  let rejected = false;
  try {
    trustedClientIp(forged);
  } catch {
    rejected = true;
  }
  assertEquals(rejected, true);
});
