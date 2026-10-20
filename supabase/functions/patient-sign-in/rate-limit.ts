// Server-side HMAC keys; never store plaintext IP or patient identifier.
export async function hashedLimiterKey(
  secret: string,
  namespace: "ip" | "identity",
  value: string,
): Promise<string> {
  if (secret.length < 32) {
    throw new Error("Rate limiting secret is not configured");
  }
  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const result = await crypto.subtle.sign(
    "HMAC",
    key,
    new TextEncoder().encode(namespace + ":" + value),
  );
  return [...new Uint8Array(result)].map((n) => n.toString(16).padStart(2, "0"))
    .join("");
}
// Only safe when the ingress demonstrably overwrites/rejects a caller-supplied
// cf-connecting-ip. Verify this on staging before deploying this login handler.
// Never silently fall back to X-Forwarded-For or a caller-controlled identifier.
export function trustedClientIp(request: Request): string {
  const ip = request.headers.get("cf-connecting-ip")?.trim();
  if (!ip || ip.length > 64) {
    throw new Error("Trusted client IP unavailable");
  }

  // Reject legacy/incomplete IPv4 forms (e.g. 127.1 or leading-zero octets).
  // Distinct spellings of the same address must not bypass its HMAC bucket.
  if (/^[0-9.]+$/.test(ip)) {
    const parts = ip.split(".");
    if (
      parts.length !== 4 ||
      parts.some((part) =>
        !/^(0|[1-9][0-9]{0,2})$/.test(part) || Number(part) > 255
      )
    ) {
      throw new Error("Trusted client IP unavailable");
    }
    return parts.join(".");
  }

  // WHATWG URL parsing validates and canonicalizes IPv6, including IPv4-mapped
  // forms, so equivalent compressed/expanded addresses have one limiter key.
  if (!ip.includes(":") || !/^[0-9a-fA-F:.]+$/.test(ip)) {
    throw new Error("Trusted client IP unavailable");
  }
  try {
    const hostname = new URL(`http://[${ip}]/`).hostname;
    if (!hostname.startsWith("[") || !hostname.endsWith("]")) {
      throw new Error("Invalid IPv6");
    }
    return hostname.slice(1, -1);
  } catch {
    throw new Error("Trusted client IP unavailable");
  }
}
