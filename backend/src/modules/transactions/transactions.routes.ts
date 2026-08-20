import { randomUUID } from "node:crypto";
import { and, eq, isNull } from "drizzle-orm";
import { Elysia, t } from "elysia";

import { withUserScope } from "../../db/client";
import { transactions } from "../../db/schema";
import { requireUserId } from "../../middleware/auth-guard";

const createBody = t.Object({
  type: t.String(),
  amount: t.Number(),
  occurredAt: t.String({ format: "date-time" }),
  accountId: t.String({ format: "uuid" }),
  transferToAccountId: t.Optional(t.String({ format: "uuid" })),
  categoryId: t.Optional(t.String({ format: "uuid" })),
  note: t.Optional(t.String()),
});

const updateBody = t.Object({
  type: t.Optional(t.String()),
  amount: t.Optional(t.Number()),
  occurredAt: t.Optional(t.String({ format: "date-time" })),
  accountId: t.Optional(t.String({ format: "uuid" })),
  transferToAccountId: t.Optional(t.Nullable(t.String({ format: "uuid" }))),
  categoryId: t.Optional(t.Nullable(t.String({ format: "uuid" }))),
  note: t.Optional(t.Nullable(t.String())),
});

export const transactionsRoutes = new Elysia({ prefix: "/transactions" })
  .get("/", async ({ headers }) => {
    const userId = await requireUserId(headers);
    return withUserScope(userId, (tx) =>
      tx.select().from(transactions).where(isNull(transactions.deletedAt)),
    );
  })
  .post(
    "/",
    async ({ headers, body }) => {
      const userId = await requireUserId(headers);
      const [row] = await withUserScope(userId, (tx) =>
        tx
          .insert(transactions)
          .values({
            id: randomUUID(),
            userId,
            type: body.type,
            amount: body.amount,
            occurredAt: new Date(body.occurredAt),
            accountId: body.accountId,
            transferToAccountId: body.transferToAccountId,
            categoryId: body.categoryId,
            note: body.note,
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
          .update(transactions)
          .set({
            ...(body.type !== undefined && { type: body.type }),
            ...(body.amount !== undefined && { amount: body.amount }),
            ...(body.occurredAt !== undefined && {
              occurredAt: new Date(body.occurredAt),
            }),
            ...(body.accountId !== undefined && { accountId: body.accountId }),
            ...(body.transferToAccountId !== undefined && {
              transferToAccountId: body.transferToAccountId,
            }),
            ...(body.categoryId !== undefined && { categoryId: body.categoryId }),
            ...(body.note !== undefined && { note: body.note }),
            updatedAt: new Date(),
          })
          .where(and(eq(transactions.id, params.id), eq(transactions.userId, userId)))
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
        .update(transactions)
        .set({ deletedAt: new Date(), updatedAt: new Date() })
        .where(and(eq(transactions.id, params.id), eq(transactions.userId, userId)))
        .returning(),
    );
    if (!row) {
      set.status = 404;
      return { error: "Not found" };
    }
    return { ok: true };
  });
