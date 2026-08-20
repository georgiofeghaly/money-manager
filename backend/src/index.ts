import { Elysia } from "elysia";

import { accountsRoutes } from "./modules/accounts/accounts.routes";
import { authRoutes } from "./modules/auth/auth.routes";
import { budgetsRoutes } from "./modules/budgets/budgets.routes";
import { categoriesRoutes } from "./modules/categories/categories.routes";
import { transactionsRoutes } from "./modules/transactions/transactions.routes";
import { UnauthorizedError } from "./middleware/auth-guard";

const app = new Elysia()
  .get("/health", () => ({ status: "ok" }))
  .onError(({ error, set }) => {
    if (error instanceof UnauthorizedError) {
      set.status = 401;
      return { error: error.message };
    }
    console.error(error);
    set.status = 500;
    return { error: "Internal error" };
  })
  .use(authRoutes)
  .use(accountsRoutes)
  .use(categoriesRoutes)
  .use(transactionsRoutes)
  .use(budgetsRoutes);

app.listen(process.env.PORT ?? 3000);

console.log(`Backend running at http://${app.server?.hostname}:${app.server?.port}`);
