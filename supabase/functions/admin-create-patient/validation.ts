export type CreatePatientInput = {
  fullName: string;
  phone: string;
  temporaryPassword: string;
  patientCode: string | null;
  requestId: string;
};

const uuidPattern =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const e164Pattern = /^\+[1-9]\d{7,14}$/;
const patientCodePattern = /^[A-Z0-9][A-Z0-9-]{2,31}$/;

export function parseCreatePatientInput(value: unknown): CreatePatientInput {
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    throw new Error("A request body is required.");
  }

  const body = value as Record<string, unknown>;
  const fullName = text(body.full_name);
  const phone = text(body.phone).replace(/[\s()-]/g, "");
  const temporaryPassword = text(body.temporary_password, false);
  const requestId = text(body.request_id);
  const rawPatientCode = text(body.patient_code).toUpperCase();

  if (fullName.length < 2 || fullName.length > 160) {
    throw new Error("Full name must be between 2 and 160 characters.");
  }
  if (!e164Pattern.test(phone)) {
    throw new Error(
      "Phone number must use international format, for example +8801…",
    );
  }
  if (temporaryPassword.length < 8 || temporaryPassword.length > 72) {
    throw new Error("Temporary password must be between 8 and 72 characters.");
  }
  if (!uuidPattern.test(requestId)) {
    throw new Error("A valid request identifier is required.");
  }
  if (rawPatientCode && !patientCodePattern.test(rawPatientCode)) {
    throw new Error(
      "Patient code must contain 3–32 letters, numbers, or hyphens.",
    );
  }

  return {
    fullName,
    phone,
    temporaryPassword,
    patientCode: rawPatientCode || null,
    requestId,
  };
}

function text(value: unknown, trim = true): string {
  if (typeof value !== "string") return "";
  return trim ? value.trim() : value;
}
