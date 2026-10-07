export type DocumentExtractionInput = {
  attachmentId: string;
  requestId: string;
};

const uuidPattern =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

export function parseDocumentExtractionInput(
  value: unknown,
): DocumentExtractionInput {
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    throw new Error("Choose a prescription file and try again.");
  }
  const object = value as Record<string, unknown>;
  if (
    typeof object.attachment_id !== "string" ||
    !uuidPattern.test(object.attachment_id)
  ) {
    throw new Error("Choose a prescription file and try again.");
  }
  if (
    typeof object.request_id !== "string" ||
    !uuidPattern.test(object.request_id)
  ) {
    throw new Error("Please try reading the prescription again.");
  }
  return {
    attachmentId: object.attachment_id,
    requestId: object.request_id,
  };
}

export type SupportedDocumentMime =
  | "application/pdf"
  | "image/jpeg"
  | "image/png";

export function validateDocumentBytes(
  bytes: Uint8Array,
  mimeType: string,
  expectedSize: number,
): asserts mimeType is SupportedDocumentMime {
  if (bytes.length < 4 || bytes.length !== expectedSize) {
    throw new InvalidDocumentError();
  }
  if (bytes.length > 10 * 1024 * 1024) {
    throw new InvalidDocumentError(
      "Prescription files must be 10 MB or smaller.",
    );
  }
  const valid = mimeType === "application/pdf"
    ? startsWith(bytes, [0x25, 0x50, 0x44, 0x46, 0x2d])
    : mimeType === "image/jpeg"
    ? startsWith(bytes, [0xff, 0xd8, 0xff])
    : mimeType === "image/png"
    ? startsWith(bytes, [0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a])
    : false;
  if (!valid) throw new InvalidDocumentError();
}

export class InvalidDocumentError extends Error {
  constructor(
    message =
      "This file is empty, damaged, or is not a supported PDF, JPG, or PNG.",
  ) {
    super(message);
    this.name = "InvalidDocumentError";
  }
}

function startsWith(bytes: Uint8Array, signature: number[]): boolean {
  return signature.every((value, index) => bytes[index] === value);
}
