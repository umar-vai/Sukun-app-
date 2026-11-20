// Server-to-server authentication for the CRM/ERP backend.
//
// The CRM signs every request with HMAC-SHA256 using a shared secret that
// lives only in the CRM backend and in this function's secrets. Browsers and
// the Flutter app never see it. Pure Web Crypto, no runtime globals, so it
// runs in Deno (Edge Functions) and Node (tests).
//
// Canonical string signed by the caller:
//   "v1\n" + timestamp + "\n" + requestId + "\n" + METHOD + "\n" +
//   pathAndQuery + "\n" + sha256hex(rawBody)
//
// Headers:
//   X-Sukun-Key-Id      identifies which secret signed (supports rotation)
//   X-Sukun-Timestamp   unix seconds; rejected outside the tolerance window
//   X-Sukun-Request-Id  caller generated id, bound into the signature
//   X-Sukun-Signature   "v1=" + lowercase hex HMAC
//
// Replay: a captured POST can only re-send the same event, which the database
// treats idempotently (event_id + payload hash). The timestamp window limits
// how long a captured request stays usable at all.

const encoder = new TextEncoder();

export type CrmAuthFailure =
  | "missing_headers"
  | "unknown_key"
  | "bad_timestamp"
  | "timestamp_out_of_window"
  | "bad_signature";

export type CrmAuthResult =
  | { ok: true; keyId: string; requestId: string }
  | { ok: false; reason: CrmAuthFailure };

export function toHex(bytes: ArrayBuffer): string {
  return Array.from(new Uint8Array(bytes))
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
}

export async function sha256Hex(data: string): Promise<string> {
  return toHex(await crypto.subtle.digest("SHA-256", encoder.encode(data)));
}

export async function hmacHex(
  secret: string,
  message: string,
): Promise<string> {
  const key = await crypto.subtle.importKey(
    "raw",
    encoder.encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  return toHex(await crypto.subtle.sign("HMAC", key, encoder.encode(message)));
}

/** Constant-time comparison of two equal-purpose hex strings. */
export function timingSafeEqual(a: string, b: string): boolean {
  const left = encoder.encode(a);
  const right = encoder.encode(b);
  let diff = left.length ^ right.length;
  const length = Math.max(left.length, right.length);
  for (let i = 0; i < length; i++) {
    diff |= (left[i] ?? 0) ^ (right[i] ?? 0);
  }
  return diff === 0;
}

export async function canonicalString(input: {
  timestamp: string;
  requestId: string;
  method: string;
  pathAndQuery: string;
  body: string;
}): Promise<string> {
  return [
    "v1",
    input.timestamp,
    input.requestId,
    input.method.toUpperCase(),
    input.pathAndQuery,
    await sha256Hex(input.body),
  ].join("\n");
}

/** Used by tests and by the .NET handoff examples to compute a signature. */
export async function signRequest(input: {
  secret: string;
  timestamp: string;
  requestId: string;
  method: string;
  pathAndQuery: string;
  body: string;
}): Promise<string> {
  return "v1=" + await hmacHex(input.secret, await canonicalString(input));
}

export function parseKeyMap(raw: string | undefined): Map<string, string> {
  const keys = new Map<string, string>();
  if (!raw) return keys;
  const parsed = JSON.parse(raw) as Record<string, unknown>;
  for (const [id, secret] of Object.entries(parsed)) {
    // Secrets shorter than 32 characters are refused: they are guessable.
    if (typeof secret === "string" && secret.length >= 32 && id.length <= 64) {
      keys.set(id, secret);
    }
  }
  return keys;
}

export async function verifyCrmRequest(input: {
  method: string;
  pathAndQuery: string;
  body: string;
  headers: { get(name: string): string | null };
  keys: Map<string, string>;
  nowSeconds: number;
  toleranceSeconds?: number;
}): Promise<CrmAuthResult> {
  const keyId = input.headers.get("x-sukun-key-id");
  const timestamp = input.headers.get("x-sukun-timestamp");
  const requestId = input.headers.get("x-sukun-request-id");
  const signature = input.headers.get("x-sukun-signature");
  if (!keyId || !timestamp || !requestId || !signature) {
    return { ok: false, reason: "missing_headers" };
  }
  if (requestId.length > 128 || !/^[A-Za-z0-9._:-]+$/.test(requestId)) {
    return { ok: false, reason: "missing_headers" };
  }
  const secret = input.keys.get(keyId);
  if (!secret) return { ok: false, reason: "unknown_key" };

  if (!/^[0-9]{9,12}$/.test(timestamp)) {
    return { ok: false, reason: "bad_timestamp" };
  }
  const tolerance = input.toleranceSeconds ?? 300;
  if (Math.abs(input.nowSeconds - Number(timestamp)) > tolerance) {
    return { ok: false, reason: "timestamp_out_of_window" };
  }

  const expected = await signRequest({
    secret,
    timestamp,
    requestId,
    method: input.method,
    pathAndQuery: input.pathAndQuery,
    body: input.body,
  });
  if (!timingSafeEqual(expected, signature)) {
    return { ok: false, reason: "bad_signature" };
  }
  return { ok: true, keyId, requestId };
}
