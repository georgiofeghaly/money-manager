/**
 * Admin-only user provisioning. Run on the server host, never exposed as an
 * HTTP endpoint — there is deliberately no self-registration/invite-code
 * flow (see app/DESIGN.md-equivalent notes in backend/README.md).
 *
 * Usage:
 *   bun run src/scripts/create-user.ts --email you@example.com --name "Gio" [--password "..."] [--admin]
 *
 * If --password is omitted, a random one is generated and printed once —
 * it is never stored in plaintext or logged anywhere else.
 */
import { randomBytes } from "node:crypto";

import { db, queryClient } from "../db/client";
import { users } from "../db/schema";

function parseArgs(argv: string[]): Record<string, string | undefined> {
  const args: Record<string, string | undefined> = {};
  for (let i = 0; i < argv.length; i++) {
    const token = argv[i];
    if (token?.startsWith("--")) {
      const key = token.slice(2);
      const next = argv[i + 1];
      // A flag followed by another --flag (or nothing) is a boolean switch
      // (e.g. --admin), not a --key value pair — don't consume `next` as
      // its value in that case.
      if (next === undefined || next.startsWith("--")) {
        args[key] = "true";
      } else {
        args[key] = next;
        i++;
      }
    }
  }
  return args;
}

async function main() {
  const args = parseArgs(process.argv.slice(2));
  const email = args.email;
  if (!email) {
    console.error(
      "Usage: --email <email> [--name <display name>] [--password <password>] [--admin]",
    );
    process.exit(1);
  }

  const password = args.password ?? randomBytes(12).toString("base64url");
  const passwordHash = await Bun.password.hash(password); // argon2id by default

  const [user] = await db
    .insert(users)
    .values({
      email,
      passwordHash,
      displayName: args.name,
      isAdmin: args.admin === "true",
    })
    .returning({ id: users.id, email: users.email });

  if (!user) throw new Error("Insert returned no row");

  console.log(`Created user ${user.email} (${user.id})`);
  if (!args.password) {
    console.log(`Generated password: ${password}`);
    console.log("Share this with the user securely — it will not be shown again.");
  }

  await queryClient.end();
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
