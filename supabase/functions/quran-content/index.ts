// Quran Foundation Content API proxy. No API credentials are sent to Flutter Web.
// Requires QF_CLIENT_ID, QF_CLIENT_SECRET and optional QF_ENV=prelive|production.
// Quran Foundation prelive only supplies chapters 1-2. Production access is
// required before the 114-chapter catalog can be enabled.
import "jsr:@supabase/functions-js/edge-runtime.d.ts";

const origins = new Set([
  "https://umar-vai.github.io",
  "http://localhost:3000",
  "http://localhost:5173",
  "http://localhost:8080",
]);
const jsonHeaders = { "Content-Type": "application/json; charset=utf-8" };
let cachedToken = "";
let tokenExpiresAt = 0;

function cors(origin: string | null): Record<string, string> {
  return {
    "Access-Control-Allow-Origin": origin && origins.has(origin)
      ? origin
      : "https://umar-vai.github.io",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
    "Access-Control-Allow-Headers":
      "authorization, x-client-info, apikey, content-type",
    "Vary": "Origin",
  };
}
function respond(
  status: number,
  body: unknown,
  origin: string | null,
): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...jsonHeaders, ...cors(origin), "Cache-Control": "no-store" },
  });
}
function upstreamEnvironment() {
  const env = Deno.env.get("QF_ENV") === "production"
    ? "production"
    : "prelive";
  return env === "production"
    ? {
      auth: "https://oauth2.quran.foundation",
      api: "https://apis.quran.foundation",
      env,
    }
    : {
      auth: "https://prelive-oauth2.quran.foundation",
      api: "https://apis-prelive.quran.foundation",
      env,
    };
}
async function token(
  clientId: string,
  clientSecret: string,
  auth: string,
): Promise<string> {
  if (cachedToken && Date.now() < tokenExpiresAt) return cachedToken;
  const response = await fetch(auth + "/oauth2/token", {
    method: "POST",
    headers: {
      Authorization: "Basic " + btoa(clientId + ":" + clientSecret),
      "Content-Type": "application/x-www-form-urlencoded",
    },
    body: "grant_type=client_credentials&scope=content",
  });
  if (!response.ok) {
    throw new Error(
      "Quran Foundation OAuth unavailable (" + response.status + ")",
    );
  }
  const payload = await response.json();
  if (typeof payload.access_token !== "string") {
    throw new Error("Missing Quran Foundation token");
  }
  cachedToken = payload.access_token;
  tokenExpiresAt = Date.now() +
    Math.max(60, (Number(payload.expires_in) || 3600) - 120) * 1000;
  return cachedToken;
}
async function contentGet(
  path: string,
  credentials: { id: string; secret: string; auth: string; api: string },
) {
  for (let attempt = 0; attempt < 2; attempt++) {
    const accessToken = await token(
      credentials.id,
      credentials.secret,
      credentials.auth,
    );
    const response = await fetch(credentials.api + "/content/api/v4/" + path, {
      headers: { "x-auth-token": accessToken, "x-client-id": credentials.id },
    });
    if (response.status === 401 && attempt === 0) {
      cachedToken = "";
      tokenExpiresAt = 0;
      continue;
    }
    if (!response.ok) {
      throw new Error(
        "Quran Foundation content unavailable (" + response.status + ")",
      );
    }
    return await response.json();
  }
  throw new Error("Quran Foundation authorization failed");
}
Deno.serve(async (request: Request) => {
  const origin = request.headers.get("origin");
  if (request.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: cors(origin) });
  }
  if (request.method !== "POST") {
    return respond(405, { error: "Method not allowed" }, origin);
  }
  const id = Deno.env.get("QF_CLIENT_ID");
  const secret = Deno.env.get("QF_CLIENT_SECRET");
  if (!id || !secret) {
    return respond(503, {
      error: "Quran Foundation integration not configured",
      code: "qf_not_configured",
    }, origin);
  }

  try {
    const data = await request.json();
    const { auth, api, env } = upstreamEnvironment();
    const c = { id, secret, auth, api };
    if (data?.action === "chapters") {
      const response = await contentGet("chapters?language=bn", c);
      return respond(200, {
        chapters: response.chapters ?? [],
        environment: env,
      }, origin);
    }
    if (data?.action === "verses") {
      const chapter = Number(data.chapter);
      const page = Number(data.page ?? 1);
      if (
        !Number.isInteger(chapter) || chapter < 1 || chapter > 114 ||
        !Number.isInteger(page) || page < 1 || page > 20
      ) {
        return respond(400, { error: "Invalid surah or page" }, origin);
      }
      // Discover content resource identifiers; never assume Bengali translations
      // or a particular audio reciter ID are stable across API environments.
      const [translationData, recitationData] = await Promise.all([
        contentGet("resources/translations?language=bn", c),
        contentGet("resources/recitations?language=en", c),
      ]);
      const translations = (translationData.translations ?? []) as Array<
        Record<string, unknown>
      >;
      const bengali = translations.find((item) =>
        String(item.language_name ?? "").toLowerCase() === "bengali"
      );
      const recitations = (recitationData.recitations ?? []) as Array<
        Record<string, unknown>
      >;
      const reciter = recitations.find((item) =>
        /mishar|afasy/i.test(JSON.stringify(item))
      ) ?? recitations[0];
      const ids = [bengali?.id, 57].filter((value) =>
        Number.isInteger(value)
      );
      const params = new URLSearchParams({
        language: "bn",
        words: "true",
        fields: "text_uthmani",
        page: String(page),
        per_page: "50",
      });
      if (ids.length) params.set("translations", ids.join(","));
      if (Number.isInteger(reciter?.id)) {
        params.set("audio", String(reciter.id));
      }
      const response = await contentGet(
        "verses/by_chapter/" + chapter + "?" + params,
        c,
      );
      return respond(200, {
        verses: response.verses ?? [],
        pagination: response.pagination ?? {},
        translation_name: bengali?.name ?? bengali?.translated_name ?? null,
        translation_id: bengali?.id ?? null,
        environment: env,
      }, origin);
    }
    return respond(400, { error: "Unsupported action" }, origin);
  } catch (error) {
    // Never log OAuth tokens, secrets, user or patient data.
    console.error(
      "Quran content proxy request failed:",
      error instanceof Error ? error.message : "Unknown failure",
    );
    return respond(502, {
      error: "কুরআন API এখন সংযুক্ত হতে পারছে না। পরে আবার চেষ্টা করুন।",
    }, origin);
  }
});
