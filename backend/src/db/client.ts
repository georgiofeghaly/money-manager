import { sql } from "drizzle-orm";
import { drizzle } from "drizzle-orm/postgres-js";
import postgres from "postgres";

import * as schema from "./schema";

const connectionString = process.env.DATABASE_URL;
if (!connectionString) {
  throw new Error("DATABASE_URL is not set");
}

// Exported (not just used internally) so scripts/migrate.ts can run raw,
// multi-statement SQL (e.g. the RLS policy file) via `.unsafe()` — Drizzle's
// own `db.execute()` sends a single prepared statement, which doesn't
// support a semicolon-separated batch of DDL statements.
export const queryClient = postgres(connectionString);
export const db = drizzle(queryClient, { schema });

/**
 * Runs [fn] inside a transaction with `app.current_user_id` set via
 * `SET LOCAL`, so every query inside it is subject to the RLS policies
 * defined in db/migrations/0001_rls.sql. Every authenticated request handler
 * should go through this instead of using `db` directly.
 */
type UserScopedTx = Parameters<Parameters<typeof db.transaction>[0]>[0];

export async function withUserScope<T>(
  userId: string,
  fn: (tx: UserScopedTx) => Promise<T>,
): Promise<T> {
  return db.transaction(async (tx) => {
    // set_config(..., true) behaves like SET LOCAL (scoped to this
    // transaction) but, unlike SET LOCAL, accepts a bound parameter instead
    // of string interpolation.
    await tx.execute(sql`SELECT set_config('app.current_user_id', ${userId}, true)`);
    return fn(tx);
  });
}
