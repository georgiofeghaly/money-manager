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

// A row rejected by the database (e.g. it references an account/category
// that doesn't exist server-side — orphaned local data from before a wipe,
// or a bug elsewhere) is isolated to its own SAVEPOINT via `tx.transaction`,
// so it can't roll back every other row in the same push. Without this, one
// permanently-broken row in a device's outbox would keep re-submitting on
// every sync and taking the *entire* batch down with it forever, since all
// rows share one Postgres transaction per push request.
type RejectedRow = { id: string; reason: string };

function describeRejection(e: unknown): string {
  const cause = e instanceof Error ? (e as Error & { cause?: unknown }).cause : undefined;
  const code =
    (cause as { code?: string } | undefined)?.code ?? (e as { code?: string } | undefined)?.code;
  switch (code) {
    case "23503":
      return "references a row that does not exist on the server";
    case "23505":
      return "duplicate id";
    case "22P02":
      return "malformed value";
    default:
      return "could not be saved";
  }
}

// Sentinel for "no cursor yet" (first page of a pull). Must be a valid uuid
// literal since it's bound against a `uuid` column — Postgres validates
// parameter types at bind time regardless of whether the OR/AND branch that
// uses it ends up being evaluated, so "" fails before the query even runs.
// The nil uuid sorts below every real generated uuid, so `gt(idCol, ...)`
// behaves the same as "no cursor" should.
const NIL_UUID = "00000000-0000-0000-0000-000000000000";

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
  const rejected: RejectedRow[] = [];
  for (const row of rows) {
    try {
      await tx.transaction(async (stx) => {
        const [existing] = await stx
          .select()
          .from(accounts)
          .where(and(eq(accounts.id, row.id), eq(accounts.userId, userId)));

        if (!existing) {
          const [inserted] = await stx
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
          return;
        }

        if (existing.version !== row.localBaseVersion) {
          conflicts.push(existing);
          return;
        }

        const [updated] = await stx
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
      });
    } catch (e) {
      rejected.push({ id: row.id, reason: describeRejection(e) });
    }
  }
  return { accepted, conflicts, rejected };
}

async function pushCategories(
  tx: Tx,
  userId: string,
  deviceId: string,
  rows: (typeof pushBody.static)["tables"]["categories"],
) {
  const accepted: (typeof categories.$inferSelect)[] = [];
  const conflicts: (typeof categories.$inferSelect)[] = [];
  const rejected: RejectedRow[] = [];
  for (const row of rows) {
    try {
      await tx.transaction(async (stx) => {
        // Only ever operates on this user's own categories — global seed
        // categories (userId IS NULL) are never pushed/edited by a client.
        const [existing] = await stx
          .select()
          .from(categories)
          .where(and(eq(categories.id, row.id), eq(categories.userId, userId)));

        if (!existing) {
          const [inserted] = await stx
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
          return;
        }

        if (existing.version !== row.localBaseVersion) {
          conflicts.push(existing);
          return;
        }

        const [updated] = await stx
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
      });
    } catch (e) {
      rejected.push({ id: row.id, reason: describeRejection(e) });
    }
  }
  return { accepted, conflicts, rejected };
}

async function pushTransactions(
  tx: Tx,
  userId: string,
  deviceId: string,
  rows: (typeof pushBody.static)["tables"]["transactions"],
) {
  const accepted: (typeof transactions.$inferSelect)[] = [];
  const conflicts: (typeof transactions.$inferSelect)[] = [];
  const rejected: RejectedRow[] = [];
  for (const row of rows) {
    try {
      await tx.transaction(async (stx) => {
        const [existing] = await stx
          .select()
          .from(transactions)
          .where(and(eq(transactions.id, row.id), eq(transactions.userId, userId)));

        if (!existing) {
          const [inserted] = await stx
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
          return;
        }

        if (existing.version !== row.localBaseVersion) {
          conflicts.push(existing);
          return;
        }

        const [updated] = await stx
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
      });
    } catch (e) {
      rejected.push({ id: row.id, reason: describeRejection(e) });
    }
  }
  return { accepted, conflicts, rejected };
}

async function pushBudgets(
  tx: Tx,
  userId: string,
  deviceId: string,
  rows: (typeof pushBody.static)["tables"]["budgets"],
) {
  const accepted: (typeof budgets.$inferSelect)[] = [];
  const conflicts: (typeof budgets.$inferSelect)[] = [];
  const rejected: RejectedRow[] = [];
  for (const row of rows) {
    try {
      await tx.transaction(async (stx) => {
        const [existing] = await stx
          .select()
          .from(budgets)
          .where(and(eq(budgets.id, row.id), eq(budgets.userId, userId)));

        if (!existing) {
          const [inserted] = await stx
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
          return;
        }

        if (existing.version !== row.localBaseVersion) {
          conflicts.push(existing);
          return;
        }

        const [updated] = await stx
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
      });
    } catch (e) {
      rejected.push({ id: row.id, reason: describeRejection(e) });
    }
  }
  return { accepted, conflicts, rejected };
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

        const rejectedCount =
          accountsResult.rejected.length +
          categoriesResult.rejected.length +
          transactionsResult.rejected.length +
          budgetsResult.rejected.length;

        if (rejectedCount > 0) {
          // A row-level failure (e.g. an orphaned foreign key from stale
          // local data) is isolated to its own SAVEPOINT by each push*
          // function above, so it never blocks the rest of this push — but
          // it's still worth surfacing in the logs since the client silently
          // drops it otherwise.
          console.warn(`sync push: ${rejectedCount} row(s) rejected for user ${userId}`, {
            accounts: accountsResult.rejected,
            categories: categoriesResult.rejected,
            transactions: transactionsResult.rejected,
            budgets: budgetsResult.rejected,
          });
        }

        await tx
          .update(devices)
          .set({
            lastSyncAt: new Date(),
            lastSyncStatus: hasConflicts || rejectedCount > 0 ? "error" : "ok",
            lastSyncError: hasConflicts
              ? "Conflicts pending resolution"
              : rejectedCount > 0
                ? `${rejectedCount} row(s) rejected`
                : null,
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
        rejected: {
          accounts: result.accounts.rejected,
          categories: result.categories.rejected,
          transactions: result.transactions.rejected,
          budgets: result.budgets.rejected,
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
      const cursorId = query.cursorId ?? NIL_UUID;

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
