import {
  boolean,
  doublePrecision,
  integer,
  pgTable,
  text,
  timestamp,
  uniqueIndex,
  uuid,
} from "drizzle-orm/pg-core";

export const users = pgTable("users", {
  id: uuid("id").primaryKey().defaultRandom(),
  email: text("email").notNull().unique(),
  passwordHash: text("password_hash").notNull(),
  displayName: text("display_name"),
  createdAt: timestamp("created_at", { withTimezone: true }).notNull().defaultNow(),
  isActive: boolean("is_active").notNull().default(true),
  // Grants access to the /admin/* routes (admin.routes.ts). Checked via a
  // DB lookup on every admin request, never trusted from the JWT, since
  // there's no token-invalidation path if admin status is later revoked.
  isAdmin: boolean("is_admin").notNull().default(false),
});

export const devices = pgTable("devices", {
  id: uuid("id").primaryKey().defaultRandom(),
  userId: uuid("user_id")
    .notNull()
    .references(() => users.id, { onDelete: "cascade" }),
  deviceName: text("device_name"),
  lastSeenAt: timestamp("last_seen_at", { withTimezone: true }),
  refreshTokenHash: text("refresh_token_hash").notNull(),
  createdAt: timestamp("created_at", { withTimezone: true }).notNull().defaultNow(),
  revokedAt: timestamp("revoked_at", { withTimezone: true }),
  // Updated by POST /sync/push on completion — surfaced in the admin panel
  // alongside lastSeenAt (last sign-in), so "last sync" is a distinct
  // signal from "last login".
  lastSyncAt: timestamp("last_sync_at", { withTimezone: true }),
  lastSyncStatus: text("last_sync_status"), // 'ok' | 'error'
  lastSyncError: text("last_sync_error"),
});

// Every syncable table below shares the same sync-metadata columns
// (updatedAt/version/originDeviceId/deletedAt) — see app/DESIGN.md-equivalent
// notes in backend/README.md for why: client-generated UUID ids, optimistic
// per-row versioning, soft deletes. Keep new tables consistent with this shape.

export const accounts = pgTable("accounts", {
  id: uuid("id").primaryKey(),
  userId: uuid("user_id")
    .notNull()
    .references(() => users.id, { onDelete: "cascade" }),
  name: text("name").notNull(),
  type: text("type").notNull(), // 'card' | 'cash' | 'savings' | 'custom'
  startingBalance: doublePrecision("starting_balance").notNull().default(0),
  archivedAt: timestamp("archived_at", { withTimezone: true }),
  updatedAt: timestamp("updated_at", { withTimezone: true }).notNull(),
  version: integer("version").notNull().default(1),
  originDeviceId: uuid("origin_device_id"),
  deletedAt: timestamp("deleted_at", { withTimezone: true }),
});

export const categories = pgTable("categories", {
  id: uuid("id").primaryKey(),
  // null = global seed category, shared by all users
  userId: uuid("user_id").references(() => users.id, { onDelete: "cascade" }),
  kind: text("kind").notNull(), // 'income' | 'expense'
  name: text("name").notNull(),
  icon: text("icon"),
  color: integer("color"), // ARGB int, mirrors the client's Categories.color
  isSeed: boolean("is_seed").notNull().default(false),
  updatedAt: timestamp("updated_at", { withTimezone: true }).notNull(),
  version: integer("version").notNull().default(1),
  originDeviceId: uuid("origin_device_id"),
  deletedAt: timestamp("deleted_at", { withTimezone: true }),
});

export const transactions = pgTable("transactions", {
  id: uuid("id").primaryKey(),
  userId: uuid("user_id")
    .notNull()
    .references(() => users.id, { onDelete: "cascade" }),
  type: text("type").notNull(), // 'income' | 'expense' | 'transfer'
  amount: doublePrecision("amount").notNull(),
  occurredAt: timestamp("occurred_at", { withTimezone: true }).notNull(),
  accountId: uuid("account_id")
    .notNull()
    .references(() => accounts.id),
  transferToAccountId: uuid("transfer_to_account_id").references(() => accounts.id),
  categoryId: uuid("category_id").references(() => categories.id),
  note: text("note"),
  updatedAt: timestamp("updated_at", { withTimezone: true }).notNull(),
  version: integer("version").notNull().default(1),
  originDeviceId: uuid("origin_device_id"),
  deletedAt: timestamp("deleted_at", { withTimezone: true }),
});

export const budgets = pgTable(
  "budgets",
  {
    id: uuid("id").primaryKey(),
    userId: uuid("user_id")
      .notNull()
      .references(() => users.id, { onDelete: "cascade" }),
    categoryId: uuid("category_id")
      .notNull()
      .references(() => categories.id),
    periodMonth: timestamp("period_month", { withTimezone: true }).notNull(),
    limitAmount: doublePrecision("limit_amount").notNull(),
    updatedAt: timestamp("updated_at", { withTimezone: true }).notNull(),
    version: integer("version").notNull().default(1),
    originDeviceId: uuid("origin_device_id"),
    deletedAt: timestamp("deleted_at", { withTimezone: true }),
  },
  (table) => [
    uniqueIndex("budgets_user_category_month_idx").on(
      table.userId,
      table.categoryId,
      table.periodMonth,
    ),
  ],
);
