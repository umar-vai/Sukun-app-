import { approvedAudioUrls, isApprovedAudioUrl } from "./approved.ts";

Deno.test("gateway allowlist exactly pins 19 approved public files", () => {
  if (approvedAudioUrls.size !== 19) throw new Error("unexpected allowlist");
  for (const audioUrl of approvedAudioUrls) {
    if (!isApprovedAudioUrl(audioUrl)) {
      throw new Error("approved URL did not pass strict policy");
    }
  }
});

Deno.test("reject arbitrary URLs, redirect targets and signed URLs", () => {
  const first = [...approvedAudioUrls][0];
  const rejected: unknown[] = [
    "https://evil.example/audio.mp3",
    "http://files.ruqyahbd.org/audio/file.mp3",
    "https://files.ruqyahbd.org.evil.example/audio/file.mp3",
    first + "?token=secret",
    first + "#part",
    first.replace(".mp3", ".pdf"),
    null,
    7,
  ];
  for (const url of rejected) {
    if (isApprovedAudioUrl(url)) {
      throw new Error("gateway accepted unapproved URL");
    }
  }
});
