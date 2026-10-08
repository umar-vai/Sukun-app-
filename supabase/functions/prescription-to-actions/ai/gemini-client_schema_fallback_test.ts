import { assertEquals } from "jsr:@std/assert@1";
import { RestGeminiClient } from "./gemini-client.ts";

Deno.test("HTTP 400 structured output retries without response schema", async () => {
  const bodies: Record<string, unknown>[] = [];
  const events: Record<string, unknown>[] = [];
  let call = 0;
  const fetcher: typeof fetch = async (_input, init) => {
    call += 1;
    bodies.push(JSON.parse(String(init?.body)) as Record<string, unknown>);
    if (call === 1) {
      return Response.json(
        { error: { code: 400, message: "invalid response schema" } },
        { status: 400 },
      );
    }
    return Response.json({
      output_text: "{\"source_text\":null,\"actions\":[{\"type\":\"amal\",\"title\":\"Ayatul Kursi\",\"instruction\":\"৩ বার পড়বেন\",\"count_target\":3,\"duration_minutes\":null,\"frequency\":{\"type\":\"daily\",\"interval\":1},\"time_window\":\"morning\",\"exact_time\":null,\"resource_match_query\":\"Ayatul Kursi\",\"source_evidence\":\"সকাল আয়াতুল কুরসি ৩ বার পড়বেন।\",\"confidence\":0.95,\"needs_review\":false,\"ambiguities\":[]}]}",
    });
  };

  const client = new RestGeminiClient(
    fetcher,
    (event) => events.push(event),
  );
  const result = await client.generate({
    apiKey: "test-key",
    model: "gemini-3.5-flash-lite",
    prescriptionText: "source",
    timeoutMs: 1000,
  });

  assertEquals(result.actions.length, 1);
  assertEquals(bodies.length, 2);
  if (!bodies[0].response_format) {
    throw new Error("First request must include response_format.");
  }
  assertEquals(bodies[1].response_format, undefined);
  assertEquals(events[0].event, "ai_structured_output_fallback");
});
