// Pinned public recordings only; sourced from the owner-attested editorial
// crosswalk at app/assets/data/ruqyahbd_book_audio_crosswalk.json.
// Editing CMS media_url alone MUST NOT expand the proxy allowlist.
// IMPORTANT: editorial entries are draft-review-only until a human publishes.
export const approvedAudioUrls = new Set<string>([
  "https://files.ruqyahbd.org/audio/Ruqyah-Luhaidan-ruqyahbd.org.mp3",
  "https://files.ruqyahbd.org/audio/Ruqyah-Sihr-Hibshi-ruqyahbd.org.mp3",
  "https://files.ruqyahbd.org/clips/ayat-shifa-ruqyahbd.org.mp3",
  "https://files.ruqyahbd.org/audio/Ruqyah-8surah-ruqyahbd.org.mp3",
  "https://files.ruqyahbd.org/audio/Ruqyah-Harq-ruqyahbd.org.mp3",
  "https://files.ruqyahbd.org/audio/Ruqyah-AyatulKursi-ruqyahbd.org.mp3",
  "https://files.ruqyahbd.org/audio/Ruqyah-AhmadAjmy-ruqyahbd.org.mp3",
  "https://files.ruqyahbd.org/audio/Ruqyah-Jinn-ruqyahbd.org.mp3",
  "https://files.ruqyahbd.org/audio/Sura-Zilzal-to-Nas-ruqyahbd.org.mp3",
  "https://files.ruqyahbd.org/audio/Ruqyah-Zina-ruqyahbd.org.mp3",
  "https://files.ruqyahbd.org/audio/Ruqyah-3Kul-ruqyahbd.org.mp3",
  "https://files.ruqyahbd.org/audio/Ruqyah-EvilEye-ruqyahbd.org.mp3",
  "https://files.ruqyahbd.org/audio/Surah-Baqara-by-Sudais-ruqyahbd.org.mp3",
  "https://files.ruqyahbd.org/audio/Ruqyah-Azan-ruqyahbd.org.mp3",
  "https://files.ruqyahbd.org/audio/Ruqyah-Shifa-Sakina-ruqyahbd.org.mp3",
  "https://files.ruqyahbd.org/audio/Ruqyah-withBangla-ruqyahbd.org.mp3",
  "https://files.ruqyahbd.org/audio/Ruqyah-SuraFatiha-ruqyahbd.org.mp3",
  "https://files.ruqyahbd.org/audio/Ruqyah-Khuruj-ruqyahbd.org.mp3",
  "https://files.ruqyahbd.org/audio/Ruqyah-tadmir-qital-ruqyahbd.org.mp3"
]);

export function isApprovedAudioUrl(input: unknown): input is string {
  if (typeof input !== "string" || !approvedAudioUrls.has(input)) return false;
  const url = new URL(input);
  return url.protocol === "https:" &&
    url.hostname === "files.ruqyahbd.org" &&
    url.username === "" && url.password === "" &&
    url.search === "" && url.hash === "" &&
    url.pathname.toLowerCase().endsWith(".mp3");
}
