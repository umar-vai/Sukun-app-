// The Quran proxy is a public read-only API, not a credential endpoint.
// Never reflect an arbitrary Origin or allow unrelated websites.
export const quranAllowedOrigins = new Set([
  "https://app.sukunlife.com",
  "https://umar-vai.github.io",
  "http://localhost:3000",
  "http://localhost:5173",
  "http://localhost:8080",
]);

export function quranCorsHeaders(
  origin: string | null,
): Record<string, string> {
  const headers: Record<string, string> = {
    "Access-Control-Allow-Methods": "POST, OPTIONS",
    "Access-Control-Allow-Headers":
      "authorization, x-client-info, apikey, content-type",
    "Vary": "Origin",
  };
  if (origin !== null && quranAllowedOrigins.has(origin)) {
    headers["Access-Control-Allow-Origin"] = origin;
  }
  return headers;
}
