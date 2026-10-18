import { assertEquals } from "jsr:@std/assert";
import { quranCorsHeaders } from "./cors.ts";

Deno.test("Quran chapters and Ruqyah verse audio share the approved app CORS origin", () => {
  const headers = quranCorsHeaders("https://app.sukunlife.com");
  assertEquals(headers["Access-Control-Allow-Origin"], "https://app.sukunlife.com");
  assertEquals(headers["Access-Control-Allow-Methods"], "POST, OPTIONS");
  assertEquals(
    headers["Access-Control-Allow-Headers"],
    "authorization, x-client-info, apikey, content-type",
  );
  assertEquals(headers["Vary"], "Origin");
});

Deno.test("existing Umar GitHub Pages preview and localhost stay supported", () => {
  for (const origin of [
    "https://umar-vai.github.io",
    "http://localhost:3000",
    "http://localhost:5173",
    "http://localhost:8080",
  ]) {
    assertEquals(quranCorsHeaders(origin)["Access-Control-Allow-Origin"], origin);
  }
});

Deno.test("never grant CORS to spoofed, http or unapproved origins", () => {
  for (const origin of [
    null,
    "http://app.sukunlife.com",
    "https://app.sukunlife.com.evil.example",
    "https://sukunlife.com",
    "https://attacker.example",
    "https://umar-vai.github.io.evil.example",
    "null",
  ]) {
    assertEquals(quranCorsHeaders(origin)["Access-Control-Allow-Origin"], undefined);
  }
});
