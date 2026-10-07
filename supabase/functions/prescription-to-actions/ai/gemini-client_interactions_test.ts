import { assertEquals } from "jsr:@std/assert@1";
import { RestGeminiClient } from "./gemini-client.ts";

Deno.test("document extraction uses Interactions API structured output", async () => {
  let url = "";
  let body: Record<string, unknown> = {};
  const fetcher: typeof fetch = async (input, init) => {
    url = String(input);
    body = JSON.parse(String(init?.body)) as Record<string, unknown>;
    return new Response(
      JSON.stringify({
        output_text: JSON.stringify({
          source_text: "সকাল আয়াতুল কুরসি ৩ বার পড়বেন।",
          actions: [{
            type: "amal",
            title: "Ayatul Kursi",
            instruction: "৩ বার পড়বেন",
            count_target: 3,
            duration_minutes: null,
            frequency: { type: "daily", interval: 1 },
            time_window: "morning",
            exact_time: null,
            resource_match_query: "Ayatul Kursi",
            source_evidence: "সকাল আয়াতুল কুরসি ৩ বার পড়বেন।",
            confidence: 0.95,
            needs_review: false,
            ambiguities: [],
          }],
        }),
      }),
      { status: 200, headers: { "Content-Type": "application/json" } },
    );
  };

  const client = new RestGeminiClient(fetcher);
  const result = await client.generate({
    apiKey: "test-key",
    model: "gemini-3.5-flash-lite",
    prescriptionText: "",
    document: {
      mimeType: "image/jpeg",
      base64Data: "dGVzdA==",
    },
    timeoutMs: 1000,
  });

  assertEquals(
    url,
    "https://generativelanguage.googleapis.com/v1beta2/interactions",
  );
  assertEquals(result.actions.length, 1);
  const formats = body.response_format as Record<string, unknown>[];
  assertEquals(formats.length, 1);
  assertEquals(formats[0].type, "text");
  assertEquals(formats[0].mime_type, "application/json");
  if (!formats[0].schema) {
    throw new Error("Interactions request must include schema.");
  }
  const input = body.input as Record<string, unknown>[];
  assertEquals(input[0].type, "image");
  assertEquals(input[1].type, "text");
});
