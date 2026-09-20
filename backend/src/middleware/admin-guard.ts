import { eq } from "drizzle-orm";

import { db } from "../db/client";
import { users } from "../db/schema";
import { requireUserId } from "./auth-guard";

export class ForbiddenError extends Error {
  constructor(message = "Forbidden") {
    super(message);
  }
}

/** Every /admin/* handler starts by calling this. Checks `isAdmin` with a
 * fresh DB lookup on every request rather than trusting a JWT claim —
 * there's no token-invalidation path if admin status is revoked mid-token,
 * and admin status can't be granted via any HTTP endpoint anyway (only via
 * create-user.ts --admin or a manual SQL UPDATE), so the extra query is
 * cheap and closes that gap. */
export async function requireAdmin(
  headers: Record<string, string | undefined>,
): Promise<string> {
  const userId = await requireUserId(headers);
  const [user] = await db
    .select({ isAdmin: users.isAdmin })
    .from(users)
    .where(eq(users.id, userId))
    .limit(1);
  if (!user?.isAdmin) throw new ForbiddenError("Admin access required");
  return userId;
}
