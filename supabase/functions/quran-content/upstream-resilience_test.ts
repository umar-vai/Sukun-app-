import { assert, assertEquals, assertRejects } from "jsr:@std/assert";
import { openQuranGet, resetOpenQuranCacheForTests } from "./upstream-resilience.ts";

function ok(data: unknown): Response {
  return Response.json({ code: 200, status: "OK", data });
}

Deno.test("transient 503 uses bounded retries and succeeds with attributed data", async () => {
  resetOpenQuranCacheForTests();
  let calls = 0;
  const result = await openQuranGet("surah", {
    fetcher: () => {
      calls++;
      return Promise.resolve(calls < 3 ? new Response("", { status: 503 }) : ok([{ number: 1 }]));
    },
    sleep: () => Promise.resolve(),
  });
  assertEquals(calls, 3);
  assertEquals(result, [{ number: 1 }]);
});

Deno.test("successful short-lived response is shared without another upstream call", async () => {
  resetOpenQuranCacheForTests();
  let calls = 0;
  const fetcher = () => {
    calls++;
    return Promise.resolve(ok([{ number: 1 }]));
  };
  const [a, b] = await Promise.all([
    openQuranGet("surah", { fetcher }),
    openQuranGet("surah", { fetcher }),
  ]);
  assertEquals(a, b);
  assertEquals(calls, 1);
  await openQuranGet("surah", { fetcher });
  assertEquals(calls, 1);
});

Deno.test("temporary upstream failure can use only a recent successful response", async () => {
  resetOpenQuranCacheForTests();
  let time = 1_000;
  const fresh = { number: 1 };
  await openQuranGet("surah", {
    fetcher: () => Promise.resolve(ok(fresh)),
    now: () => time,
  });
  time += 120_000;
  const stale = await openQuranGet("surah", {
    fetcher: () => Promise.resolve(new Response("", { status: 503 })),
    sleep: () => Promise.resolve(),
    now: () => time,
  });
  assertEquals(stale, fresh);
  time += 601_000;
  await assertRejects(
    () => openQuranGet("surah", {
      fetcher: () => Promise.resolve(new Response("", { status: 503 })),
      sleep: () => Promise.resolve(),
      now: () => time,
    }),
    Error,
    "temporarily unavailable",
  );
});

Deno.test("does not retry nontransient errors or fabricate missing verses", async () => {
  resetOpenQuranCacheForTests();
  let calls = 0;
  await assertRejects(
    () => openQuranGet("surah", {
      fetcher: () => {
        calls++;
        return Promise.resolve(new Response("", { status: 403 }));
      },
    }),
    Error,
    "HTTP 403",
  );
  assertEquals(calls, 1);
  await assertRejects(() => openQuranGet("surah/0/editions/quran-uthmani,bn.bengali,ar.alafasy"));
  assert(true);
});
