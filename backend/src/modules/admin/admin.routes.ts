import { randomBytes } from "node:crypto";
import { eq } from "drizzle-orm";
import { Elysia, t } from "elysia";

import { db } from "../../db/client";
import { devices, users } from "../../db/schema";
import { requireAdmin } from "../../middleware/admin-guard";

const createUserBody = t.Object({
  email: t.String({ format: "email" }),
  displayName: t.Optional(t.String()),
  isAdmin: t.Optional(t.Boolean()),
});

// Metadata-only by design: this module must never import or query
// accounts/categories/transactions/budgets. Those tables are the ones RLS
// actually protects (see db/rls.sql) — users/devices sit outside RLS, so
// admin's "no financial data" boundary is enforced here, in code, not by
// the database. Keep it that way; don't add a route that reaches into a
// user's financial tables "just for support," even read-only.
export const adminRoutes = new Elysia({ prefix: "/admin" })
  .get("/users", async ({ headers }) => {
    await requireAdmin(headers);
    return db
      .select({
        id: users.id,
        email: users.email,
        displayName: users.displayName,
        isActive: users.isActive,
        isAdmin: users.isAdmin,
        createdAt: users.createdAt,
      })
      .from(users);
  })
  .get("/users/:id/devices", async ({ headers, params }) => {
    await requireAdmin(headers);
    return db
      .select({
        id: devices.id,
        deviceName: devices.deviceName,
        lastSeenAt: devices.lastSeenAt,
        createdAt: devices.createdAt,
        revokedAt: devices.revokedAt,
        lastSyncAt: devices.lastSyncAt,
        lastSyncStatus: devices.lastSyncStatus,
      })
      .from(devices)
      .where(eq(devices.userId, params.id));
  })
  // The only HTTP path that creates a user — still admin-gated, never
  // public. Mirrors create-user.ts's provisioning logic (random password,
  // argon2id via Bun.password) so both paths stay equivalent.
  .post(
    "/users",
    async ({ headers, body, set }) => {
      await requireAdmin(headers);

      const password = randomBytes(12).toString("base64url");
      const passwordHash = await Bun.password.hash(password);

      const [existing] = await db
        .select({ id: users.id })
        .from(users)
        .where(eq(users.email, body.email))
        .limit(1);
      if (existing) {
        set.status = 409;
        return { error: "A user with that email already exists" };
      }

      const [user] = await db
        .insert(users)
        .values({
          email: body.email,
          displayName: body.displayName,
          passwordHash,
          isAdmin: body.isAdmin ?? false,
        })
        .returning({ id: users.id, email: users.email, displayName: users.displayName });

      if (!user) {
        set.status = 500;
        return { error: "Insert returned no row" };
      }

      // Returned once, same convention as create-user.ts — never stored or
      // logged in plaintext anywhere after this response.
      return { ...user, generatedPassword: password };
    },
    { body: createUserBody },
  );
