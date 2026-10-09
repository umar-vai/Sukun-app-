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
export function trustedClientIp(request: Request): string {
  // Never trust caller-supplied x-forwarded-for without proxy sanitization.
  const ip = request.headers.get("cf-connecting-ip")?.trim();
  if (!ip || ip.length > 64 || !/^[0-9a-fA-F:.]+$/.test(ip)) {
    throw new Error("Trusted client IP unavailable");
  }
  return ip.toLowerCase();
}
