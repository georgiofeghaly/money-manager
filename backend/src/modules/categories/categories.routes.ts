import { randomUUID } from "node:crypto";
import { and, eq, isNull, or } from "drizzle-orm";
import { Elysia, t } from "elysia";

import { withUserScope } from "../../db/client";
import { categories } from "../../db/schema";
import { requireUserId } from "../../middleware/auth-guard";

const createBody = t.Object({
  kind: t.String(),
  name: t.String(),
  icon: t.Optional(t.String()),
  color: t.Optional(t.Number()),
});

const updateBody = t.Object({
  name: t.Optional(t.String()),
  icon: t.Optional(t.String()),
  color: t.Optional(t.Number()),
});

export const categoriesRoutes = new Elysia({ prefix: "/categories" })
  // Global seed categories (user_id IS NULL) plus this user's own.
  .get("/", async ({ headers }) => {
    const userId = await requireUserId(headers);
    return withUserScope(userId, (tx) =>
      tx
        .select()
        .from(categories)
        .where(
          and(
            isNull(categories.deletedAt),
            or(isNull(categories.userId), eq(categories.userId, userId)),
          ),
        ),
    );
  })
  .post(
    "/",
    async ({ headers, body }) => {
      const userId = await requireUserId(headers);
      const [row] = await withUserScope(userId, (tx) =>
        tx
          .insert(categories)
          .values({
            id: randomUUID(),
            userId,
            kind: body.kind,
            name: body.name,
            icon: body.icon,
            color: body.color,
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
          .update(categories)
          .set({
            ...(body.name !== undefined && { name: body.name }),
            ...(body.icon !== undefined && { icon: body.icon }),
            ...(body.color !== undefined && { color: body.color }),
            updatedAt: new Date(),
          })
          // userId scoping here also guards against editing a seed
          // category (user_id NULL never matches), on top of RLS.
          .where(and(eq(categories.id, params.id), eq(categories.userId, userId)))
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
        .update(categories)
        .set({ deletedAt: new Date(), updatedAt: new Date() })
        .where(and(eq(categories.id, params.id), eq(categories.userId, userId)))
        .returning(),
    );
    if (!row) {
      set.status = 404;
      return { error: "Not found" };
    }
    return { ok: true };
  });
