import {
  assertEquals,
  assertMatch,
  assertNotEquals,
  assertRejects,
  assertThrows,
} from "jsr:@std/assert@1";
import {
  hashedLimiterKey,
  trustedClientIp,
} from "./rate-limit.ts";
import {
  MAX_SIGN_IN_BODY_BYTES,
  readLimitedJson,
} from "./request-body.ts";

const secret = "only-synthetic-test-secret-32-plus-chars";

Deno.test("rate limit HMAC is deterministic and never exposes a raw key", async () => {
  const first = await hashedLimiterKey(secret, "ip", "192.0.2.15");
  const again = await hashedLimiterKey(secret, "ip", "192.0.2.15");
  assertEquals(first, again);
  assertMatch(first, /^[a-f0-9]{64}$/);
  assertNotEquals(first, "192.0.2.15");
});

Deno.test("IP and identity HMAC namespaces cannot share a bucket", async () => {
  const ip = await hashedLimiterKey(secret, "ip", "same-test-value");
  const identity = await hashedLimiterKey(
    secret,
    "identity",
    "same-test-value",
  );
  assertNotEquals(ip, identity);
});

Deno.test("rate limiting fails closed without a strong secret", async () => {
  await assertRejects(
    () => hashedLimiterKey("short", "identity", "SL-TEST-1"),
    Error,
    "Rate limiting secret is not configured",
  );
});

Deno.test("client IP comes only from the configured proxy header", () => {
  const request = new Request("https://example.invalid/login", {
    headers: {
      "cf-connecting-ip": "2001:db8::1",
      "x-forwarded-for": "203.0.113.99",
    },
  });
  assertEquals(trustedClientIp(request), "2001:db8::1");
  assertThrows(
    () =>
      trustedClientIp(
        new Request("https://example.invalid/login", {
          headers: { "x-forwarded-for": "203.0.113.99" },
        }),
      ),
    Error,
    "Trusted client IP unavailable",
  );
});

Deno.test("invalid or empty proxy IP fails closed", () => {
  for (const ip of ["", "not-an-ip", "203.0.113.1, 192.0.2.2"]) {
    assertThrows(
      () =>
        trustedClientIp(
          new Request("https://example.invalid/login", {
            headers: { "cf-connecting-ip": ip },
          }),
        ),
      Error,
      "Trusted client IP unavailable",
    );
  }
});

Deno.test("accepts normal small sign-in JSON", async () => {
  const payload = { patient_code: "SL-TEST-1", password: "ExamplePass123" };
  const request = new Request("https://example.invalid/login", {
    method: "POST",
    body: JSON.stringify(payload),
  });
  assertEquals(await readLimitedJson(request), payload);
});

Deno.test("rejects an oversized claimed Content-Length before reading", async () => {
  const request = new Request("https://example.invalid/login", {
    method: "POST",
    headers: {
      "content-length": String(MAX_SIGN_IN_BODY_BYTES + 1),
    },
    body: "{}",
  });
  await assertRejects(
    () => readLimitedJson(request),
    Error,
    "request_too_large",
  );
});

Deno.test("rejects oversized streaming body without Content-Length", async () => {
  const request = new Request("https://example.invalid/login", {
    method: "POST",
    body: "x".repeat(MAX_SIGN_IN_BODY_BYTES + 1),
  });
  await assertRejects(
    () => readLimitedJson(request),
    Error,
    "request_too_large",
  );
});

Deno.test("rejects missing or malformed JSON", async () => {
  const missing = new Request("https://example.invalid/login", {
    method: "POST",
  });
  await assertRejects(() => readLimitedJson(missing), SyntaxError);

  const malformed = new Request("https://example.invalid/login", {
    method: "POST",
    body: "{not-json}",
  });
  await assertRejects(() => readLimitedJson(malformed), SyntaxError);
});
