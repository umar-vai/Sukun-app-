export type PatientSignInInput = {
  patientCode: string;
  password: string;
};

const patientCodePattern = /^[A-Z0-9][A-Z0-9-]{2,31}$/;

export function parsePatientSignInInput(value: unknown): PatientSignInInput {
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    throw new Error("A request body is required.");
  }
  const body = value as Record<string, unknown>;
  const patientCode = typeof body.patient_code === "string"
    ? body.patient_code.trim().toUpperCase()
    : "";
  const password = typeof body.password === "string" ? body.password : "";
  if (!patientCodePattern.test(patientCode)) {
    throw new Error("Enter a valid patient ID.");
  }
  if (password.length < 8 || password.length > 72) {
    throw new Error("Enter your password.");
  }
  return { patientCode, password };
}
