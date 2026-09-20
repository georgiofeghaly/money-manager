import { cors } from "@elysiajs/cors";
import { Elysia } from "elysia";

import { accountsRoutes } from "./modules/accounts/accounts.routes";
import { adminRoutes } from "./modules/admin/admin.routes";
import { authRoutes } from "./modules/auth/auth.routes";
import { budgetsRoutes } from "./modules/budgets/budgets.routes";
import { categoriesRoutes } from "./modules/categories/categories.routes";
import { devicesRoutes } from "./modules/devices/devices.routes";
import { syncRoutes } from "./modules/sync/sync.routes";
import { transactionsRoutes } from "./modules/transactions/transactions.routes";
import { ForbiddenError } from "./middleware/admin-guard";
import { UnauthorizedError } from "./middleware/auth-guard";

// The mobile app is a native Dio client — it never sends an Origin header,
// so CORS was never a concern until the web app. Scoped to one explicit
// origin (not "*"), since requests carry a bearer token in Authorization.
// WEB_ORIGIN unset -> CORS stays off (origin: false), matching "closed by
// default" rather than accidentally permissive in an environment that
// hasn't configured it yet.
const webOrigin = process.env.WEB_ORIGIN;

const app = new Elysia()
  .get("/health", () => ({ status: "ok" }))
  .use(
    cors({
      origin: webOrigin ? [webOrigin] : false,
      methods: ["GET", "POST", "PATCH", "DELETE", "OPTIONS"],
      allowedHeaders: ["Authorization", "Content-Type"],
    }),
  )
  .onError(({ error, set }) => {
    if (error instanceof UnauthorizedError) {
      set.status = 401;
      return { error: error.message };
    }
    if (error instanceof ForbiddenError) {
      set.status = 403;
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
  .use(budgetsRoutes)
  .use(devicesRoutes)
  .use(syncRoutes)
  .use(adminRoutes);

app.listen(process.env.PORT ?? 3000);

console.log(`Backend running at http://${app.server?.hostname}:${app.server?.port}`);
