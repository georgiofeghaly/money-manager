# Money Manager — PRD & Build Plan

This is the project's living plan: requirements, architecture decisions, the phased roadmap, and current status. Update it as work progresses — it should always reflect where the project actually is, not just where it started. Detailed, code-level conventions live in [app/DESIGN.md](app/DESIGN.md) (Flutter) and [backend/README.md](backend/README.md) (backend); this file is the higher-level "why" and "what's left."

## Status (updated 2026-08-23)

- **Phase 0–1 (+ 1b): done.** The full offline Flutter app runs on-device — accounts, categories, transactions, calendar, budgets, charts, PIN + biometric lock, dark mode, Settings, and a `DESIGN.md` design system.
- **Phase 2 (backend code): written, not yet run.** `backend/` has the full Drizzle schema, RLS policies, Elysia auth (login/refresh, device-scoped tokens) + CRUD modules for accounts/categories/transactions/budgets, the `create-user.ts` admin script, `migrate.ts`, `Dockerfile`, `docker-compose.yml`, and `backend/README.md` with setup/verification steps. Typechecks clean (`bunx tsc --noEmit`). **Not yet actually run against Postgres** — Docker wasn't installed in the dev environment this was written in; run against Docker on your own machine and follow `backend/README.md`'s "Verifying user isolation" section.
- **Phase 3 (sync + conflict resolution): done.** Backend gained a `sync` module (`POST /sync/push`, `GET /sync/pull` — cursor-based, per-row versioning, FK-safe table ordering), `GET /auth/me`, `GET /devices`, and `devices.lastSyncAt`/`lastSyncStatus` tracking (see `backend/README.md`'s "Sync protocol" section). The Flutter app's `core/sync/` now has the full client engine: `outbox.dart` + `sync_engine.dart` (push-then-pull, one pass), `sync_controller.dart` (progress state for the UI), `sync_triggers.dart` (`workmanager` periodic + `connectivity_plus` reconnect trigger; resume-sync hooked into `LockGate`'s existing lifecycle observer). Every repository write now marks its row `syncStatus: 'pending'`. Sync progress is surfaced in Settings (live row, replacing the old "Coming soon" placeholder) and as a thin progress strip in `AppShell`. Manual conflict resolution (`features/sync_conflicts/`: conflict list, side-by-side diff, Keep mine / Keep other / Edit manually) is built and wired to a non-blocking `AppShell` banner. `flutter analyze`/`flutter test` clean; **not yet run against a live two-device setup** (needs Docker + a real server to validate end-to-end, see Verification approach below).
- **Backend admin capability (new, beyond the original Phase 3 scope): done.** `users.isAdmin` flag, `admin-guard.ts` (DB-checked, not JWT-trusted), and an `/admin` module: `GET /admin/users`, `GET /admin/users/:id/devices` (metadata only — sign-in/sync status, never financial data), `POST /admin/users` (admin-gated user creation, mirrors `create-user.ts`). `create-user.ts` gained a `--admin` flag.
- **Companion web app (viewer + `/admin`): done.** `app/lib/main_web.dart` is a second Flutter entrypoint (mobile's `main.dart` untouched) reusing the same theme, widgets, and per-feature screens as the mobile app. Getting there required one unplanned but necessary fix: `core/db/database.dart` unconditionally imported `dart:io`/`package:drift/native.dart`, which fails to compile for web (`dart:ffi`'s `external` functions aren't supported by dart2js) — fixed by moving the native `NativeDatabase` connection behind a conditional import (`core/db/connection/native.dart` vs `connection/unsupported.dart`), so the Drift-generated row types stay reusable on web without dragging in ffi. Every feature repository was split into a `*Reader` interface (used by both platforms) and a `*Writer` interface (mobile-only, backed by a separate `*WriterProvider` — the web app has no code path that can even call a mutation). On web, `kIsWeb` swaps each `*RepositoryProvider` to an `Api*Repository` (`app/lib/web/data/`) backed by a new `WebDataStore`, which hydrates a full read-only snapshot by paging the *existing* `/sync/pull` endpoint from the epoch — no new "list my data" REST API was needed. Existing screens (`AccountsScreen`, `CalendarScreen`/`TransactionTile`, `BudgetsScreen`, `TransactionSearchScreen`) gained an additive `readOnly` flag that hides FABs, swipe-to-archive, and tap-to-edit; `ChartsScreen` needed no changes, since it was already read-only. Routing is `go_router` (web-only dependency): `/login` (reuses `AuthController`/`ApiClient` as-is — `flutter_secure_storage` needs no web-specific code), `/` → `ViewerShell` (same 4 data tabs, minus Settings), `/admin` → `AdminGate`, which shows the same login form when signed out and then a server-verified `GET /auth/me` `isAdmin` check (never trusted from a token claim) before rendering `AdminShell` (user list → device list with last-sign-in/last-sync) or a plain "access denied". `POST /admin/users` is wired to a create-user form with a one-time generated-password dialog. `flutter build web -t lib/main_web.dart` succeeds; mobile's `flutter analyze`/`flutter test` (58/58) stayed clean throughout the refactor.
- **Phase 4–5 (deployment, multi-user validation): not started.** Everything above is verified via static analysis and local builds only — this dev environment has no Docker, so nothing has been run against a live Postgres/backend yet. See app/DESIGN.md's "Manual verification still needed" note for the exact checklist to run once Docker is available.

## Context

You want to stop using commercial "money manager" apps (ads, possible data harvesting) and replace them with your own private, offline-first Flutter app, with an optional self-hosted sync backend (Bun + Postgres, Dockerized at home) so the same private data can sync across your own devices and, isolated per-person, your family's.

## Confirmed requirements

- **Client**: Flutter, **Android only** for v1.
- **Offline-first**: fully usable app with zero network — local SQLite storage, sync is opportunistic on top.
- **Domain**: Accounts (manual, starter presets Card/Cash/Savings, user can add more), Transactions (Income / Expense / Transfer between own accounts), Categories (seeded presets per income/expense, user-extensible), Calendar view organized Year → Month/Week/Day, rendered as a scrollable **list** (not a grid).
- **Currency**: single global currency, no multi-currency/conversion.
- **v1 scope**: core tracking **plus** monthly category budgets and simple spending charts. No receipt photo attachments in v1.
- **Security**: biometric (fingerprint) unlock, falling back to a 6-digit PIN; proper secure local storage, lock-on-background.
- **Backend**: self-hosted only — Bun.js + PostgreSQL, Dockerized, reachable from outside only via your own DNS+TLS record and/or personal VPN. Not a public SaaS.
- **Multi-user**: each family member's data is **fully isolated** (no shared/visible data across users); users are **manually provisioned by you** (no public self-registration, no invite codes).
- **Sync**: automatic background sync across a user's own multiple devices (e.g. your phone + tablet). Because sync is automatic and offline edits can collide, conflicts are handled via a **manual resolution UI** (show both versions, let the user choose) — not silent last-write-wins.
- **No cloud, no analytics, no third parties.**

## Architecture decisions

### Data model & local storage
- **Client DB: Drift** (over sqflite/Isar) — type-safe, SQL-shaped (matches Postgres, good for the category/month aggregate queries budgets & charts need), reactive `.watch()` streams map cleanly to the calendar/budget/chart UI, and has a real migration story across build phases.
- Every syncable table (`accounts`, `categories`, `transactions`, `budgets`) carries: client-generated **UUID** id (so offline-created rows never collide), `user_id`, `updated_at`, an incrementing `version` (optimistic concurrency), `origin_device_id`, `deleted_at` (soft-delete/tombstone — deletes must sync too), plus client-only `sync_status` (`synced`/`pending`/`conflict`).
- Postgres schema mirrors this 1:1 (`users`, `devices`, `accounts`, `categories`, `transactions`, `budgets`) — see `backend/src/db/schema.ts` for the exact Drizzle definitions.
- Account balances are **derived** (summed from transactions), never a stored running counter, to avoid drift bugs.

```
users(id, email, password_hash[argon2id], display_name, created_at, is_active)
devices(id, user_id, device_name, last_seen_at, refresh_token_hash, revoked_at)
accounts(id, user_id, name, type, starting_balance, archived_at, updated_at, version, origin_device_id, deleted_at)
categories(id, user_id[null=global seed], kind[income|expense], name, icon, color, is_seed, updated_at, version, origin_device_id, deleted_at)
transactions(id, user_id, type[income|expense|transfer], amount, occurred_at, account_id,
             transfer_to_account_id[null unless transfer], category_id[null only for transfer],
             note, updated_at, version, origin_device_id, deleted_at)
budgets(id, user_id, category_id, period_month, limit_amount, updated_at, version, origin_device_id, deleted_at,
        UNIQUE(user_id, category_id, period_month))
```

### Sync protocol (Phase 3 — not built yet)
- **Cursor-based delta push/pull**, not vector clocks/CRDTs — appropriate because there's one authoritative server (Postgres), low edit concurrency (2-3 devices/user), and the product explicitly wants manual "pick a version" resolution rather than automatic merge.
- Push: client sends dirty rows with `local_base_version`; server accepts if it matches current server version (writes, bumps version), else returns `conflict` with the server's current row attached.
- Pull: `GET /sync/pull?since=<cursor>` returns all rows (incl. tombstones) with `updated_at > cursor` for that user, paginated.
- Conflicts are detected symmetrically (push-rejected OR pull-would-clobber-a-dirty-row) via the same version-comparison check.
- **Background sync on Android**: `workmanager` periodic task (~15 min, OS-throttled — this is an Android constraint, not solvable in-app), plus sync-on-app-resume and sync-on-connectivity-regained (`connectivity_plus`) for responsiveness. Since the backend is only reachable via home Wi-Fi/VPN, "always-on VPN" is the practical way to get background sync away from home.
- **Manual conflict resolution UI**: non-blocking app-wide banner → dedicated screen listing each conflict as a side-by-side diff ("Your version, edited on [device]" vs "Other version, edited on [device]"), with actions **Keep mine** / **Keep other** / **Edit manually**. All three resolve by producing a normal push with a corrected `local_base_version`, so no bespoke server endpoint is needed beyond push/pull.

### Auth & security
- No self-registration. Users are provisioned via an **admin CLI script** (`backend/src/scripts/create-user.ts`), hashing passwords with **argon2id** via Bun's built-in `Bun.password`.
- Login issues a short-lived JWT access token + a longer-lived opaque refresh token, scoped **per device** (a `devices` row per `(user_id, device_id)`) — enables revoking a single lost device without logging out others.
- App lock: `local_auth` for biometric, `flutter_secure_storage` for the PIN's salted hash (10k-iteration salted SHA-256 via `package:crypto` — see `app/DESIGN.md`'s "App lock" section for why this isn't a real KDF). PIN setup is mandatory on first run; biometric is additive. Lock overlay shown immediately on backgrounding, re-auth required on resume (5s grace period); `FLAG_SECURE` blocks screenshots/recent-apps preview.
- **Backend exposure** (Phase 4, not built yet): reverse proxy with **Caddy** (DNS-01 ACME), Default posture: **VPN-only access** (WireGuard) for real use, DNS+TLS as a fallback path. Postgres and the Bun API stay on an internal Docker network with no published ports — only Caddy touches the host.
- **Per-user isolation**: single shared Postgres schema, every table scoped by `user_id`, enforced at the app layer **and** via Postgres Row-Level Security as defense-in-depth (not separate per-user schemas/DBs — unnecessary operational overhead at family scale). Implemented in `backend/src/db/rls.sql`.

### Backend stack
- **Elysia** on Bun, **Drizzle ORM** for schema + migrations, **jose** for JWT signing/verification (standalone, not tied to Elysia's plugin lifecycle — see `backend/README.md`).
- Module layout: `src/{index.ts, db/{schema.ts,client.ts,rls.sql,migrations/}, modules/{auth,accounts,categories,transactions,budgets}, middleware/auth-guard.ts, scripts/{create-user.ts,migrate.ts}}`.
- Docker Compose (dev): `postgres` + `api`, both port-published to localhost for easy testing. Production (Phase 4) swaps this for an internal-only network with `caddy` as the sole host-facing service.

### Budgets & charts
- Budgets: flat `(user_id, category_id, period_month, limit_amount)`, one per category per month, progress bar (spent/limit) — no rollover, no notifications, "copy last month" button for setup.
- Charts: `fl_chart` — pie/donut (spending by category, current month) and bar chart (spending by month, trailing 6 months), computed from local Drift aggregate queries, fully offline.

## Phased roadmap

1. **Phase 0 — Scaffolding.** ✅ Done.
2. **Phase 1 — Offline-only Flutter app.** ✅ Done. Drift schema/migrations, accounts/categories/transactions CRUD, Year→Month/Week/Day calendar list, budgets screen, charts screen, PIN+biometric lock with lock-on-background. Fully usable in airplane mode, no backend involved.
3. **Phase 1b — Editable data, Settings, dark mode, design system.** ✅ Done (folded into Phase 1 above; see `app/DESIGN.md`).
4. **Phase 2 — Backend, auth, provisioning.** ✅ Code done, ⏳ not yet run (needs Docker). Postgres schema via Drizzle, Elysia CRUD modules, RLS policies, `create-user.ts` admin script, local Docker Compose.
5. **Phase 3 — Sync + conflict resolution.** ⏳ Not started. `/sync/push` + `/sync/pull` endpoints, client `core/sync` module (outbox drain, cursor pull, `workmanager` + `connectivity_plus` + resume triggers), conflict data model + resolution screen, device registration.
6. **Phase 4 — Production deployment.** ⏳ Not started. Caddy + `Caddyfile` (DNS-01 ACME), production Compose (only 443 published), WireGuard VPN path, DDNS if needed.
7. **Phase 5 — Polish & multi-user validation.** ⏳ Not started. Provision a second family member's account, confirm isolation; multi-device test per user; device management/revocation screen; token-refresh-on-expiry-mid-sync; battery-optimization-exemption prompt for reliable `workmanager` on aggressive OEM skins. "Done" = daily real use across 2 devices for 1-2 weeks with no data loss.

## Verification approach per phase

- **Phase 1**: manual QA in airplane mode — accounts, all 3 transaction types, all calendar granularities, budget progress bars, lock-on-background + screenshot blocking.
- **Phase 2**: `curl`/REST client against the Dockerized backend with two provisioned users, confirm cross-user queries return nothing (see `backend/README.md`).
- **Phase 3**: two emulators (or one emulator + one physical device) logged in as the same user, offline edits on both, then reconnect — confirm conflict detection and each of the 3 resolution paths.
- **Phase 4**: real device off home Wi-Fi (mobile data, VPN toggled on/off) hitting the real domain, confirm TLS handshake and graceful offline fallback.
- **Phase 5**: real-world dogfooding — daily use for 1-2 weeks across 2 devices plus a second family member's account.

## Where things live

- [app/DESIGN.md](app/DESIGN.md) — Flutter design system, code conventions, gotchas (icon tree-shaking, DateTime/strftime storage caveat, etc.)
- [backend/README.md](backend/README.md) — backend setup, verification steps, and the reasoning behind each architecture choice
- `backend/src/db/schema.ts` — Postgres schema, source of truth for the server-side data model
- `app/lib/core/db/database.dart` — Drift schema, must stay field-compatible with the server schema
