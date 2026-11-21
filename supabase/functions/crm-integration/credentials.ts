// Pure helpers for CRM patient provisioning. No runtime globals beyond Web
// Crypto, so they run in Deno and Node tests.

/**
 * Temporary password shown once to staff, who pass it to the patient by hand.
 * 12 characters from an alphabet without look-alikes (no 0 O 1 l I), about
 * 69 bits. The account is forced to change it at first login.
 */
export function generateTemporaryPassword(): string {
  const alphabet = "ABCDEFGHJKMNPQRSTUVWXYZabcdefghjkmnpqrstuvwxyz23456789";
  const limit = 256 - (256 % alphabet.length); // reject to avoid modulo bias
  let out = "";
  while (out.length < 12) {
    for (const value of crypto.getRandomValues(new Uint8Array(24))) {
      if (value < limit && out.length < 12) {
        out += alphabet[value % alphabet.length];
      }
    }
  }
  return out;
}

export function generatePatientCode(now = new Date()): string {
  const alphabet = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
  const bytes = crypto.getRandomValues(new Uint8Array(6));
  const suffix = Array.from(bytes, (v) => alphabet[v % alphabet.length]).join(
    "",
  );
  return `SL-${now.getUTCFullYear()}-${suffix}`;
}

export type NormalizedPhone = { e164: string; digits: string };

/** Bangladesh mobile numbers only: 01[3-9]XXXXXXXX in any common spelling. */
export function normalizeBangladeshPhone(raw: string): NormalizedPhone | null {
  let value = raw.replace(/[\s()-]/g, "");
  if (value.startsWith("+")) value = value.slice(1);
  if (value.startsWith("00")) value = value.slice(2);
  if (value.startsWith("880")) value = value.slice(3);
  if (value.startsWith("0")) value = value.slice(1);
  if (!/^1[3-9][0-9]{8}$/.test(value)) return null;
  return { e164: `+880${value}`, digits: `880${value}` };
}
