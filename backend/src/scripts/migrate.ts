import { readFileSync } from "node:fs";
import { migrate } from "drizzle-orm/postgres-js/migrator";

import { db, queryClient } from "../db/client";

async function main() {
  console.log("Applying schema migrations...");
  await migrate(db, { migrationsFolder: "./src/db/migrations" });

  console.log("Applying row-level security policies...");
  const rls = readFileSync(new URL("../db/rls.sql", import.meta.url), "utf-8");
  await queryClient.unsafe(rls);

  console.log("Done.");
  await queryClient.end();
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
