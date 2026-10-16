import { assertEquals, assertThrows } from "jsr:@std/assert@1";
import { buildWebCareReminderMessage } from "./firebase_client.ts";

Deno.test("background Web reminder sends task ID only and never patient copy", () => {
  const taskId = "10000000-0000-4000-8000-000000000711";
  const message = buildWebCareReminderMessage("synthetic-web-token", taskId);
  assertEquals(message.data, { type: "care_reminder", task_id: taskId });
  assertEquals("notification" in message, false);
  assertEquals(message.webpush?.headers.TTL, "600");
  assertEquals(JSON.stringify(message).includes("prescription"), false);
});

Deno.test("malformed task identifiers never enter Web Push messages", () => {
  for (const forged of ["../../admin", "https://example.org", "", "xyz"]) {
    assertThrows(
      () => buildWebCareReminderMessage("synthetic-web-token", forged),
    );
  }
});
