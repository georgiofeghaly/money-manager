import { eq } from "drizzle-orm";
import { Elysia } from "elysia";

import { db } from "../../db/client";
import { devices } from "../../db/schema";
import { requireUserId } from "../../middleware/auth-guard";

// Self-scoped: a user's own devices, used by the mobile conflict-resolution
// UI to label a conflict "edited on Tablet" instead of a raw device UUID.
// Not RLS-scoped (devices isn't an RLS table) — scoped by the explicit
// `eq(devices.userId, userId)` filter below instead, same as auth.routes.ts.
export const devicesRoutes = new Elysia({ prefix: "/devices" }).get("/", async ({ headers }) => {
  const userId = await requireUserId(headers);
  return db
    .select({
      id: devices.id,
      deviceName: devices.deviceName,
      lastSeenAt: devices.lastSeenAt,
    })
    .from(devices)
    .where(eq(devices.userId, userId));
});
