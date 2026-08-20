# Money Manager backend

Self-hosted sync backend: Bun + Elysia + PostgreSQL (via Drizzle ORM). Private, multi-user (family-scale, not SaaS) — see `../DESIGN.md`-equivalent notes below and the project plan for the full architecture rationale.

## Stack & layout

```
src/
  index.ts              # Elysia app, mounts every module, health check, error handling
  db/
    schema.ts            # Drizzle schema — source of truth for the Postgres data model
    client.ts             # db (Drizzle instance) + withUserScope() (RLS-scoped transactions)
    rls.sql                # Row-level security policies, applied after migrations
    migrations/            # drizzle-kit generated SQL migrations
  modules/
    auth/                 # login, refresh (device-scoped tokens)
    accounts/ categories/ transactions/ budgets/   # CRUD, one module per table
  middleware/
    auth-guard.ts          # requireUserId(headers) — every authenticated handler calls this first
  scripts/
    create-user.ts          # admin-only user provisioning CLI (never an HTTP endpoint)
    migrate.ts               # applies schema migrations, then rls.sql
```

## First-time setup (with Docker installed)

```sh
cp .env.example .env
# edit .env: set POSTGRES_PASSWORD and JWT_SECRET (openssl rand -base64 48)

docker compose up -d postgres
bun install
bun run migrate        # applies schema + RLS policies

docker compose up -d --build api      # or: bun run dev, if running the API outside Docker

bun run create-user --email you@example.com --name "Gio"
# prints a generated password once — save it, it's not stored in plaintext anywhere
```

Health check: `curl http://localhost:3000/health` → `{"status":"ok"}`.

## Verifying user isolation (Phase 2's "done" condition)

1. Provision two users:
   ```sh
   bun run create-user --email alice@example.com --name Alice
   bun run create-user --email bob@example.com --name Bob
   ```
2. Log in as each (note: `deviceId` is any client-generated UUID — the real app generates one per device on first launch):
   ```sh
   curl -s http://localhost:3000/auth/login -H 'Content-Type: application/json' \
     -d '{"email":"alice@example.com","password":"<alice password>","deviceId":"11111111-1111-1111-1111-111111111111"}'
   ```
3. Using each user's `accessToken`, create an account:
   ```sh
   curl -s http://localhost:3000/accounts -X POST \
     -H 'Authorization: Bearer <alice accessToken>' -H 'Content-Type: application/json' \
     -d '{"name":"Alice Cash","type":"cash"}'
   ```
4. Confirm isolation: `GET /accounts` with Bob's token must never return Alice's account, and vice versa. This is enforced twice — once by every handler's `WHERE user_id = ...`, and again by the Postgres RLS policies in `rls.sql` (so a bug in the app-layer filter still can't leak rows).

## Design notes (why things are built this way)

- **No self-registration.** Users are provisioned only via `create-user.ts`, run directly on the server host — there is no HTTP endpoint that creates a user, so there's no public attack surface for account creation. Matches the "private family server, not a SaaS" requirement.
- **Row-Level Security is defense-in-depth, not the only guard.** Every route handler already scopes its query by `user_id`; RLS policies (`rls.sql`) enforce the same boundary again at the database level via `withUserScope()`, which sets `app.current_user_id` for the duration of each transaction. If RLS's `current_setting()` finds that variable unset, the policy denies all rows — it fails closed.
- **Refresh tokens are opaque random strings, hashed with plain SHA-256** before storage (`modules/auth/tokens.ts`) — not a slow password KDF, since they're high-entropy generated values, not user-chosen secrets. Access tokens are short-lived (15 min) JWTs signed with `JWT_SECRET`, verified via the standalone `jose` library (not tied to Elysia's request/plugin lifecycle), so `requireUserId()` is a plain function any route module can call.
- **Devices are first-class rows**, keyed by a client-generated UUID (`deviceId`), so the same user's phone and tablet each get independent refresh tokens — losing one device just means revoking that one row (`devices.revokedAt`; no revocation endpoint yet, that's a Phase 5 item).
- **This `docker-compose.yml` is a dev/Phase-2 config** — Postgres and the API both publish ports directly to `localhost` for easy `curl`/`psql` access while building this out. Phase 4 replaces it with a production compose where only a Caddy service touches the host network (TLS via DNS-01 ACME) and everything else is internal-only.
- **Sync endpoints (`/sync/push`, `/sync/pull`) don't exist yet** — that's Phase 3. The CRUD modules here are plain REST, useful for testing/admin access now, but the Flutter app won't talk to this backend at all until the sync protocol is built on top.
