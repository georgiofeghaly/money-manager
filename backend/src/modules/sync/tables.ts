import { accounts, budgets, categories, transactions } from "../../db/schema";

/** FK-safe write order: accounts/categories have no dependency on the
 * others, transactions depends on both, budgets depends on categories.
 * Every push-apply and pull-apply loop (server here, client in
 * app/lib/core/sync/sync_engine.dart) must process tables in this order. */
export const SYNC_TABLE_ORDER = ["accounts", "categories", "transactions", "budgets"] as const;

export type SyncTableName = (typeof SYNC_TABLE_ORDER)[number];

export const SYNC_TABLES = { accounts, categories, transactions, budgets } as const;
