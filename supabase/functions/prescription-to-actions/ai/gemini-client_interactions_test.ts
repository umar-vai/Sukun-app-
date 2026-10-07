import { assertEquals } from "jsr:@std/assert@1";
import { RestGeminiClient } from "./gemini-client.ts";

Deno.test("document transcription uses v1beta Interactions without structured output", async () => {
  let url = "";
  let body: Record<string, unknown> = {};
  const fetcher: typeof fetch = async (input, init) => {
    url = String(input);
    body = JSON.parse(String(init?.body)) as Record<string, unknown>;
    return new Response(
      JSON.stringify({
        output_text: "সকাল আয়াতুল কুরসি ৩ বার পড়বেন।",
      }),
      { status: 200, headers: { "Content-Type": "application/json" } },
    );
  };

  const client = new RestGeminiClient(fetcher);
  const result = await client.transcribeDocument({
    apiKey: "test-key",
    model: "gemini-3.5-flash-lite",
    document: {
      mimeType: "image/jpeg",
      base64Data: "dGVzdA==",
    },
    timeoutMs: 1000,
  });

  assertEquals(
    url,
    "https://generativelanguage.googleapis.com/v1beta/interactions",
  );
  assertEquals(result, "সকাল আয়াতুল কুরসি ৩ বার পড়বেন।");
  assertEquals(body.response_format, undefined);
  const input = body.input as Record<string, unknown>[];
  assertEquals(input[0].type, "text");
  assertEquals(input[1].type, "image");
});
