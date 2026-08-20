import { and, eq, ne } from "drizzle-orm";
import { Elysia, t } from "elysia";

import { db } from "../../db/client";
import { devices, users } from "../../db/schema";
import { requireAuth } from "../../middleware/auth-guard";
import {
  generateRefreshToken,
  hashRefreshToken,
  signAccessToken,
} from "./tokens";

const loginBody = t.Object({
  email: t.String(),
  password: t.String(),
  deviceId: t.String({ format: "uuid" }),
  deviceName: t.Optional(t.String()),
});

const refreshBody = t.Object({
  deviceId: t.String({ format: "uuid" }),
  refreshToken: t.String(),
});

const changePasswordBody = t.Object({
  currentPassword: t.String(),
  newPassword: t.String({ minLength: 8 }),
});

export const authRoutes = new Elysia({ prefix: "/auth" })
  // Login: verify email+password, then upsert this device's row (a device
  // logging in again just rotates its refresh token, doesn't duplicate).
  .post(
    "/login",
    async ({ body, set }) => {
      const { email, password, deviceId, deviceName } = body;

      const [user] = await db.select().from(users).where(eq(users.email, email)).limit(1);
      if (!user || !user.isActive || !(await Bun.password.verify(password, user.passwordHash))) {
        set.status = 401;
        return { error: "Invalid credentials" };
      }

      const refreshToken = generateRefreshToken();

      await db
        .insert(devices)
        .values({
          id: deviceId,
          userId: user.id,
          deviceName,
          refreshTokenHash: hashRefreshToken(refreshToken),
          lastSeenAt: new Date(),
        })
        .onConflictDoUpdate({
          target: devices.id,
          set: {
            deviceName,
            refreshTokenHash: hashRefreshToken(refreshToken),
            lastSeenAt: new Date(),
            revokedAt: null,
          },
        });

      const accessToken = await signAccessToken(user.id, deviceId);
      return { accessToken, refreshToken, userId: user.id };
    },
    { body: loginBody },
  )
  // Refresh: rotate the refresh token on every use (reduces replay risk if
  // an old token ever leaks) and issue a fresh short-lived access token.
  .post(
    "/refresh",
    async ({ body, set }) => {
      const { deviceId, refreshToken } = body;

      const [device] = await db
        .select()
        .from(devices)
        .where(and(eq(devices.id, deviceId), eq(devices.refreshTokenHash, hashRefreshToken(refreshToken))))
        .limit(1);

      if (!device || device.revokedAt) {
        set.status = 401;
        return { error: "Invalid refresh token" };
      }

      const newRefreshToken = generateRefreshToken();
      await db
        .update(devices)
        .set({ refreshTokenHash: hashRefreshToken(newRefreshToken), lastSeenAt: new Date() })
        .where(eq(devices.id, deviceId));

      const accessToken = await signAccessToken(device.userId, deviceId);
      return { accessToken, refreshToken: newRefreshToken };
    },
    { body: refreshBody },
  )
  // Changing your password revokes every *other* device's session (forces
  // re-login there) — the current device stays logged in since it just
  // proved it knows the old password. There's no dedicated device-management
  // UI yet (Phase 5), so this is the only way a compromised device's access
  // gets cut off today.
  .patch(
    "/password",
    async ({ headers, body, set }) => {
      const { userId, deviceId } = await requireAuth(headers);
      const { currentPassword, newPassword } = body;

      const [user] = await db.select().from(users).where(eq(users.id, userId)).limit(1);
      if (!user || !(await Bun.password.verify(currentPassword, user.passwordHash))) {
        set.status = 401;
        return { error: "Current password is incorrect" };
      }

      const newHash = await Bun.password.hash(newPassword);
      await db.update(users).set({ passwordHash: newHash }).where(eq(users.id, userId));

      await db
        .update(devices)
        .set({ revokedAt: new Date() })
        .where(and(eq(devices.userId, userId), ne(devices.id, deviceId)));

      return { ok: true };
    },
    { body: changePasswordBody },
  );
