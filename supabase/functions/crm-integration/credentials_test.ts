import test from "node:test";
import assert from "node:assert/strict";
import {
  generatePatientCode,
  generateTemporaryPassword,
  normalizeBangladeshPhone,
} from "./credentials.ts";

test("temporary passwords are 12 unambiguous characters and differ", () => {
  const seen = new Set<string>();
  for (let i = 0; i < 200; i++) {
    const p = generateTemporaryPassword();
    assert.match(
      p,
      /^[ABCDEFGHJKMNPQRSTUVWXYZabcdefghjkmnpqrstuvwxyz23456789]{12}$/,
    );
    seen.add(p);
  }
  assert.equal(seen.size, 200);
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

test("patient codes match the existing format", () => {
  assert.match(generatePatientCode(), /^SL-\d{4}-[A-Z2-9]{6}$/);
});
