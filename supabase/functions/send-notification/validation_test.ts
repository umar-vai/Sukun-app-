import { assertEquals, assertThrows } from "jsr:@std/assert@1";
import { buildPlanUpdatedMessage } from "./firebase_client.ts";
import { parsePlanUpdatedInput } from "./validation.ts";

Deno.test("accepts an idempotent plan-updated request", () => {
  const input = parsePlanUpdatedInput({
    type: "plan_updated",
    care_plan_id: "10000000-0000-4000-8000-000000000001",
    request_id: "20000000-0000-4000-8000-000000000001",
  });
  assertEquals(input.type, "plan_updated");
});

Deno.test("rejects broadcast and unsupported notification types", () => {
  assertThrows(
    () =>
      parsePlanUpdatedInput({
        type: "broadcast",
        care_plan_id: "10000000-0000-4000-8000-000000000001",
        request_id: "20000000-0000-4000-8000-000000000001",
      }),
    Error,
    "Only plan-updated notifications",
  );
});

Deno.test("plan update payload contains no prescription or action content", () => {
  const message = buildPlanUpdatedMessage(
    "device-token",
    "10000000-0000-4000-8000-000000000001",
  );
  assertEquals(message.notification.body, "Your care plan has been updated.");
  assertEquals(message.data.type, "plan_updated");
  assertEquals(message.android.notification.channel_id, "care_updates");
  assertEquals(Object.keys(message.data).sort(), ["care_plan_id", "type"]);
});
