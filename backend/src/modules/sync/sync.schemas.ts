import { t } from "elysia";

// Push rows carry the full row (unlike the CRUD modules' partial PATCH
// bodies) plus `localBaseVersion`: the server `version` this device last
// saw for the row, or `null` for a row it believes doesn't exist on the
// server yet. The server compares this against the current server version
// to decide insert / accept-update / conflict.
const baseFields = {
  id: t.String({ format: "uuid" }),
  localBaseVersion: t.Union([t.Number(), t.Null()]),
  deletedAt: t.Optional(t.Union([t.String({ format: "date-time" }), t.Null()])),
};

const accountRow = t.Object({
  ...baseFields,
  name: t.String(),
  type: t.String(),
  startingBalance: t.Number(),
  archivedAt: t.Optional(t.Union([t.String({ format: "date-time" }), t.Null()])),
});

const categoryRow = t.Object({
  ...baseFields,
  kind: t.String(),
  name: t.String(),
  icon: t.Optional(t.Union([t.String(), t.Null()])),
  color: t.Optional(t.Union([t.Number(), t.Null()])),
});

const transactionRow = t.Object({
  ...baseFields,
  type: t.String(),
  amount: t.Number(),
  occurredAt: t.String({ format: "date-time" }),
  accountId: t.String({ format: "uuid" }),
  transferToAccountId: t.Optional(t.Union([t.String({ format: "uuid" }), t.Null()])),
  categoryId: t.Optional(t.Union([t.String({ format: "uuid" }), t.Null()])),
  note: t.Optional(t.Union([t.String(), t.Null()])),
});

const budgetRow = t.Object({
  ...baseFields,
  categoryId: t.String({ format: "uuid" }),
  periodMonth: t.String({ format: "date-time" }),
  limitAmount: t.Number(),
});

export const pushBody = t.Object({
  deviceId: t.String({ format: "uuid" }),
  tables: t.Object({
    accounts: t.Array(accountRow),
    categories: t.Array(categoryRow),
    transactions: t.Array(transactionRow),
    budgets: t.Array(budgetRow),
  }),
});

export const pullQuery = t.Object({
  // Both default to "the beginning of time" so a fresh device can omit
  // them entirely for its first full pull.
  since: t.Optional(t.String({ format: "date-time" })),
  cursorId: t.Optional(t.String()),
});
