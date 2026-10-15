// Bounded resilience for the existing attributed Al Quran Cloud stream.
// No persisted Quran or translation corpus, no alternate unapproved provider.
const baseUrl = "https://api.alquran.cloud/v1/";
const successTtlMs = 90_000;
const staleLimitMs = 600_000;
const cacheLimit = 6;
const retryStatuses = new Set([429, 500, 502, 503, 504]);

type Entry = { value: unknown; createdAt: number };
const entries = new Map<string, Entry>();
const pending = new Map<string, Promise<unknown>>();

export type OpenQuranDependencies = {
  fetcher?: typeof fetch;
  now?: () => number;
  sleep?: (milliseconds: number) => Promise<void>;
};

export function resetOpenQuranCacheForTests(): void {
  entries.clear();
  pending.clear();
}

function remember(path: string, value: unknown, now: number): void {
  entries.delete(path);
  entries.set(path, { value, createdAt: now });
  while (entries.size > cacheLimit) {
    const oldest = entries.keys().next().value;
    if (!oldest) break;
    entries.delete(oldest);
  }
}

function isTransient(error: unknown): boolean {
  return error instanceof TypeError ||
    (error instanceof DOMException && error.name === "TimeoutError");
}

/** Never use stale values older than ten minutes. An outage is not a reason
 * to synthesize, translate, rename or silently change any Quran content.
 */
export async function openQuranGet(
  path: string,
  dependencies: OpenQuranDependencies = {},
): Promise<unknown> {
  // This helper only accepts the two hardcoded call types used by our proxy.
  if (
    path !== "surah" &&
    !/^surah\/(?:[1-9]|[1-9][0-9]|1[01][0-9]|11[0-4])\/editions\/quran-uthmani,bn\.bengali,ar\.alafasy$/
      .test(path)
  ) {
    throw new Error("Unsupported Quran upstream path");
  }
  const now = dependencies.now ?? Date.now;
  const fetcher = dependencies.fetcher ?? fetch;
  const sleep = dependencies.sleep ??
    ((ms: number) => new Promise<void>((resolve) => setTimeout(resolve, ms)));
  const current = entries.get(path);
  if (current && now() - current.createdAt < successTtlMs) {
    return current.value;
  }
  const inflight = pending.get(path);
  if (inflight) return inflight;

  const operation = (async (): Promise<unknown> => {
    let lastError: unknown;
    for (let attempt = 0; attempt < 3; attempt++) {
      try {
        const response = await fetcher(baseUrl + path, {
          headers: { Accept: "application/json" },
          signal: AbortSignal.timeout(7_000),
        });
        if (!response.ok) {
          // Bad input, access or policy errors must not be retried.
          if (!retryStatuses.has(response.status)) {
            throw new Error("Quran upstream HTTP " + response.status);
          }
          lastError = new Error("Quran upstream temporarily unavailable");
        } else {
          const data = await response.json();
          if (
            data?.code !== 200 || data?.status !== "OK" ||
            data?.data == null
          ) {
            throw new Error("Invalid Quran upstream response");
          }
          remember(path, data.data, now());
          return data.data;
        }
      } catch (error) {
        if (!isTransient(error)) throw error;
        lastError = new Error("Quran upstream network timeout");
      }
      if (attempt < 2) {
        // A small delay prevents a failing third party from being hammered.
        await sleep(450 * (attempt + 1));
      }
    }
    const cached = entries.get(path);
    if (cached && now() - cached.createdAt <= staleLimitMs) {
      return cached.value;
    }
    throw lastError ?? new Error("Quran upstream unavailable");
  })();

  pending.set(path, operation);
  try {
    return await operation;
  } finally {
    pending.delete(path);
  }
}
