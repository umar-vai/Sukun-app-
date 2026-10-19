import { assertEquals, assertRejects, assertThrows } from "jsr:@std/assert@1";
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

function requestWithTrustedIp(ip: string): Request {
  return new Request("https://example.test", {
    headers: { "cf-connecting-ip": ip },
  });
}

Deno.test("IPv6 aliases share one rate-limit bucket", async () => {
  const secret = "test-only-secret-not-for-production-123456789";
  const compressed = trustedClientIp(requestWithTrustedIp("2001:db8::1"));
  const expanded = trustedClientIp(
    requestWithTrustedIp("2001:0DB8:0:0:0:0:0:1"),
  );
  assertEquals(compressed, "2001:db8::1");
  assertEquals(expanded, compressed);
  assertEquals(
    await hashedLimiterKey(secret, "ip", compressed),
    await hashedLimiterKey(secret, "ip", expanded),
  );
  assertEquals(
    trustedClientIp(requestWithTrustedIp("::ffff:192.0.2.1")),
    "::ffff:c000:201",
  );
});

Deno.test("reject malformed or non-canonical proxy IP headers", () => {
  for (
    const invalid of [
      "127.1",
      "001.2.3.4",
      "256.1.2.3",
      "1.2.3.4, 5.6.7.8",
      "2001:db8:::1",
      "2001:db8::1%eth0",
      "not-an-ip",
      "",
    ]
  ) {
    assertThrows(
      () => trustedClientIp(requestWithTrustedIp(invalid)),
      Error,
      "Trusted client IP unavailable",
    );
  }
  assertEquals(
    trustedClientIp(requestWithTrustedIp("203.0.113.9")),
    "203.0.113.9",
  );
});
