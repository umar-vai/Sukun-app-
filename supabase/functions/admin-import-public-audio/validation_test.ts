import {
  approvedAudioSource,
  boundedAudioBytes,
  looksLikeMp3,
  parseImportRequest,
} from "./validation.ts";

Deno.test("only valid content id with explicit permission acknowledgement", () => {
  const id = "19e7b42d-9d0b-4714-b982-35341a934e98";
  const value = parseImportRequest({
    contentItemId: id,
    permissionConfirmed: true,
  });
  if (value.contentItemId !== id) throw new Error("bad id");
  for (
    const input of [
      { contentItemId: id },
      { contentItemId: id, permissionConfirmed: false },
      { contentItemId: "../bad", permissionConfirmed: true },
    ]
  ) {
    try {
      parseImportRequest(input);
      throw new Error("unsafe import accepted");
    } catch (error) {
      if ((error as Error).message === "unsafe import accepted") throw error;
    }
  }
});

Deno.test("rejects SSRF paths, queries, redirects to arbitrary hosts", () => {
  const good =
    "https://files.ruqyahbd.org/audio/Ruqyah-Luhaidan-HQ-ruqyahbd.org.mp3";
  if (!approvedAudioSource(good)) throw new Error("approved host missing");
  for (
    const url of [
      "http://files.ruqyahbd.org/audio/test.mp3",
      "https://evil.invalid/audio/test.mp3",
      "https://files.ruqyahbd.org.evil.invalid/audio/test.mp3",
      "https://files.ruqyahbd.org:444/audio/test.mp3",
      "https://files.ruqyahbd.org/private/test.mp3",
      "https://files.ruqyahbd.org/audio/test.mp3?redirect=evil",
      "https://files.ruqyahbd.org/audio/%2e%2e/test.mp3",
      "https://files.ruqyahbd.org/audio/file.pdf",
    ]
  ) {
    if (approvedAudioSource(url)) throw new Error("unsafe host accepted");
  }
});

Deno.test("allows explicit admin alternate from approved host only", () => {
  const id = "19e7b42d-9d0b-4714-b982-35341a934e98";
  const original =
    "https://files.ruqyahbd.org/audio/Ruqyah-Luhaidan-HQ-ruqyahbd.org.mp3";
  const alternate =
    "https://files.ruqyahbd.org/audio/Ruqyah-Luhaidan-ruqyahbd.org.mp3";
  const selected = parseImportRequest({
    contentItemId: id,
    permissionConfirmed: true,
    sourceUrlOverride: alternate,
  });
  if (selected.sourceUrlOverride !== alternate) {
    throw new Error("approved alternate was not accepted");
  }
  for (
    const input of [
      { contentItemId: id, permissionConfirmed: true, sourceUrlOverride: null },
      {
        contentItemId: id,
        permissionConfirmed: true,
        sourceUrlOverride: "http://127.0.0.1/audio/demo.mp3",
      },
      {
        contentItemId: id,
        permissionConfirmed: true,
        sourceUrlOverride: original + "?next=https://evil.example/",
      },
    ]
  ) {
    try {
      parseImportRequest(input);
      throw new Error("unsafe override accepted");
    } catch (error) {
      if ((error as Error).message === "unsafe override accepted") {
        throw error;
      }
    }
  }
});

Deno.test("validates MP3 magic and refuses HTML response", () => {
  if (!looksLikeMp3(new Uint8Array([0x49, 0x44, 0x33, 0x04]))) {
    throw new Error("ID3 rejected");
  }
  if (looksLikeMp3(new TextEncoder().encode("<html>"))) {
    throw new Error("HTML accepted");
  }
});

Deno.test("caps streamed source without trusting Content-Length", async () => {
  const good = new Response(new Uint8Array([0x49, 0x44, 0x33, 0x04, 1, 2]));
  const result = await boundedAudioBytes(good, 8);
  if (result.length !== 6) throw new Error("bad content");
  const tooBig = new Response(
    new Uint8Array([0x49, 0x44, 0x33, 0x04, 1, 2, 3, 4]),
  );
  try {
    await boundedAudioBytes(tooBig, 5);
    throw new Error("cap bypassed");
  } catch (error) {
    if ((error as Error).message === "cap bypassed") throw error;
  }
});
