// Retired: Sukun Life now streams approved external media directly.
// This endpoint remains as a 410 tombstone so old cached admin clients cannot
// accidentally upload new public copies. JWT verification stays enabled.
const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, apikey, x-client-info, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Cache-Control": "no-store",
};

Deno.serve((request) => {
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: cors });
  }
  return new Response(
    JSON.stringify({ code: "audio_import_retired" }),
    {
      status: 410,
      headers: { ...cors, "Content-Type": "application/json; charset=utf-8" },
    },
  );
});
