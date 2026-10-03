export type PatientSignInInput = {
  identifier: string;
  identifierKind: "patient_code" | "phone";
  password: string;
};

const patientCodePattern = /^[A-Z0-9][A-Z0-9-]{2,31}$/;
const e164Pattern = /^\+[1-9]\d{7,14}$/;

export function parsePatientSignInInput(value: unknown): PatientSignInInput {
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    throw new Error("A request body is required.");
  }
  const body = value as Record<string, unknown>;
  const rawIdentifier = typeof body.identifier === "string"
    ? body.identifier
    : typeof body.patient_code === "string"
    ? body.patient_code
    : "";
  const isPhone = rawIdentifier.trim().startsWith("+");
  const identifier = isPhone
    ? rawIdentifier.trim().replace(/[\s()-]/g, "")
    : rawIdentifier.trim().toUpperCase();
  const password = typeof body.password === "string" ? body.password : "";
  if (
    isPhone
      ? !e164Pattern.test(identifier)
      : !patientCodePattern.test(identifier)
  ) {
    throw new Error("Enter a valid patient ID.");
  }
  if (password.length < 8 || password.length > 72) {
    throw new Error("Enter your password.");
  }
  return {
    identifier,
    identifierKind: isPhone ? "phone" : "patient_code",
    password,
  };
}
