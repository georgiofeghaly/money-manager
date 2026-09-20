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
    auth/                 # login, refresh, /auth/me (device-scoped tokens)
    accounts/ categories/ transactions/ budgets/   # CRUD, one module per table
    devices/               # GET /devices — caller's own devices (self-scoped)
    sync/                   # POST /sync/push, GET /sync/pull — see "Sync protocol" below
    admin/                  # /admin/* — metadata-only, gated by isAdmin (see "Admin routes" below)
  middleware/
    auth-guard.ts          # requireUserId(headers) — every authenticated handler calls this first
    admin-guard.ts          # requireAdmin(headers) — every /admin/* handler calls this first
  scripts/
    create-user.ts          # admin-only user provisioning CLI (--admin to grant admin), never an HTTP endpoint except via POST /admin/users
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

## Sync protocol

`POST /sync/push` — body `{deviceId, tables: {accounts, categories, transactions, budgets}}`, each row carrying `localBaseVersion` (the server `version` this device last saw, or `null` for a row it believes is new). Per row: no existing server row → insert (version 1, regardless of `localBaseVersion` — rows are never hard-deleted server-side, so "absent" only ever means genuinely new); existing row whose version matches `localBaseVersion` → update (version+1), accepted; existing row whose version differs → conflict, nothing written, the server's current row is returned so the client can render a diff. Updates the pushing device's `lastSyncAt`/`lastSyncStatus` on completion.

`GET /sync/pull?since=<iso>&cursorId=<uuid>` — all rows (including tombstones, i.e. `deletedAt IS NOT NULL` rows are not filtered out) with `updatedAt > since`, paginated at 500 rows/table, ordered `updatedAt asc, id asc`. Uses a **composite `(updatedAt, id)` cursor**, not a bare `updatedAt > since` filter — a bare filter would silently drop or duplicate rows at a page boundary whenever multiple rows share an exact timestamp (e.g. a bulk CSV import). Returns `nextCursor: {since, cursorId} | null`; keep pulling while non-null.

Pull-side conflicts (an incoming row would clobber a row the client has pending-but-unpushed) are detected client-side by comparing the pulled row's version against the client's own outbox base version — no server logic needed for that half.

## Admin routes

`GET /admin/users`, `GET /admin/users/:id/devices`, `POST /admin/users` — all gated by `requireAdmin` (`middleware/admin-guard.ts`), which does a DB lookup for `isAdmin` on every request rather than trusting a JWT claim. **Metadata only** — these routes return sign-in/sync status, never financial data, and the module must never import `accounts/categories/transactions/budgets`. There's no RLS backstop for this boundary the way there is for the CRUD routes (`users`/`devices` aren't RLS tables), so it's enforced by code review, not the database — keep it that way. `POST /admin/users` is the only HTTP path that creates a user (still never public); it mirrors `create-user.ts`'s provisioning logic and returns the generated password once, same "shown once, never stored again" convention.

## Deploying the web app

The web app (`app/lib/main_web.dart` — read-only account viewer at `/`, admin panel at `/admin`, both behind `/login`; see `app/DESIGN.md`'s "Companion web app" section for how it's built) is implemented. `docker-compose.yml`'s `web` service builds `../app` via `app/Dockerfile.web` (Flutter web build → nginx with SPA fallback, `app/web/nginx.conf`) and joins `npm-network` alongside `api`. Give it its **own NPM proxy host on a separate subdomain** from the API (e.g. `app.<domain>` vs. `api.<domain>`) rather than path-based routing on one host — a subdomain split needs zero changes to the already-shipped mobile app's API calls. Set `WEB_ORIGIN` in `.env` to that subdomain's URL so the `api` service's CORS allows it (see `.env.example`); leave it unset in setups that don't deploy `web`, CORS then stays off.

## Design notes (why things are built this way)

- **No self-registration.** Users are provisioned via `create-user.ts` (run directly on the server host) or `POST /admin/users` (gated by `requireAdmin`, used by the web admin panel's "New user" form) — there is no *public* endpoint that creates a user, so there's no public attack surface for account creation. Matches the "private family server, not a SaaS" requirement.
- **Row-Level Security is defense-in-depth, not the only guard.** Every route handler already scopes its query by `user_id`; RLS policies (`rls.sql`) enforce the same boundary again at the database level via `withUserScope()`, which sets `app.current_user_id` for the duration of each transaction. If RLS's `current_setting()` finds that variable unset, the policy denies all rows — it fails closed.
- **Refresh tokens are opaque random strings, hashed with plain SHA-256** before storage (`modules/auth/tokens.ts`) — not a slow password KDF, since they're high-entropy generated values, not user-chosen secrets. Access tokens are short-lived (15 min) JWTs signed with `JWT_SECRET`, verified via the standalone `jose` library (not tied to Elysia's request/plugin lifecycle), so `requireUserId()` is a plain function any route module can call.
- **Devices are first-class rows**, keyed by a client-generated UUID (`deviceId`), so the same user's phone and tablet each get independent refresh tokens — losing one device just means revoking that one row (`devices.revokedAt`; no revocation endpoint yet, that's a Phase 5 item).
- **This `docker-compose.yml` is a dev/Phase-2 config** — Postgres and the API both publish ports directly to `localhost` for easy `curl`/`psql` access while building this out. Phase 4 replaces it with a production compose where only a Caddy service touches the host network (TLS via DNS-01 ACME) and everything else is internal-only.
- **Sync endpoints (`/sync/push`, `/sync/pull`) are implemented** — see "Sync protocol" above. The CRUD modules remain plain REST (useful for `curl`/admin/one-off access), but the Flutter app's real path to the server is push/pull plus the client-side outbox/pull engine in `app/lib/core/sync/`.
