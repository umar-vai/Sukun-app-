// A verified Patient session alone does not prove knowledge of the current
// password. The explicit re-sign-in must match the *same* Auth user before
// changing credentials, even when the project's optional GoTrue
// "require current password" toggle is disabled.
export type PasswordProof = {
  user: { id: string } | null;
  session: unknown | null;
  error: unknown;
};

export function isVerifiedCurrentPassword(
  proof: PasswordProof,
  expectedUserId: string,
): boolean {
  return proof.error == null &&
    proof.user?.id === expectedUserId &&
    proof.session != null;
}
