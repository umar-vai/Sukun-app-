const internalPatientEmailDomain = "patients.auth.sukunlife.invalid";

export function createInternalPatientEmail(seed = crypto.randomUUID()): string {
  const normalizedSeed = seed.replaceAll("-", "").toLowerCase();
  return `patient-${normalizedSeed}@${internalPatientEmailDomain}`;
}
