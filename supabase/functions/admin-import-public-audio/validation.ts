export const AUDIO_BUCKET = "sukun-public-audio";
export const MAX_AUDIO_BYTES = 47_185_920;
const uuidPattern = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

export type ImportRequest = {
  contentItemId: string;
  permissionConfirmed: true;
};

export function parseImportRequest(input: unknown): ImportRequest {
  if (!input || typeof input !== "object" || Array.isArray(input)) {
    throw new Error("invalid_request");
  }
  const data = input as Record<string, unknown>;
  if (typeof data.contentItemId !== "string" ||
      !uuidPattern.test(data.contentItemId)) {
    throw new Error("invalid_content_item");
  }
  if (data.permissionConfirmed !== true) {
    throw new Error("rights_confirmation_required");
  }
  return {
    contentItemId: data.contentItemId,
    permissionConfirmed: true,
  };
}

export function approvedAudioSource(raw: string): URL | null {
  try {
    const url = new URL(raw);
    if (url.protocol !== "https:" ||
        url.hostname !== "files.ruqyahbd.org" ||
        url.port !== "" ||
        url.username || url.password ||
        url.search || url.hash ||
        !/^\/audio\/[a-z0-9_.-]+\.mp3$/i.test(url.pathname)) {
      return null;
    }
    return url;
  } catch {
    return null;
  }
}

export function looksLikeMp3(bytes: Uint8Array): boolean {
  if (bytes.length < 4) return false;
  const id3 = bytes[0] === 0x49 && bytes[1] === 0x44 &&
    bytes[2] === 0x33;
  const frameSync = bytes[0] === 0xff && (bytes[1] & 0xe0) === 0xe0;
  return id3 || frameSync;
}

export async function boundedAudioBytes(
  response: Response,
  maximum = MAX_AUDIO_BYTES,
): Promise<Uint8Array> {
  if (!response.ok || !response.body) throw new Error("download_failed");
  const declared = response.headers.get("content-length");
  if (declared != null && Number(declared) > maximum) {
    await response.body.cancel();
    throw new Error("audio_too_large");
  }
  const reader = response.body.getReader();
  const chunks: Uint8Array[] = [];
  let total = 0;
  try {
    while (true) {
      const part = await reader.read();
      if (part.done) break;
      total += part.value.byteLength;
      if (total > maximum) {
        await reader.cancel();
        throw new Error("audio_too_large");
      }
      chunks.push(part.value);
    }
  } finally {
    reader.releaseLock();
  }
  if (!total) throw new Error("empty_audio");
  const result = new Uint8Array(total);
  let offset = 0;
  for (const chunk of chunks) {
    result.set(chunk, offset);
    offset += chunk.byteLength;
  }
  if (!looksLikeMp3(result)) throw new Error("not_an_mp3");
  return result;
}
