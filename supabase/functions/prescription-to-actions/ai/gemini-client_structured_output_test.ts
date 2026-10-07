import { assertEquals } from "jsr:@std/assert@1";
import { RestGeminiClient } from "./gemini-client.ts";

Deno.test("fallback GenerateContent request keeps the JSON schema", async () => {
  const bodies: Record<string, unknown>[] = [];
  let call = 0;
  const fetcher: typeof fetch = async (_input, init) => {
    call += 1;
    bodies.push(JSON.parse(String(init?.body)) as Record<string, unknown>);
    if (call === 1) {
      return new Response(
        JSON.stringify({ error: { status: "INVALID_ARGUMENT" } }),
        {
          status: 400,
          headers: { "Content-Type": "application/json" },
        },
      );
    }
    return new Response(
      JSON.stringify({
        candidates: [{
          content: {
            parts: [{
              text: JSON.stringify({
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
            }],
          },
        }],
      }),
      { status: 200, headers: { "Content-Type": "application/json" } },
    );
  };

  const client = new RestGeminiClient(fetcher);
  const result = await client.generate({
    apiKey: "test-key",
    model: "test-model",
    prescriptionText: "source",
    timeoutMs: 1000,
  });

  assertEquals(result.actions.length, 1);
  assertEquals(bodies.length, 2);
  const secondConfig = bodies[1].generationConfig as Record<string, unknown>;
  assertEquals(secondConfig.responseMimeType, "application/json");
  if (!secondConfig.responseSchema) {
    throw new Error("Fallback request must include responseSchema.");
  }
});
