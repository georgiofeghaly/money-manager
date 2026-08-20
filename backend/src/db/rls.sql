-- Row-Level Security: defense-in-depth per-user isolation, on top of the
-- app-layer `WHERE user_id = ...` scoping every query already does.
-- Applied via scripts/migrate.ts after the Drizzle-generated schema
-- migrations, and safe to re-run (DROP POLICY IF EXISTS before each CREATE).
--
-- Requires every request handler to run inside withUserScope() (db/client.ts),
-- which sets app.current_user_id via SET LOCAL / set_config for the duration
-- of the transaction. Without that set, current_setting(...) below raises,
-- and the policy denies all rows — fails closed, not open.

ALTER TABLE accounts ENABLE ROW LEVEL SECURITY;
ALTER TABLE categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE budgets ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS accounts_isolation ON accounts;
CREATE POLICY accounts_isolation ON accounts
  USING (user_id = current_setting('app.current_user_id', true)::uuid)
  WITH CHECK (user_id = current_setting('app.current_user_id', true)::uuid);

-- Categories are special: user_id IS NULL for global seed categories, which
-- every user should be able to read (but never write/delete).
DROP POLICY IF EXISTS categories_select ON categories;
CREATE POLICY categories_select ON categories
  FOR SELECT
  USING (
    user_id IS NULL
    OR user_id = current_setting('app.current_user_id', true)::uuid
  );

DROP POLICY IF EXISTS categories_write ON categories;
CREATE POLICY categories_write ON categories
  FOR INSERT
  WITH CHECK (user_id = current_setting('app.current_user_id', true)::uuid);

DROP POLICY IF EXISTS categories_update ON categories;
CREATE POLICY categories_update ON categories
  FOR UPDATE
  USING (user_id = current_setting('app.current_user_id', true)::uuid)
  WITH CHECK (user_id = current_setting('app.current_user_id', true)::uuid);

DROP POLICY IF EXISTS categories_delete ON categories;
CREATE POLICY categories_delete ON categories
  FOR DELETE
  USING (user_id = current_setting('app.current_user_id', true)::uuid);

DROP POLICY IF EXISTS transactions_isolation ON transactions;
CREATE POLICY transactions_isolation ON transactions
  USING (user_id = current_setting('app.current_user_id', true)::uuid)
  WITH CHECK (user_id = current_setting('app.current_user_id', true)::uuid);

DROP POLICY IF EXISTS budgets_isolation ON budgets;
CREATE POLICY budgets_isolation ON budgets
  USING (user_id = current_setting('app.current_user_id', true)::uuid)
  WITH CHECK (user_id = current_setting('app.current_user_id', true)::uuid);
