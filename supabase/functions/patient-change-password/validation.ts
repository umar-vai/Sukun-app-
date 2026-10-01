export type ChangePasswordInput = {
  currentPassword: string;
  newPassword: string;
};

export function parseChangePasswordInput(value: unknown): ChangePasswordInput {
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    throw new Error("A request body is required.");
  }
  const body = value as Record<string, unknown>;
  const currentPassword = typeof body.current_password === "string"
    ? body.current_password
    : "";
  const newPassword = typeof body.new_password === "string" ? body.new_password : "";
  if (currentPassword.length < 8 || currentPassword.length > 72) {
    throw new Error("Enter the current temporary password.");
  }
  if (newPassword.length < 8 || newPassword.length > 72) {
    throw new Error("The new password must be between 8 and 72 characters.");
  }
  if (newPassword === currentPassword) {
    throw new Error("Choose a new password that is different from the temporary password.");
  }
  return { currentPassword, newPassword };
}
