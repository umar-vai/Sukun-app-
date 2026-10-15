// Use the licensed, attributed public stream when Quran Foundation's complete
// production API has not been provisioned. Credentials never reach the client.
export function useAttributedPublicQuran(
  environment: string | undefined,
  clientId: string | undefined,
  clientSecret: string | undefined,
): boolean {
  return environment !== "production" || !clientId?.trim() ||
    !clientSecret?.trim();
}
