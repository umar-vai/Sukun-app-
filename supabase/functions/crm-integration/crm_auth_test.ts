import test from "node:test";
import assert from "node:assert/strict";
import {
  parseKeyMap,
  signRequest,
  timingSafeEqual,
  verifyCrmRequest,
} from "./crm_auth.ts";

const secret = "s".repeat(40);
const keys = new Map([["crm-2026-11", secret]]);
const body = JSON.stringify({ event_id: "evt-1" });
const now = 1_790_000_000;

async function headersFor(overrides: Record<string, string> = {}) {
  const base: Record<string, string> = {
    "x-sukun-key-id": "crm-2026-11",
    "x-sukun-timestamp": String(now),
    "x-sukun-request-id": "req-1",
    "x-sukun-signature": await signRequest({
      secret,
      timestamp: String(now),
      requestId: "req-1",
      method: "POST",
      pathAndQuery: "/crm-integration/prescriptions",
      body,
    }),
    ...overrides,
  };
  return { get: (n: string) => base[n.toLowerCase()] ?? null };
}

const verify = async (
  headers: { get(n: string): string | null },
  extra: Partial<Parameters<typeof verifyCrmRequest>[0]> = {},
) =>
  verifyCrmRequest({
    method: "POST",
    pathAndQuery: "/crm-integration/prescriptions",
    body,
    headers,
    keys,
    nowSeconds: now,
    ...extra,
  });

test("accepts a correctly signed request", async () => {
  const result = await verify(await headersFor());
  assert.equal(result.ok, true);
});

test("rejects a tampered body", async () => {
  const result = await verify(await headersFor(), { body: body + " " });
  assert.deepEqual(result, { ok: false, reason: "bad_signature" });
});

test("rejects a different path or method", async () => {
  assert.equal(
    (await verify(await headersFor(), { pathAndQuery: "/x" })).ok,
    false,
  );
  assert.equal((await verify(await headersFor(), { method: "GET" })).ok, false);
});

test("rejects missing headers and unknown keys", async () => {
  const none = { get: () => null };
  assert.deepEqual(await verify(none), {
    ok: false,
    reason: "missing_headers",
  });
  const unknown = await headersFor({ "x-sukun-key-id": "other" });
  assert.deepEqual(await verify(unknown), { ok: false, reason: "unknown_key" });
});

test("rejects stale and future timestamps", async () => {
  assert.deepEqual(
    await verify(await headersFor(), { nowSeconds: now + 301 }),
    { ok: false, reason: "timestamp_out_of_window" },
  );
  assert.deepEqual(
    await verify(await headersFor(), { nowSeconds: now - 301 }),
    { ok: false, reason: "timestamp_out_of_window" },
  );
  assert.equal(
    (await verify(await headersFor(), { nowSeconds: now + 299 })).ok,
    true,
  );
});

test("rejects a malformed timestamp and request id", async () => {
  assert.deepEqual(
    await verify(await headersFor({ "x-sukun-timestamp": "abc" })),
    { ok: false, reason: "bad_timestamp" },
  );
  assert.deepEqual(
    await verify(await headersFor({ "x-sukun-request-id": "bad id!" })),
    { ok: false, reason: "missing_headers" },
  );
});

test("a rotated second key keeps working while the first is retired", async () => {
  const two = new Map(keys);
  two.set("crm-2026-12", "t".repeat(40));
  assert.equal((await verify(await headersFor(), { keys: two })).ok, true);
  two.delete("crm-2026-11");
  assert.deepEqual(
    await verify(await headersFor(), { keys: two }),
    { ok: false, reason: "unknown_key" },
  );
});

test("parseKeyMap refuses short secrets", () => {
  const map = parseKeyMap(JSON.stringify({ a: "short", b: "x".repeat(32) }));
  assert.deepEqual([...map.keys()], ["b"]);
  assert.equal(parseKeyMap(undefined).size, 0);
});

test("timingSafeEqual", () => {
  assert.equal(timingSafeEqual("abc", "abc"), true);
  assert.equal(timingSafeEqual("abc", "abd"), false);
  assert.equal(timingSafeEqual("abc", "abcd"), false);
});
