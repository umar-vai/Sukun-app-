// Scoped Firebase Cloud Messaging adapter for Flutter Web.
// All config keys here are public Firebase CLIENT identifiers.
let messaging;
let worker;
let unlisten;
const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
function config() { return globalThis.sukunWebPushConfig || {}; }
const api = {
  isAvailable() {
    const c = config();
    return Boolean(c.enabled && c.apiKey && c.appId && c.projectId &&
      c.messagingSenderId && c.vapidKey &&
      "serviceWorker" in navigator && "Notification" in window &&
      window.isSecureContext);
  },
  async getToken() {
    if (!api.isAvailable()) return null;
    if (Notification.permission !== "granted") return null;
    if (!messaging) {
      const appLib = await import("https://www.gstatic.com/firebasejs/11.10.0/firebase-app.js");
      const messageLib = await import("https://www.gstatic.com/firebasejs/11.10.0/firebase-messaging.js");
      const c = config();
      const firebaseApp = appLib.initializeApp({
        apiKey: c.apiKey, appId: c.appId, projectId: c.projectId,
        messagingSenderId: c.messagingSenderId,
      }, "sukun-browser-push");
      messaging = messageLib.getMessaging(firebaseApp);
      const scope = new URL(document.baseURI);
      worker = await navigator.serviceWorker.register(
        new URL("firebase-messaging-sw.js", scope).href,
        { scope: scope.pathname }
      );
      // Store only opaque task ID in JavaScript events, not provider text.
      unlisten = messageLib.onMessage(messaging, (payload) => {
        const data = payload?.data || {};
        window.dispatchEvent(new CustomEvent("sukun-web-push-message", {
          detail: JSON.stringify({ type: data.type || "", task_id:
            uuid.test(data.task_id || "") ? data.task_id : "" })
        }));
      });
      api._messageLib = messageLib;
    }
    return (await api._messageLib.getToken(messaging, {
      vapidKey: config().vapidKey, serviceWorkerRegistration: worker
    })) || null;
  },
  async deleteToken() {
    if (!messaging || !api._messageLib) return;
    await api._messageLib.deleteToken(messaging);
    if (unlisten) { unlisten(); unlisten = null; }
  },
  _messageLib: null
};
globalThis.sukunWebPush = Object.freeze(api);
