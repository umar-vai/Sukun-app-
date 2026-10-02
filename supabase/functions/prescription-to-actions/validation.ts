export type GenerateActionsInput = {
  prescriptionId: string;
  carePlanId: string;
  requestId: string;
};

const uuidPattern =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

export function parseGenerateActionsInput(
  value: unknown,
): GenerateActionsInput {
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    throw new Error("A request body is required.");
  }
  const body = value as Record<string, unknown>;
  const prescriptionId = stringValue(body.prescription_id);
  const carePlanId = stringValue(body.care_plan_id);
  const requestId = stringValue(body.request_id);
  if (!uuidPattern.test(prescriptionId)) {
    throw new Error("A valid prescription identifier is required.");
  }
  if (!uuidPattern.test(carePlanId)) {
    throw new Error("A valid care plan identifier is required.");
  }
  if (!uuidPattern.test(requestId)) {
    throw new Error("A valid request identifier is required.");
  }
  return { prescriptionId, carePlanId, requestId };
}

function stringValue(value: unknown): string {
  return typeof value === "string" ? value.trim() : "";
}
