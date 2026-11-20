// Pure helpers for one-time account activation. No runtime globals beyond
// Web Crypto and fetch (injected), so they run in Deno and Node tests.
import { sha256Hex } from "./crm_auth.ts";

const BASE64URL = /[+/=]/g;

/** 256 bit random token, URL safe. Exists only inside the delivered link. */
export function generateActivationToken(): string {
  const bytes = crypto.getRandomValues(new Uint8Array(32));
  return btoa(String.fromCharCode(...bytes)).replace(
    BASE64URL,
    (c) => c === "+" ? "-" : c === "/" ? "_" : "",
  );
}

export function hashActivationToken(token: string): Promise<string> {
  return sha256Hex(token);
}

/** Random password nobody knows. The patient sets the real one on activation. */
export function generateUnknownPassword(): string {
  return generateActivationToken() + "Aa1";
}

export function generatePatientCode(now = new Date()): string {
  const alphabet = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
  const bytes = crypto.getRandomValues(new Uint8Array(6));
  const suffix = Array.from(bytes, (v) => alphabet[v % alphabet.length]).join(
    "",
  );
  return `SL-${now.getUTCFullYear()}-${suffix}`;
}

export type NormalizedPhone = { e164: string; digits: string };

/** Bangladesh mobile numbers only: 01[3-9]XXXXXXXX in any common spelling. */
export function normalizeBangladeshPhone(raw: string): NormalizedPhone | null {
  let value = raw.replace(/[\s()-]/g, "");
  if (value.startsWith("+")) value = value.slice(1);
  if (value.startsWith("00")) value = value.slice(2);
  if (value.startsWith("880")) value = value.slice(3);
  if (value.startsWith("0")) value = value.slice(1);
  if (!/^1[3-9][0-9]{8}$/.test(value)) return null;
  return { e164: `+880${value}`, digits: `880${value}` };
}

/**
 * The token goes in the URL fragment, so it is never sent to a server or
 * written to an access log when the page loads.
 */
export function buildActivationLink(baseUrl: string, token: string): string {
  return `${baseUrl.replace(/\/+$/, "")}/activate#token=${token}`;
}

export type WhatsAppConfig = {
  accessToken: string;
  phoneNumberId: string;
  templateName: string;
  languageCode: string;
};

export function readWhatsAppConfig(
  get: (name: string) => string | undefined,
): WhatsAppConfig | null {
  const accessToken = get("WHATSAPP_ACCESS_TOKEN");
  const phoneNumberId = get("WHATSAPP_PHONE_NUMBER_ID");
  const templateName = get("WHATSAPP_ACTIVATION_TEMPLATE");
  if (!accessToken || !phoneNumberId || !templateName) return null;
  return {
    accessToken,
    phoneNumberId,
    templateName,
    languageCode: get("WHATSAPP_TEMPLATE_LANGUAGE") ?? "bn",
  };
}

export type Delivery = "sent" | "failed" | "not_configured";

/**
 * Sends the activation link with a pre-approved WhatsApp template (Meta Cloud
 * API). The template has one body variable: the link. NOT yet exercised
 * against a real WhatsApp Business account.
 */
export async function sendActivationWhatsApp(
  input: {
    config: WhatsAppConfig | null;
    toDigits: string;
    link: string;
    fetchImpl?: typeof fetch;
  },
): Promise<Delivery> {
  if (!input.config) return "not_configured";
  const doFetch = input.fetchImpl ?? fetch;
  try {
    const response = await doFetch(
      `https://graph.facebook.com/v21.0/${input.config.phoneNumberId}/messages`,
      {
        method: "POST",
        headers: {
          "Authorization": `Bearer ${input.config.accessToken}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          messaging_product: "whatsapp",
          to: input.toDigits,
          type: "template",
          template: {
            name: input.config.templateName,
            language: { code: input.config.languageCode },
            components: [{
              type: "body",
              parameters: [{ type: "text", text: input.link }],
            }],
          },
        }),
        signal: AbortSignal.timeout(10_000),
      },
    );
    return response.ok ? "sent" : "failed";
  } catch {
    return "failed";
  }
}
