import { randomUUID } from "node:crypto";
import { and, eq, isNull } from "drizzle-orm";
import { Elysia, t } from "elysia";

import { withUserScope } from "../../db/client";
import { accounts } from "../../db/schema";
import { requireUserId } from "../../middleware/auth-guard";

const createBody = t.Object({
  name: t.String(),
  type: t.String(),
  startingBalance: t.Optional(t.Number()),
});

const updateBody = t.Object({
  name: t.Optional(t.String()),
  type: t.Optional(t.String()),
  startingBalance: t.Optional(t.Number()),
  archived: t.Optional(t.Boolean()),
});

export const accountsRoutes = new Elysia({ prefix: "/accounts" })
  .get("/", async ({ headers }) => {
    const userId = await requireUserId(headers);
    return withUserScope(userId, (tx) =>
      tx.select().from(accounts).where(isNull(accounts.deletedAt)),
    );
  })
  .post(
    "/",
    async ({ headers, body }) => {
      const userId = await requireUserId(headers);
      const [row] = await withUserScope(userId, (tx) =>
        tx
          .insert(accounts)
          .values({
            id: randomUUID(),
            userId,
            name: body.name,
            type: body.type,
            startingBalance: body.startingBalance ?? 0,
            updatedAt: new Date(),
          })
          .returning(),
      );
      return row;
    },
    { body: createBody },
  )
  .patch(
    "/:id",
    async ({ headers, params, body, set }) => {
      const userId = await requireUserId(headers);
      const [row] = await withUserScope(userId, (tx) =>
        tx
          .update(accounts)
          .set({
            ...(body.name !== undefined && { name: body.name }),
            ...(body.type !== undefined && { type: body.type }),
            ...(body.startingBalance !== undefined && {
              startingBalance: body.startingBalance,
            }),
            ...(body.archived !== undefined && {
              archivedAt: body.archived ? new Date() : null,
            }),
            updatedAt: new Date(),
          })
          .where(and(eq(accounts.id, params.id), eq(accounts.userId, userId)))
          .returning(),
      );
      if (!row) {
        set.status = 404;
        return { error: "Not found" };
      }
      return row;
    },
    { body: updateBody },
  )
  .delete("/:id", async ({ headers, params, set }) => {
    const userId = await requireUserId(headers);
    const [row] = await withUserScope(userId, (tx) =>
      tx
        .update(accounts)
        .set({ deletedAt: new Date(), updatedAt: new Date() })
        .where(and(eq(accounts.id, params.id), eq(accounts.userId, userId)))
        .returning(),
    );
    if (!row) {
      set.status = 404;
      return { error: "Not found" };
    }
    return { ok: true };
  });
