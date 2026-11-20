// Same limits as the existing patient password change (8 to 72 characters).
export function validateNewPassword(value: unknown): string | null {
  if (typeof value !== "string") return null;
  if (value.length < 8 || value.length > 72) return null;
  if (/^(.)\1+$/.test(value)) return null; // one repeated character
  return value;
}

export function validateToken(value: unknown): string | null {
  return typeof value === "string" && /^[A-Za-z0-9_-]{43}$/.test(value)
    ? value
    : null;
}
