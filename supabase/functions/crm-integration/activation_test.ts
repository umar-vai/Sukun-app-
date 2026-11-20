import test from "node:test";
import assert from "node:assert/strict";
import {
  buildActivationLink,
  generateActivationToken,
  generatePatientCode,
  hashActivationToken,
  normalizeBangladeshPhone,
  readWhatsAppConfig,
  sendActivationWhatsApp,
} from "./activation.ts";

test("tokens are long, url safe and unique", () => {
  const a = generateActivationToken();
  const b = generateActivationToken();
  assert.match(a, /^[A-Za-z0-9_-]{43}$/);
  assert.notEqual(a, b);
});

test("only the hash is derivable, 64 hex chars", async () => {
  const hash = await hashActivationToken("abc");
  assert.match(hash, /^[0-9a-f]{64}$/);
  assert.equal(
    hash,
    "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad",
  );
});

test("Bangladesh phone numbers normalise from every spelling", () => {
  for (
    const raw of [
      "01712345678",
      "+8801712345678",
      "8801712345678",
      "008801712345678",
      "+880 1712-345678",
    ]
  ) {
    assert.deepEqual(normalizeBangladeshPhone(raw), {
      e164: "+8801712345678",
      digits: "8801712345678",
    });
  }
});

test("invalid phone numbers are refused", () => {
  for (
    const raw of ["", "12345", "01212345678", "+14155550123", "0171234567"]
  ) {
    assert.equal(normalizeBangladeshPhone(raw), null);
  }
});

test("link keeps the token in the fragment", () => {
  assert.equal(
    buildActivationLink("https://app.sukunlife.com/", "T"),
    "https://app.sukunlife.com/activate#token=T",
  );
});

test("patient codes match the existing format", () => {
  assert.match(generatePatientCode(), /^SL-\d{4}-[A-Z2-9]{6}$/);
});

test("WhatsApp is reported as not configured, never faked", async () => {
  assert.equal(readWhatsAppConfig(() => undefined), null);
  assert.equal(
    await sendActivationWhatsApp({ config: null, toDigits: "880", link: "x" }),
    "not_configured",
  );
});

test("WhatsApp request shape and failure handling", async () => {
  const config = readWhatsAppConfig((n) =>
    ({
      WHATSAPP_ACCESS_TOKEN: "tok",
      WHATSAPP_PHONE_NUMBER_ID: "123",
      WHATSAPP_ACTIVATION_TEMPLATE: "activation",
    } as Record<string, string>)[n]
  );
  let seen: { url: string; body: Record<string, unknown> } | undefined;
  const ok = (async (url: string, init: { body: string }) => {
    seen = { url, body: JSON.parse(init.body) };
    return new Response("{}", { status: 200 });
  }) as unknown as typeof fetch;
  assert.equal(
    await sendActivationWhatsApp({
      config,
      toDigits: "8801712345678",
      link: "https://x/activate#token=T",
      fetchImpl: ok,
    }),
    "sent",
  );
  assert.equal(seen?.body.to, "8801712345678");
  assert.match(seen!.url, /\/123\/messages$/);
  const down = (async () => {
    throw new Error("network");
  }) as unknown as typeof fetch;
  assert.equal(
    await sendActivationWhatsApp({
      config,
      toDigits: "88",
      link: "x",
      fetchImpl: down,
    }),
    "failed",
  );
});
