const internalPatientEmailDomain = "patients.auth.sukunlife.invalid";

export function createInternalPatientEmail(seed: string): string {
  const normalizedSeed = seed.replaceAll("-", "").toLowerCase();
  return `patient-${normalizedSeed}@${internalPatientEmailDomain}`;
}
