export type PlanUpdatedInput = {
  type: "plan_updated";
  carePlanId: string;
  requestId: string;
};

const uuidPattern =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

export function parsePlanUpdatedInput(value: unknown): PlanUpdatedInput {
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    throw new Error("A notification request is required.");
  }
  const input = value as Record<string, unknown>;
  if (input.type !== "plan_updated") {
    throw new Error("Only plan-updated notifications are supported.");
  }
  if (
    typeof input.care_plan_id !== "string" ||
    !uuidPattern.test(input.care_plan_id)
  ) {
    throw new Error("A valid care plan identifier is required.");
  }
  if (
    typeof input.request_id !== "string" ||
    !uuidPattern.test(input.request_id)
  ) {
    throw new Error("A valid request identifier is required.");
  }
  return {
    type: "plan_updated",
    carePlanId: input.care_plan_id,
    requestId: input.request_id,
  };
}
