import { randomUUID } from "node:crypto";
import { and, eq, isNull } from "drizzle-orm";
import { Elysia, t } from "elysia";

import { withUserScope } from "../../db/client";
import { budgets } from "../../db/schema";
import { requireUserId } from "../../middleware/auth-guard";

const createBody = t.Object({
  categoryId: t.String({ format: "uuid" }),
  periodMonth: t.String({ format: "date-time" }),
  limitAmount: t.Number(),
});

const updateBody = t.Object({
  limitAmount: t.Optional(t.Number()),
});

export const budgetsRoutes = new Elysia({ prefix: "/budgets" })
  .get("/", async ({ headers }) => {
    const userId = await requireUserId(headers);
    return withUserScope(userId, (tx) =>
      tx.select().from(budgets).where(isNull(budgets.deletedAt)),
    );
  })
  .post(
    "/",
    async ({ headers, body }) => {
      const userId = await requireUserId(headers);
      const [row] = await withUserScope(userId, (tx) =>
        tx
          .insert(budgets)
          .values({
            id: randomUUID(),
            userId,
            categoryId: body.categoryId,
            periodMonth: new Date(body.periodMonth),
            limitAmount: body.limitAmount,
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
          .update(budgets)
          .set({
            ...(body.limitAmount !== undefined && { limitAmount: body.limitAmount }),
            updatedAt: new Date(),
          })
          .where(and(eq(budgets.id, params.id), eq(budgets.userId, userId)))
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
        .update(budgets)
        .set({ deletedAt: new Date(), updatedAt: new Date() })
        .where(and(eq(budgets.id, params.id), eq(budgets.userId, userId)))
        .returning(),
    );
    if (!row) {
      set.status = 404;
      return { error: "Not found" };
    }
    return { ok: true };
  });
