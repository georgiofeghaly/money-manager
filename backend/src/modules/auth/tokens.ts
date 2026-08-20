import { createHash, randomBytes } from "node:crypto";
import { jwtVerify, SignJWT } from "jose";

const ACCESS_TOKEN_TTL = "15m";

function jwtSecret(): Uint8Array {
  const secret = process.env.JWT_SECRET;
  if (!secret) throw new Error("JWT_SECRET is not set");
  return new TextEncoder().encode(secret);
}

export async function signAccessToken(userId: string, deviceId: string): Promise<string> {
  return new SignJWT({ deviceId })
    .setProtectedHeader({ alg: "HS256" })
    .setSubject(userId)
    .setIssuedAt()
    .setExpirationTime(ACCESS_TOKEN_TTL)
    .sign(jwtSecret());
}

export interface AccessTokenClaims {
  userId: string;
  deviceId: string;
}

/** Returns the authenticated user+device, or null if the token is missing/invalid/expired. */
export async function verifyAccessToken(token: string): Promise<AccessTokenClaims | null> {
  try {
    const { payload } = await jwtVerify(token, jwtSecret());
    if (typeof payload.sub !== "string" || typeof payload.deviceId !== "string") return null;
    return { userId: payload.sub, deviceId: payload.deviceId };
  } catch {
    return null;
  }
}

export function generateRefreshToken(): string {
  return randomBytes(32).toString("hex");
}

/** Refresh tokens are opaque high-entropy strings, so a plain SHA-256 hash
 * (not a slow password KDF) is enough for at-rest storage. */
export function hashRefreshToken(token: string): string {
  return createHash("sha256").update(token).digest("hex");
}
