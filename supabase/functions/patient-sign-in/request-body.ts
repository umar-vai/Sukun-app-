// Bound unauthenticated JSON bodies before parsing or running privileged lookups.
// A patient identifier + password should never need a large request body.
export const MAX_SIGN_IN_BODY_BYTES = 4096;

export async function readLimitedJson(request: Request): Promise<unknown> {
  const rawLength = request.headers.get("content-length");
  if (rawLength !== null) {
    const claimed = Number(rawLength);
    if (Number.isFinite(claimed) && claimed > MAX_SIGN_IN_BODY_BYTES) {
      throw new Error("request_too_large");
    }
  }

  if (!request.body) throw new SyntaxError("Missing request body");
  const reader = request.body.getReader();
  const decoder = new TextDecoder("utf-8", { fatal: true });
  let count = 0;
  let data = "";
  try {
    while (true) {
      const { done, value } = await reader.read();
      if (done) break;
      count += value.byteLength;
      if (count > MAX_SIGN_IN_BODY_BYTES) {
        await reader.cancel();
        throw new Error("request_too_large");
      }
      data += decoder.decode(value, { stream: true });
    }
    data += decoder.decode();
    return JSON.parse(data);
  } finally {
    reader.releaseLock();
  }
}
