import { assertEquals } from "jsr:@std/assert@1";
import { RestGeminiClient } from "./gemini-client.ts";

Deno.test("text action parsing uses Interactions API", async () => {
  let url = "";
  let body: Record<string, unknown> = {};
  const fetcher: typeof fetch = async (input, init) => {
    url = String(input);
    body = JSON.parse(String(init?.body)) as Record<string, unknown>;
    return new Response(
      JSON.stringify({
        output_text:
          '{"source_text":"সকাল আয়াতুল কুরসি ৩ বার পড়বেন।","actions":[{"type":"amal","title":"Ayatul Kursi","instruction":"৩ বার পড়বেন","count_target":3,"duration_minutes":null,"frequency":{"type":"daily","interval":1},"time_window":"morning","exact_time":null,"resource_match_query":"Ayatul Kursi","source_evidence":"সকাল আয়াতুল কুরসি ৩ বার পড়বেন।","confidence":0.95,"needs_review":false,"ambiguities":[]}]}',
      }),
      { status: 200, headers: { "Content-Type": "application/json" } },
    );
  };

  const client = new RestGeminiClient(fetcher);
  const result = await client.generate({
    apiKey: "test-key",
    model: "gemini-3.5-flash-lite",
    prescriptionText: "সকাল আয়াতুল কুরসি ৩ বার পড়বেন।",
    timeoutMs: 1000,
  });

  assertEquals(
    url,
    "https://generativelanguage.googleapis.com/v1beta/interactions",
  );
  assertEquals(result.actions.length, 1);
  assertEquals(body.response_format, undefined);
  assertEquals(typeof body.input, "string");
});
