export type FirebaseServiceAccount = {
  projectId: string;
  clientEmail: string;
  privateKey: string;
};

export type FirebaseMessage = {
  token: string;
  notification: { title: string; body: string };
  data: Record<string, string>;
  android: { priority: "high" };
  apns: {
    payload: { aps: { sound: "default"; "content-available": number } };
  };
};

export type FirebaseSendResult = {
  ok: boolean;
  messageId?: string;
  invalidToken: boolean;
};

export function parseServiceAccount(raw: string): FirebaseServiceAccount {
  const value = JSON.parse(raw) as Record<string, unknown>;
  const projectId = value.project_id;
  const clientEmail = value.client_email;
  const privateKey = value.private_key;
  if (
    typeof projectId !== "string" || !projectId.trim() ||
    typeof clientEmail !== "string" || !clientEmail.trim() ||
    typeof privateKey !== "string" || !privateKey.includes("PRIVATE KEY")
  ) {
    throw new Error("Firebase server credentials are not configured.");
  }
  return { projectId, clientEmail, privateKey };
}

export function buildPlanUpdatedMessage(
  token: string,
  carePlanId: string,
): FirebaseMessage {
  return {
    token,
    notification: {
      title: "Sukun Life",
      body: "Your care plan has been updated.",
    },
    data: { type: "plan_updated", care_plan_id: carePlanId },
    android: { priority: "high" },
    apns: {
      payload: { aps: { sound: "default", "content-available": 1 } },
    },
  };
}

export async function createFirebaseAccessToken(
  account: FirebaseServiceAccount,
  fetcher: typeof fetch = fetch,
): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  const header = base64Url(JSON.stringify({ alg: "RS256", typ: "JWT" }));
  const claims = base64Url(JSON.stringify({
    iss: account.clientEmail,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: "https://oauth2.googleapis.com/token",
    iat: now,
    exp: now + 3600,
  }));
  const signingInput = `${header}.${claims}`;
  const key = await crypto.subtle.importKey(
    "pkcs8",
    pemToBytes(account.privateKey),
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const signature = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    key,
    new TextEncoder().encode(signingInput),
  );
  const assertion = `${signingInput}.${
    base64UrlBytes(new Uint8Array(signature))
  }`;
  const response = await fetcher("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion,
    }),
  });
  if (!response.ok) throw new Error("Firebase authentication is unavailable.");
  const payload = await response.json() as { access_token?: unknown };
  if (typeof payload.access_token !== "string") {
    throw new Error("Firebase authentication is unavailable.");
  }
  return payload.access_token;
}

export async function sendFirebaseMessage(
  account: FirebaseServiceAccount,
  accessToken: string,
  message: FirebaseMessage,
  fetcher: typeof fetch = fetch,
): Promise<FirebaseSendResult> {
  const response = await fetcher(
    `https://fcm.googleapis.com/v1/projects/${
      encodeURIComponent(account.projectId)
    }/messages:send`,
    {
      method: "POST",
      headers: {
        Authorization: `Bearer ${accessToken}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({ message }),
    },
  );
  if (response.ok) {
    const payload = await response.json() as { name?: unknown };
    return {
      ok: true,
      messageId: typeof payload.name === "string" ? payload.name : undefined,
      invalidToken: false,
    };
  }
  const body = await response.text();
  return {
    ok: false,
    invalidToken: response.status === 404 ||
      body.includes("UNREGISTERED") || body.includes("INVALID_ARGUMENT"),
  };
}

function pemToBytes(pem: string): ArrayBuffer {
  const contents = pem.replace(
    /-----BEGIN PRIVATE KEY-----|-----END PRIVATE KEY-----|\s/g,
    "",
  );
  return Uint8Array.from(
    atob(contents),
    (character) => character.charCodeAt(0),
  ).buffer as ArrayBuffer;
}

function base64Url(value: string): string {
  return base64UrlBytes(new TextEncoder().encode(value));
}

function base64UrlBytes(value: Uint8Array): string {
  let binary = "";
  for (const byte of value) binary += String.fromCharCode(byte);
  return btoa(binary).replaceAll("+", "-").replaceAll("/", "_").replace(
    /=+$/,
    "",
  );
}
