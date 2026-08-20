import type { AccessTokenClaims } from "../modules/auth/tokens";
import { verifyAccessToken } from "../modules/auth/tokens";

export class UnauthorizedError extends Error {
  constructor(message = "Unauthorized") {
    super(message);
  }
}

function extractBearerToken(headers: Record<string, string | undefined>): string {
  const authHeader = headers.authorization;
  const token = authHeader?.startsWith("Bearer ") ? authHeader.slice(7) : undefined;
  if (!token) throw new UnauthorizedError("Missing bearer token");
  return token;
}

/** Every authenticated route handler starts by calling this with its
 * `headers` object; throws UnauthorizedError (mapped to a 401 by
 * index.ts's onError handler) if the bearer token is missing/invalid. */
export async function requireAuth(
  headers: Record<string, string | undefined>,
): Promise<AccessTokenClaims> {
  const claims = await verifyAccessToken(extractBearerToken(headers));
  if (!claims) throw new UnauthorizedError("Invalid or expired token");
  return claims;
}

/** Convenience wrapper for the common case of only needing the user id. */
export async function requireUserId(
  headers: Record<string, string | undefined>,
): Promise<string> {
  return (await requireAuth(headers)).userId;
}
