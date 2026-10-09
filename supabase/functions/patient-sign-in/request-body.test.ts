import { assertEquals, assertRejects } from "jsr:@std/assert@1";
import { MAX_SIGN_IN_BODY_BYTES, readLimitedJson } from "./request-body.ts";

Deno.test("accepts small patient sign-in JSON", async () => {
  const payload = { identifier: "SL-123", password: "example-pass" };
  const result = await readLimitedJson(
    new Request("https://example.test", {
      method: "POST",
      body: JSON.stringify(payload),
    }),
  );
  assertEquals(result, payload);
});

Deno.test("rejects oversized declared body before parsing", async () => {
  const request = new Request("https://example.test", {
    method: "POST",
    headers: { "content-length": String(MAX_SIGN_IN_BODY_BYTES + 1) },
    body: "{}",
  });
  await assertRejects(
    () => readLimitedJson(request),
    Error,
    "request_too_large",
  );
});

Deno.test("rejects oversized streamed body without content-length", async () => {
  const oversized = "x".repeat(MAX_SIGN_IN_BODY_BYTES + 1);
  const request = new Request("https://example.test", {
    method: "POST",
    body: oversized,
  });
  request.headers.delete("content-length");
  await assertRejects(
    () => readLimitedJson(request),
    Error,
    "request_too_large",
  );
});

Deno.test("rejects malformed JSON", async () => {
  const request = new Request("https://example.test", {
    method: "POST",
    body: "{",
  });
  await assertRejects(() => readLimitedJson(request), SyntaxError);
});
