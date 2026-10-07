export type SuggestedFrequency =
  | { type: "daily"; interval: number }
  | { type: "weekly"; weekdays: number[] };

export type SuggestedAction = {
  type: string;
  title: string;
  instruction: string | null;
  count_target: number | null;
  duration_minutes: number | null;
  frequency: SuggestedFrequency | null;
  time_window: "morning" | "afternoon" | "evening" | "night" | "anytime" | null;
  exact_time: string | null;
  resource_match_query: string | null;
  source_evidence: string;
  confidence: number;
  needs_review: boolean;
  ambiguities: string[];
};

export type SuggestedActions = {
  actions: SuggestedAction[];
  source_text: string | null;
};

const timeWindows = new Set([
  "morning",
  "afternoon",
  "evening",
  "night",
  "anytime",
]);

export function parseSuggestedActions(value: unknown): SuggestedActions {
  if (!isObject(value) || !Array.isArray(value.actions)) {
    throw new Error("AI output must contain an actions array.");
  }
  if (value.actions.length > 50) {
    throw new Error("AI output contains too many actions.");
  }
  return {
    actions: value.actions.map(parseAction),
    source_text: value.source_text === undefined
      ? null
      : optionalText(value.source_text, 50000, "source text"),
  };
}

function parseAction(value: unknown, index: number): SuggestedAction {
  if (!isObject(value)) throw new Error(`Action ${index + 1} is invalid.`);
  const type = requiredText(value.type, 80, "action type");
  const title = requiredText(value.title, 160, "action title");
  const instruction = optionalText(value.instruction, 2000, "instruction");
  const countTarget = optionalPositiveInteger(value.count_target, "count");
  const durationMinutes = optionalPositiveInteger(
    value.duration_minutes,
    "duration",
  );
  const frequency = parseFrequency(value.frequency);
  const timeWindow = value.time_window === null
    ? null
    : typeof value.time_window === "string" &&
        timeWindows.has(value.time_window)
    ? value.time_window as SuggestedAction["time_window"]
    : invalid("time window");
  const exactTime = value.exact_time === null
    ? null
    : typeof value.exact_time === "string" &&
        /^(?:[01]\d|2[0-3]):[0-5]\d$/.test(value.exact_time)
    ? value.exact_time
    : invalid("exact time");
  const resourceMatchQuery = optionalText(
    value.resource_match_query,
    160,
    "resource match query",
  );
  const sourceEvidence = requiredText(
    value.source_evidence,
    600,
    "source evidence",
  );
  if (
    typeof value.confidence !== "number" ||
    value.confidence < 0 || value.confidence > 1
  ) {
    throw new Error("Action confidence must be between 0 and 1.");
  }
  if (typeof value.needs_review !== "boolean") {
    throw new Error("Action needs_review must be a boolean.");
  }
  if (
    !Array.isArray(value.ambiguities) ||
    !value.ambiguities.every((item) => typeof item === "string")
  ) {
    throw new Error("Action ambiguities must be a string array.");
  }
  const ambiguities = value.ambiguities
    .map((item) => item.trim())
    .filter(Boolean)
    .slice(0, 20);
  if (value.needs_review && ambiguities.length === 0) {
    throw new Error("An action needing review must explain the uncertainty.");
  }

  return {
    type,
    title,
    instruction,
    count_target: countTarget,
    duration_minutes: durationMinutes,
    frequency,
    time_window: timeWindow,
    exact_time: exactTime,
    resource_match_query: resourceMatchQuery,
    source_evidence: sourceEvidence,
    confidence: value.confidence,
    needs_review: value.needs_review || ambiguities.length > 0 ||
      frequency === null,
    ambiguities,
  };
}

function parseFrequency(value: unknown): SuggestedFrequency | null {
  if (value === null) return null;
  if (!isObject(value) || typeof value.type !== "string") {
    throw new Error("Action frequency is invalid.");
  }
  if (value.type === "daily") {
    const interval = value.interval;
    if (!Number.isInteger(interval) || (interval as number) < 1) {
      throw new Error("Daily frequency interval must be positive.");
    }
    return { type: "daily", interval: interval as number };
  }
  if (value.type === "weekly") {
    if (!Array.isArray(value.weekdays) || value.weekdays.length === 0) {
      throw new Error("Weekly frequency needs weekdays.");
    }
    const weekdays = [...new Set(value.weekdays)];
    if (
      !weekdays.every((day) => Number.isInteger(day) && day >= 1 && day <= 7)
    ) {
      throw new Error("Weekly weekdays must use ISO values 1 through 7.");
    }
    return { type: "weekly", weekdays: weekdays as number[] };
  }
  throw new Error("Unsupported action frequency.");
}

function requiredText(value: unknown, max: number, label: string): string {
  if (typeof value !== "string" || !value.trim() || value.trim().length > max) {
    throw new Error(`Invalid ${label}.`);
  }
  return value.trim();
}

function optionalText(
  value: unknown,
  max: number,
  label: string,
): string | null {
  if (value === null) return null;
  if (typeof value !== "string" || value.trim().length > max) {
    throw new Error(`Invalid ${label}.`);
  }
  return value.trim() || null;
}

function optionalPositiveInteger(value: unknown, label: string): number | null {
  if (value === null) return null;
  if (!Number.isInteger(value) || (value as number) < 1) {
    throw new Error(`Action ${label} must be a positive integer or null.`);
  }
  return value as number;
}

function invalid(label: string): never {
  throw new Error(`Invalid ${label}.`);
}

function isObject(value: unknown): value is Record<string, unknown> {
  return !!value && typeof value === "object" && !Array.isArray(value);
}

export const geminiResponseSchema = {
  type: "object",
  required: ["actions"],
  properties: {
    source_text: { type: ["string", "null"] },
    actions: {
      type: "array",
      maxItems: 50,
      items: {
        type: "object",
        required: [
          "type",
          "title",
          "instruction",
          "count_target",
          "duration_minutes",
          "frequency",
          "time_window",
          "exact_time",
          "resource_match_query",
          "source_evidence",
          "confidence",
          "needs_review",
          "ambiguities",
        ],
        properties: {
          type: { type: "string" },
          title: { type: "string" },
          instruction: { type: ["string", "null"] },
          count_target: { type: ["integer", "null"], minimum: 1 },
          duration_minutes: { type: ["integer", "null"], minimum: 1 },
          frequency: {
            anyOf: [
              { type: "null" },
              {
                type: "object",
                required: ["type", "interval"],
                properties: {
                  type: { type: "string", enum: ["daily"] },
                  interval: { type: "integer", minimum: 1 },
                },
              },
              {
                type: "object",
                required: ["type", "weekdays"],
                properties: {
                  type: { type: "string", enum: ["weekly"] },
                  weekdays: {
                    type: "array",
                    minItems: 1,
                    items: { type: "integer", minimum: 1, maximum: 7 },
                  },
                },
              },
            ],
          },
          time_window: {
            type: ["string", "null"],
            enum: ["morning", "afternoon", "evening", "night", "anytime", null],
          },
          exact_time: { type: ["string", "null"] },
          resource_match_query: { type: ["string", "null"] },
          source_evidence: { type: "string" },
          confidence: { type: "number", minimum: 0, maximum: 1 },
          needs_review: { type: "boolean" },
          ambiguities: { type: "array", items: { type: "string" } },
        },
      },
    },
  },
} as const;
