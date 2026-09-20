import { and, asc, eq, gt, or } from "drizzle-orm";
import type { AnyPgColumn } from "drizzle-orm/pg-core";
import { Elysia } from "elysia";

import { db, withUserScope } from "../../db/client";
import { accounts, budgets, categories, devices, transactions } from "../../db/schema";
import { requireAuth } from "../../middleware/auth-guard";
import { pullQuery, pushBody } from "./sync.schemas";
import { SYNC_TABLE_ORDER } from "./tables";

type Tx = Parameters<Parameters<typeof db.transaction>[0]>[0];

const PULL_PAGE_LIMIT = 500;

// ---- push -------------------------------------------------------------
//
// Per row: no existing server row -> INSERT (version 1). Existing row whose
// version matches the row's `localBaseVersion` -> UPDATE (version+1),
// accepted. Existing row whose version differs -> CONFLICT, nothing
// written, the server's current row is returned so the client can show a
// diff. Soft-deletes (deletedAt) flow through the same accept/conflict path
// as any other field change — there's no separate delete branch.
//
// A row absent on the server is always inserted regardless of
// `localBaseVersion`: since rows are never hard-deleted server-side (see
// schema.ts's deletedAt/tombstone convention), "absent" only happens for a
// row that's genuinely new, so there's nothing to conflict against.

async function pushAccounts(
  tx: Tx,
  userId: string,
  deviceId: string,
  rows: (typeof pushBody.static)["tables"]["accounts"],
) {
  const accepted: (typeof accounts.$inferSelect)[] = [];
  const conflicts: (typeof accounts.$inferSelect)[] = [];
  for (const row of rows) {
    const [existing] = await tx
      .select()
      .from(accounts)
      .where(and(eq(accounts.id, row.id), eq(accounts.userId, userId)));

    if (!existing) {
      const [inserted] = await tx
        .insert(accounts)
        .values({
          id: row.id,
          userId,
          name: row.name,
          type: row.type,
          startingBalance: row.startingBalance,
          archivedAt: row.archivedAt ? new Date(row.archivedAt) : null,
          deletedAt: row.deletedAt ? new Date(row.deletedAt) : null,
          updatedAt: new Date(),
          version: 1,
          originDeviceId: deviceId,
        })
        .returning();
      if (inserted) accepted.push(inserted);
      continue;
    }

    if (existing.version !== row.localBaseVersion) {
      conflicts.push(existing);
      continue;
    }

    const [updated] = await tx
      .update(accounts)
      .set({
        name: row.name,
        type: row.type,
        startingBalance: row.startingBalance,
        archivedAt: row.archivedAt ? new Date(row.archivedAt) : null,
        deletedAt: row.deletedAt ? new Date(row.deletedAt) : null,
        updatedAt: new Date(),
        version: existing.version + 1,
        originDeviceId: deviceId,
      })
      .where(eq(accounts.id, row.id))
      .returning();
    if (updated) accepted.push(updated);
  }
  return { accepted, conflicts };
}

async function pushCategories(
  tx: Tx,
  userId: string,
  deviceId: string,
  rows: (typeof pushBody.static)["tables"]["categories"],
) {
  const accepted: (typeof categories.$inferSelect)[] = [];
  const conflicts: (typeof categories.$inferSelect)[] = [];
  for (const row of rows) {
    // Only ever operates on this user's own categories — global seed
    // categories (userId IS NULL) are never pushed/edited by a client.
    const [existing] = await tx
      .select()
      .from(categories)
      .where(and(eq(categories.id, row.id), eq(categories.userId, userId)));

    if (!existing) {
      const [inserted] = await tx
        .insert(categories)
        .values({
          id: row.id,
          userId,
          kind: row.kind,
          name: row.name,
          icon: row.icon ?? null,
          color: row.color ?? null,
          deletedAt: row.deletedAt ? new Date(row.deletedAt) : null,
          updatedAt: new Date(),
          version: 1,
          originDeviceId: deviceId,
        })
        .returning();
      if (inserted) accepted.push(inserted);
      continue;
    }

    if (existing.version !== row.localBaseVersion) {
      conflicts.push(existing);
      continue;
    }

    const [updated] = await tx
      .update(categories)
      .set({
        name: row.name,
        icon: row.icon ?? null,
        color: row.color ?? null,
        deletedAt: row.deletedAt ? new Date(row.deletedAt) : null,
        updatedAt: new Date(),
        version: existing.version + 1,
        originDeviceId: deviceId,
      })
      .where(eq(categories.id, row.id))
      .returning();
    if (updated) accepted.push(updated);
  }
  return { accepted, conflicts };
}

async function pushTransactions(
  tx: Tx,
  userId: string,
  deviceId: string,
  rows: (typeof pushBody.static)["tables"]["transactions"],
) {
  const accepted: (typeof transactions.$inferSelect)[] = [];
  const conflicts: (typeof transactions.$inferSelect)[] = [];
  for (const row of rows) {
    const [existing] = await tx
      .select()
      .from(transactions)
      .where(and(eq(transactions.id, row.id), eq(transactions.userId, userId)));

    if (!existing) {
      const [inserted] = await tx
        .insert(transactions)
        .values({
          id: row.id,
          userId,
          type: row.type,
          amount: row.amount,
          occurredAt: new Date(row.occurredAt),
          accountId: row.accountId,
          transferToAccountId: row.transferToAccountId ?? null,
          categoryId: row.categoryId ?? null,
          note: row.note ?? null,
          deletedAt: row.deletedAt ? new Date(row.deletedAt) : null,
          updatedAt: new Date(),
          version: 1,
          originDeviceId: deviceId,
        })
        .returning();
      if (inserted) accepted.push(inserted);
      continue;
    }

    if (existing.version !== row.localBaseVersion) {
      conflicts.push(existing);
      continue;
    }

    const [updated] = await tx
      .update(transactions)
      .set({
        type: row.type,
        amount: row.amount,
        occurredAt: new Date(row.occurredAt),
        accountId: row.accountId,
        transferToAccountId: row.transferToAccountId ?? null,
        categoryId: row.categoryId ?? null,
        note: row.note ?? null,
        deletedAt: row.deletedAt ? new Date(row.deletedAt) : null,
        updatedAt: new Date(),
        version: existing.version + 1,
        originDeviceId: deviceId,
      })
      .where(eq(transactions.id, row.id))
      .returning();
    if (updated) accepted.push(updated);
  }
  return { accepted, conflicts };
}

async function pushBudgets(
  tx: Tx,
  userId: string,
  deviceId: string,
  rows: (typeof pushBody.static)["tables"]["budgets"],
) {
  const accepted: (typeof budgets.$inferSelect)[] = [];
  const conflicts: (typeof budgets.$inferSelect)[] = [];
  for (const row of rows) {
    const [existing] = await tx
      .select()
      .from(budgets)
      .where(and(eq(budgets.id, row.id), eq(budgets.userId, userId)));

    if (!existing) {
      const [inserted] = await tx
        .insert(budgets)
        .values({
          id: row.id,
          userId,
          categoryId: row.categoryId,
          periodMonth: new Date(row.periodMonth),
          limitAmount: row.limitAmount,
          deletedAt: row.deletedAt ? new Date(row.deletedAt) : null,
          updatedAt: new Date(),
          version: 1,
          originDeviceId: deviceId,
        })
        .returning();
      if (inserted) accepted.push(inserted);
      continue;
    }

    if (existing.version !== row.localBaseVersion) {
      conflicts.push(existing);
      continue;
    }

    const [updated] = await tx
      .update(budgets)
      .set({
        categoryId: row.categoryId,
        periodMonth: new Date(row.periodMonth),
        limitAmount: row.limitAmount,
        deletedAt: row.deletedAt ? new Date(row.deletedAt) : null,
        updatedAt: new Date(),
        version: existing.version + 1,
        originDeviceId: deviceId,
      })
      .where(eq(budgets.id, row.id))
      .returning();
    if (updated) accepted.push(updated);
  }
  return { accepted, conflicts };
}

// ---- pull ---------------------------------------------------------------
//
// A composite (updatedAt, id) cursor, not a bare `updatedAt > since` filter
// — with a bare filter, any page boundary that lands mid-timestamp (e.g. a
// bulk CSV import writes many rows in the same instant) would silently
// drop or duplicate rows across pages. `id > cursorId` breaks the tie
// deterministically for rows sharing `since` exactly.

function pullWhere(
  userIdCol: AnyPgColumn,
  updatedAtCol: AnyPgColumn,
  idCol: AnyPgColumn,
  userId: string,
  since: Date,
  cursorId: string,
) {
  return and(
    eq(userIdCol, userId),
    or(gt(updatedAtCol, since), and(eq(updatedAtCol, since), gt(idCol, cursorId))),
  );
}

async function pullAccounts(tx: Tx, userId: string, since: Date, cursorId: string) {
  return tx
    .select()
    .from(accounts)
    .where(pullWhere(accounts.userId, accounts.updatedAt, accounts.id, userId, since, cursorId))
    .orderBy(asc(accounts.updatedAt), asc(accounts.id))
    .limit(PULL_PAGE_LIMIT);
}

async function pullCategories(tx: Tx, userId: string, since: Date, cursorId: string) {
  return tx
    .select()
    .from(categories)
    .where(
      pullWhere(categories.userId, categories.updatedAt, categories.id, userId, since, cursorId),
    )
    .orderBy(asc(categories.updatedAt), asc(categories.id))
    .limit(PULL_PAGE_LIMIT);
}

async function pullTransactions(tx: Tx, userId: string, since: Date, cursorId: string) {
  return tx
    .select()
    .from(transactions)
    .where(
      pullWhere(
        transactions.userId,
        transactions.updatedAt,
        transactions.id,
        userId,
        since,
        cursorId,
      ),
    )
    .orderBy(asc(transactions.updatedAt), asc(transactions.id))
    .limit(PULL_PAGE_LIMIT);
}

async function pullBudgets(tx: Tx, userId: string, since: Date, cursorId: string) {
  return tx
    .select()
    .from(budgets)
    .where(pullWhere(budgets.userId, budgets.updatedAt, budgets.id, userId, since, cursorId))
    .orderBy(asc(budgets.updatedAt), asc(budgets.id))
    .limit(PULL_PAGE_LIMIT);
}

export const syncRoutes = new Elysia({ prefix: "/sync" })
  .post(
    "/push",
    async ({ headers, body }) => {
      const { userId, deviceId } = await requireAuth(headers);
      if (body.deviceId !== deviceId) {
        // The token's deviceId is authoritative; a mismatched body.deviceId
        // would misattribute originDeviceId on every row this push writes.
        return { error: "deviceId does not match the authenticated device" };
      }

      const result = await withUserScope(userId, async (tx) => {
        const accountsResult = await pushAccounts(tx, userId, deviceId, body.tables.accounts);
        const categoriesResult = await pushCategories(
          tx,
          userId,
          deviceId,
          body.tables.categories,
        );
        const transactionsResult = await pushTransactions(
          tx,
          userId,
          deviceId,
          body.tables.transactions,
        );
        const budgetsResult = await pushBudgets(tx, userId, deviceId, body.tables.budgets);

        const hasConflicts =
          accountsResult.conflicts.length > 0 ||
          categoriesResult.conflicts.length > 0 ||
          transactionsResult.conflicts.length > 0 ||
          budgetsResult.conflicts.length > 0;

        await tx
          .update(devices)
          .set({
            lastSyncAt: new Date(),
            lastSyncStatus: hasConflicts ? "error" : "ok",
            lastSyncError: hasConflicts ? "Conflicts pending resolution" : null,
          })
          .where(eq(devices.id, deviceId));

        return {
          accounts: accountsResult,
          categories: categoriesResult,
          transactions: transactionsResult,
          budgets: budgetsResult,
        };
      });

      return {
        accepted: {
          accounts: result.accounts.accepted,
          categories: result.categories.accepted,
          transactions: result.transactions.accepted,
          budgets: result.budgets.accepted,
        },
        conflicts: {
          accounts: result.accounts.conflicts,
          categories: result.categories.conflicts,
          transactions: result.transactions.conflicts,
          budgets: result.budgets.conflicts,
        },
      };
    },
    { body: pushBody },
  )
  .get(
    "/pull",
    async ({ headers, query }) => {
      const userId = await requireAuth(headers).then((c) => c.userId);
      const since = query.since ? new Date(query.since) : new Date(0);
      const cursorId = query.cursorId ?? "";

      const result = await withUserScope(userId, async (tx) => {
        const pages: Record<(typeof SYNC_TABLE_ORDER)[number], unknown[]> = {
          accounts: await pullAccounts(tx, userId, since, cursorId),
          categories: await pullCategories(tx, userId, since, cursorId),
          transactions: await pullTransactions(tx, userId, since, cursorId),
          budgets: await pullBudgets(tx, userId, since, cursorId),
        };

        let hasMore = false;
        let cursorUpdatedAt = since;
        let cursorRowId = cursorId;
        for (const name of SYNC_TABLE_ORDER) {
          const rows = pages[name] as { id: string; updatedAt: Date }[];
          if (rows.length === PULL_PAGE_LIMIT) hasMore = true;
          for (const row of rows) {
            if (
              row.updatedAt > cursorUpdatedAt ||
              (row.updatedAt.getTime() === cursorUpdatedAt.getTime() && row.id > cursorRowId)
            ) {
              cursorUpdatedAt = row.updatedAt;
              cursorRowId = row.id;
            }
          }
        }

        return { pages, hasMore, cursorUpdatedAt, cursorRowId };
      });

      return {
        tables: result.pages,
        nextCursor: result.hasMore
          ? { since: result.cursorUpdatedAt.toISOString(), cursorId: result.cursorRowId }
          : null,
        serverTime: new Date().toISOString(),
      };
    },
    { query: pullQuery },
  );
