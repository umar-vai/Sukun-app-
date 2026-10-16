/* Firebase Web Push service worker scoped to /Sukun-app-/ on Pages.
 * Only public client Firebase configuration may be loaded here.
 * The backend sends DATA-ONLY push; never display patient or AI copy.
 */
importScripts("./sukun-push-config.js");
if (self.sukunWebPushConfig?.enabled) {
  importScripts("https://www.gstatic.com/firebasejs/11.10.0/firebase-app-compat.js");
  importScripts("https://www.gstatic.com/firebasejs/11.10.0/firebase-messaging-compat.js");
  const cfg = self.sukunWebPushConfig;
  firebase.initializeApp({
    apiKey: cfg.apiKey, appId: cfg.appId,
    projectId: cfg.projectId, messagingSenderId: cfg.messagingSenderId
  });
  const messaging = firebase.messaging();
  const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
  messaging.onBackgroundMessage((payload) => {
    const data = payload?.data || {};
    if (data.type !== "care_reminder" || !uuid.test(data.task_id || "")) return;
    return self.registration.showNotification("সুকুন লাইফ", {
      body: "আপনার আজকের নির্ধারিত আমলের সময় হয়েছে।",
      tag: "sukun-care-" + data.task_id,
      data: { taskId: data.task_id },
      icon: undefined,
    });
  });
}
self.addEventListener("notificationclick", (event) => {
  event.notification.close();
  const id = event.notification.data?.taskId;
  if (!/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(id || "")) return;
  const scope = new URL(self.registration.scope);
  const safeUrl = scope.origin + scope.pathname +
    "#/patient/today?task=" + encodeURIComponent(id);
  event.waitUntil((async () => {
    const windows = await clients.matchAll({ type: "window", includeUncontrolled: true });
    const current = windows.find((client) => client.url.startsWith(scope.href));
    if (current) {
      await current.navigate(safeUrl);
      return current.focus();
    }
    return clients.openWindow(safeUrl);
  })());
});
