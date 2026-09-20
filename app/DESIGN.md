# Design system & conventions

Reference for keeping future screens (budgets, charts, lock screen, sync UI) consistent with what's already built. Update this file when a new pattern gets established — don't let it drift from the code.

## Theme

- Defined once in `lib/core/theme/app_theme.dart`: `buildLightTheme()` / `buildDarkTheme()`, both `ColorScheme.fromSeed(seedColor: Colors.teal)`. Wired in `main.dart` via `theme:`/`darkTheme:`/`themeMode: ThemeMode.system` — the app follows the phone's OS theme, no in-app toggle.
- Never hardcode a `Color` in a screen. If it's a semantic color (income/expense/transfer), use `TransactionColors` from `app_theme.dart`. If it's a category color, it comes from the category's own `color` column via `colorFromArgb()` in `core/theme/category_style.dart`.

## Semantic colors

| Meaning | Source |
|---|---|
| Income | `TransactionColors.income` (fixed green — reads as "positive" in both light/dark) |
| Expense | `TransactionColors.expense(context)` → `colorScheme.error` |
| Transfer | `TransactionColors.transfer(context)` → `colorScheme.tertiary` |
| Category | per-category `color` (ARGB int column), via `colorFromArgb(argb, fallbackSeedId)` |

## Category icons & colors

- Categories store an **icon key** (plain string, e.g. `'car'`), never a raw icon codepoint. The key maps to a real `IconData` via `kCategoryIcons` in `core/theme/category_style.dart`. **Never construct `IconData` dynamically from a stored codepoint** — Flutter's icon tree-shaking in release builds strips unused icon glyphs and can't tell a dynamically-built `IconData` is "used," so it silently renders as a missing-glyph box.
- Colors are a fixed 12-swatch palette (`kCategoryColorPalette`), stored as the actual ARGB int on the row once picked. `defaultColorForId(id)` gives a deterministic fallback (hash of id → palette index) for categories with no color set yet, so nothing ever renders with a missing/null color.
- Picker UI is a `Wrap` of `CircleAvatar`s for both icon and color (see `category_form_sheet.dart`) — no third-party color-picker package, keeps the dependency surface small.

## Data layer conventions

Every feature follows the same three-layer shape:

```
lib/features/<feature>/
  data/<feature>_repository.dart      # wraps AppDatabase, exposes Stream<T> watch*() + Future<void> create/update/delete
  application/<feature>_providers.dart # Riverpod Provider<Repository> + StreamProvider(.family) wrapping watch*()
  presentation/*.dart                  # ConsumerWidget/ConsumerStatefulWidget screens & sheets
```

- **Repositories never expose Drift's generated `Companion` types past their own file** — callers pass plain named params (`name:`, `type:`, ...), the repository builds the `Companion` internally. Keeps Drift as an implementation detail.
- **Soft delete, always.** Every syncable table has `deletedAt`; accounts additionally have `archivedAt` (used instead of delete, since transactions reference accounts and must never lose that reference). Nothing is ever hard-deleted from the UI.
- **Lookup vs. picker streams.** Dropdowns for *creating* new data (`accountsProvider`, `categoriesByKindProvider`) only show active/non-deleted rows. Anything that needs to *display* an existing reference (calendar tiles, the transaction edit form) uses the `...ForLookup` variant, which includes archived/deleted rows — otherwise editing an old transaction whose account was since archived would crash `DropdownButtonFormField` (its `initialValue` wouldn't match any item). If you add a new picker, ask which case it is before wiring the provider.
- **Balances are always derived**, never stored (`AccountRepository.watchBalance` sums transactions live). Don't add a cached `balance` column.

## Component patterns

- **Create vs. edit**: one form widget handles both, taking an optional `existing` row (`AddAccountSheet(existing: account)`, `CategoryFormSheet(existing: category)`, `AddTransactionScreen(existing: transaction)`). The widget switches its title/submit label/delete-or-archive button off `existing != null` — don't create a separate `Edit*Screen` copy of a form.
- **Quick-create/edit forms** (accounts, categories) are `showModalBottomSheet` sheets. **Multi-field or navigation-heavy forms** (transactions) are full `MaterialPageRoute` screens. Pick based on field count / whether the user needs to see other app chrome while filling it in.
- **Destructive actions** always go through `confirmDialog()` (`core/widgets/confirm_dialog.dart`) — never a bare `showDialog` copy. Archive actions also use it (framed as "will be hidden," not "will be deleted," since it's reversible in the DB even though there's no un-archive UI yet).
- **Swipe-to-archive/delete** via `Dismissible` (see `accounts_screen.dart`) for list rows where a quick gesture makes sense; `confirmDismiss` still routes through `confirmDialog()` so a swipe is never silently destructive.
- **Lists grouped by a header** (calendar's day headers, manage-categories' income/expense headers) use `textTheme.labelLarge` colored `colorScheme.primary` — that's the fixed "section header" style, don't invent a new one per screen.

## Spacing

- `16` — screen-edge padding, standard gap between unrelated form sections.
- `12` — gap between related form fields (e.g., stacked `TextFormField`s).
- `8` — gap between tightly related elements (a label and the control under it).
- `24` — gap before a primary submit button, to visually separate it from the form above.

## Navigation shell

- 5-tab bottom `NavigationBar` (`core/app_shell.dart`): Calendar, Budgets, Charts, Accounts, Settings. The FAB is contextual per tab (add transaction / add account / hidden elsewhere) via `_AppShellState._showFab` + a switch in `_onFabPressed` — keep it that way; don't add a global "add" flow that doesn't know which tab it's on.
- Settings (`features/settings/presentation/settings_screen.dart`) is also where not-yet-built roadmap items get a disabled placeholder row as they're planned but not implemented — remove the placeholder the same PR that implements the real feature (the sync row was the example of this: it's now a live row bound to `syncControllerProvider`, not a placeholder). Implemented security-relevant settings (e.g. the PIN/biometric lock) get a normal, non-disabled row describing their current state instead.

## Screen headers with built-in navigation

Calendar and Budgets both replace the `AppBar`'s plain title with a `Row` (prev/next chevrons + a period label, `titleSpacing: 0`, centered) instead of a separate row below the AppBar — a static "Calendar" title plus a nav row underneath wastes a full row of vertical space for no informational gain. Use `IconButton(constraints: BoxConstraints(minWidth: 36, minHeight: 36), padding: EdgeInsets.zero, ...)` for the chevrons — Flutter's default `IconButton` reserves a 48×48 tap target that reads as "dead space" when several sit inline in a title row. Apply this pattern to any future screen whose primary state is "which period am I looking at" rather than introducing a separate nav row.

## Aggregate queries (budgets, charts)

- Single-table `GROUP BY` with a typed aggregate (e.g. category totals for the pie chart) uses Drift's `selectOnly` + `.sum()` + `groupBy` builder (`ChartRepository.watchCategoryBreakdown`) — stays type-safe, no raw SQL needed.
- Multi-bucket time-series queries (spend-per-month across N months) use `customSelect` with `strftime()` instead (`ChartRepository.watchMonthlyTotals`), because Drift's typed builder can't express "group by truncated month" cleanly.
- **Caveat when writing raw SQL against `DateTime` columns**: Drift stores `DateTime` as a Unix-epoch integer (seconds) by default in this project (no `storeDateTimeAsText` override), so any raw `strftime()`/date-function call needs the `'unixepoch'` modifier — `strftime('%Y-%m', occurred_at, 'unixepoch')`, not `strftime('%Y-%m', occurred_at)`. Forgetting the modifier doesn't error, it just silently returns wrong/empty groupings.
- Budgets use a manual "select existing row, then insert-or-update" (`BudgetRepository.upsertBudget`) rather than Drift's `insertOnConflictUpdate`, because the natural conflict target is the `(category_id, period_month)` unique key, not the primary key (`id` is a fresh UUID on every insert) — `insertOnConflictUpdate` conflicts on the primary key by default.

## App lock

- `features/lock/` follows the same data/application/presentation layering as everything else, but application-layer state is a plain `ChangeNotifier` (`LockController`, exposed via `ChangeNotifierProvider`) rather than a repository-backed `StreamProvider` — there's no DB-backed stream to watch, just in-memory phase state (`LockPhase`: checking → needsSetup/locked → unlocked).
- `PinStorage` (`features/lock/data/pin_storage.dart`) hashes the PIN with salted, 10k-iteration SHA-256 via `package:crypto` — not a real KDF (PBKDF2/argon2id), a deliberate tradeoff to avoid adding a heavier crypto dependency for a locally-verified PIN. Revisit if this ever needs to double as an encryption key, not just a gate.
- `LockGate` (`features/lock/presentation/lock_gate.dart`) wraps `AppShell` in `main.dart` and is the *only* place that observes `WidgetsBindingObserver`/`AppLifecycleState` for the whole app — don't add a second lifecycle observer elsewhere for a different feature; route through `LockController` if something else needs to react to backgrounding.
- Screenshot/recent-apps redaction is `FLAG_SECURE`, set directly in `android/.../MainActivity.kt`'s `onCreate` — not a Flutter plugin, since it's 4 lines of native code and avoids another native dependency.

## Schema migrations

- `AppDatabase.schemaVersion` bumps on any column/table change; write the `onUpgrade` step to backfill sane defaults for existing rows (see the `color` column migration in `core/db/database.dart`) rather than leaving them `null` and special-casing null everywhere in the UI.

## Backend connection & auth (core/sync/)

- `core/sync/` (not a `features/` folder, deliberately — this is cross-cutting infra other features will depend on, like `core/db`) holds: `ConnectionSettings` (secure-storage-backed server URL + device id + session), `ApiClient` (a `Dio` instance with an interceptor that attaches the bearer token and transparently refreshes+retries once on a 401), and `AuthController` — a `ChangeNotifier` following the same pattern as `LockController` (see "App lock" below): plain in-memory phase state (`ConnectionPhase`: checking → disconnected/connectedLoggedOut → loggedIn), not a DB-backed `StreamProvider`.
- `AuthController` has a `.debugDisconnected()` test-only constructor, same reasoning and pattern as `LockController.debugUnlocked()` — `flutter_secure_storage`'s platform channel isn't available in widget tests, so a real controller's `_init()` would hang forever. Any new `ChangeNotifier`-based controller that reads secure storage in its constructor needs the same seam.
- `core/sync/` also has the real Phase-3 data sync engine now: `outbox.dart` (finds `syncStatus == 'pending'` rows across all 4 tables, applies push/pull results back), `sync_engine.dart` (one push-then-pull pass; push before pull so a just-pushed row can't be momentarily overwritten by a stale pull), `sync_controller.dart` (the `ChangeNotifier` Settings/AppShell watch for progress), `sync_triggers.dart` (`workmanager` ~15-min periodic task + `connectivity_plus` reconnect listener; resume-triggered sync is *not* a second `WidgetsBindingObserver` — it's called directly from `LockGate`'s existing one, see `features/lock/presentation/lock_gate.dart`). `ConnectionPhase.loggedIn` still only means there's a valid session — check `syncControllerProvider`'s `SyncProgress` for actual sync state.
- Every repository write (`create*`/`update*`/`delete*`/`setArchived`/soft-deletes) across accounts/categories/transactions/budgets sets `syncStatus: Value('pending')` explicitly — the column's schema default (`'synced'`) only applies to rows the sync engine itself writes back from the server (`Outbox.upsert*FromServer`/`markXSynced`). Any new mutation method on these repositories must do the same, or the outbox will silently never pick it up.
- A local row's `originDeviceId` being `null` is the sync engine's signal that the row has never round-tripped through the server (repositories never touch that column) — used to decide whether a push sends `localBaseVersion: null` (insert) vs the row's current `version` (update-or-conflict). Don't repurpose `originDeviceId` for anything else.
- Sync conflicts (`features/sync_conflicts/`) are stored as JSON snapshots (`SyncConflicts` table, client-only, no server counterpart) in a shape that mirrors the server's row format exactly (ISO date strings, `version`/`originDeviceId` included) — see the `_*ToFullJson` helpers in `sync_engine.dart`. Don't swap in Drift's own `.toJson()` for this; its serialization format isn't guaranteed to match the server's wire format, and the two sides of a conflict need to be structurally identical for the diff screen and for `SyncConflictRepository`'s resolve logic (`version` always comes from the server side, field values from whichever side was chosen).
- Changing your password revokes every other device's session server-side (see `backend/src/modules/auth/auth.routes.ts`), so the change-password success message says so — don't remove that copy if you touch `change_password_sheet.dart`.
- The PIN has the equivalent flow: `LockController.changePin()` (verifies the current PIN via `PinStorage.verifyPin` before calling `setPin`) + `features/lock/presentation/change_pin_sheet.dart`, reachable from Settings → Security. Any future "change credential" flow (PIN, password, and eventually a device PIN reset) should follow this same current→new→confirm shape rather than inventing a new one.

## Companion web app (`lib/web/`, `lib/main_web.dart`)

- Second entrypoint, same codebase: `lib/main_web.dart` builds `WebApp` (`lib/web/web_app.dart`), mobile's `lib/main.dart`/`AppShell`/`LockGate` are untouched and never imported from `lib/web/`. Build with `flutter build web -t lib/main_web.dart` — the plain `flutter build web` (defaulting to `lib/main.dart`) builds the *mobile* app for web, which is not what you want and (before the fix below) doesn't compile anyway.
- **Why `core/db/database.dart` has a conditional import.** Drift's `NativeDatabase` (`package:drift/native.dart`) pulls in `package:ffi`, whose `external` FFI function declarations are a hard compile error under dart2js/dartdevc (`Only JS interop members may be 'external'`) — this isn't a Drift-specific limitation, `dart:ffi` itself doesn't exist on web. Since the web app still needs to *reuse* the Drift-generated row types (`Account`, `Category`, `Transaction`, `Budget` — plain data classes, no ffi dependency of their own), the actual `_openConnection()`/`NativeDatabase` call is split into `core/db/connection/native.dart`, selected via `import 'connection/unsupported.dart' if (dart.library.io) 'connection/native.dart'` in `database.dart`. Don't move ffi/`dart:io` imports back into `database.dart` itself — that reintroduces the same web-build failure even for code that never calls `AppDatabase()` on web.
- **Reader/Writer split.** Every feature repository (`account_repository.dart`, `category_repository.dart`, `transaction_repository.dart`, `budget_repository.dart`, `chart_repository.dart`) exposes an abstract `*Reader` interface (watch/query methods — the only thing the web app depends on) and, where mutations exist, a separate `*Writer` interface. `Drift*Repository` implements both; `Api*Repository` (`lib/web/data/`) implements only the reader. `*_providers.dart` picks the implementation via `kIsWeb`, and a second `*WriterProvider` casts to the writer interface, throwing `UnsupportedError` if ever called on web (it never is — see `readOnly` below). **Any new feature repository must follow this same split**, or it can't be reused read-only on web.
- **`WebDataStore` (`lib/web/data/web_data_store.dart`)** is the web app's entire data source: on `load()`, it pages through the *existing* `GET /sync/pull` endpoint from the Unix epoch and materializes the full result into in-memory `Account`/`Category`/`Transaction`/`Budget` lists — there's no separate "list my data" REST API, and no local Drift database on web at all (per the original design decision: view-only, no local storage/sync on web). `Api*Repository` classes compute their `watch*()` results from this in-memory snapshot (mirroring each Drift repository's SQL filtering/sorting in plain Dart) via `watchDerived()`, which mimics Drift's `.watch()` contract (emit current value immediately, then again on every `WebDataStore.refresh()`). If you add a query to a Drift repository's reader interface, add the equivalent in-memory computation to its `Api*Repository` counterpart — they must stay behaviorally equivalent (see `ApiChartRepository.watchMonthlyTotals`'s comment about matching the SQL version's UTC-month grouping specifically).
- **`readOnly` flag, not forked screens.** `AccountsScreen`, `CalendarScreen`/`TransactionTile`, `BudgetsScreen`, and `TransactionSearchScreen` take an additive `readOnly` bool (default `false`) that hides FABs, `Dismissible` swipe actions, and tap-to-edit — the same widget renders on both mobile and `ViewerShell` (`lib/web/presentation/viewer_shell.dart`, the web analogue of `core/app_shell.dart`, minus Settings/backup/import — nothing on web to back them). `ChartsScreen` needed no `readOnly` flag; it was already pure display. Extend this pattern for any new screen the web app should show, rather than writing a parallel web-only copy.
- **Routing** is `go_router` (the only place it's imported — mobile's `Navigator`-based routing is untouched): `/login` (`lib/web/presentation/login_screen.dart`, new UI but 100% reused `AuthController`/`ApiClient` — `flutter_secure_storage` needed no web-specific handling), `/` → `ViewerShell`, `/admin` → `AdminGate`. The router's `redirect` only handles `/login` vs `/` based on `ConnectionPhase`; `/admin` is deliberately left alone by the redirect and handles its own auth UI (see next point).
- **Admin panel (`lib/web/admin/`)** has its own effective login gate: `AdminGate` shows the same `LoginScreen` when signed out (one account system, one backend — there's no separate "admin credentials"), then — once logged in — calls `GET /auth/me` and checks `isAdmin` before rendering `AdminShell`. This mirrors the backend's own `requireAdmin()` (DB-checked, never trusted from a JWT claim) on the client side: a logged-in non-admin hitting `/admin` sees an explicit "this account doesn't have admin access" screen, not a silent redirect. `AdminShell` (user list → device list, showing last-sign-in/last-sync/last-sync-status) and `CreateUserScreen` (→ `POST /admin/users`, one-time generated-password dialog, same "shown once, never re-displayed" convention as `create-user.ts`) only ever call the `/admin/*` and `/auth/me` endpoints, which are metadata-only by construction on the backend — there's no financial data this client could accidentally render even with a bug.

## Manual verification still needed

Everything above is verified via `flutter analyze`, `flutter test` (58/58), `bunx tsc --noEmit` (backend), and local `flutter build web -t lib/main_web.dart` — this dev environment has no Docker, so **none of it has run against a live Postgres/backend yet**. Before relying on this in production, run through `backend/README.md`'s verification section plus:

1. Two-device mobile sync: offline edits on both, reconnect, confirm convergence and correct Settings status; force a same-row conflict and round-trip all three resolutions (Keep mine/Keep other/Edit manually).
2. `docker compose build web && docker compose up -d --wait web`, then load the web app against a real backend: log in, confirm data matches mobile for the same account, confirm no mutation affordances render anywhere, hard-refresh to confirm the session survives (verifies `flutter_secure_storage`'s web backend is actually persistent — never confirmed locally).
3. `/admin`: non-admin login → access-denied screen; admin login → user/device list populates, create-user round-trips (new user can log in with the generated password); confirm the rendered page never contains a financial figure (grep the DOM for a known test transaction amount).
4. Off-network (mobile data/VPN): hit both subdomains through NPM/TLS, hard-refresh `/admin` to confirm the nginx SPA fallback works (not a 404), check devtools for CORS failures.

## Known Android build gotchas

If `flutter run`/Gradle fails with a cryptic error on a fresh machine setup, check these before re-diagnosing from scratch — none of them are caused by anything in this codebase:

1. **`IllegalArgumentException: <jdk version>` from Gradle's Kotlin DSL compiler.** Android Studio's bundled JDK can be newer than Gradle's embedded Kotlin/IntelliJ platform supports parsing. Fix: install a JDK 21 (LTS) separately and pin it in `android/gradle.properties` via `org.gradle.java.home=<path>` — Android Studio's own "Gradle JVM" IDE setting does **not** affect `flutter run`/`gradlew` invoked from the command line or VS Code, only its own internal sync.
2. **AGP's SDK auto-installer failing** (`InstallFailedException`) for the NDK or CMake mid-build. Install the missing component manually via the Android cmdline-tools: `cmdline-tools/latest/bin/android.exe sdk install "cmake/3.22.1"` (package id format is `<name>/<version>`, a slash — not the legacy `sdkmanager`'s `<name>;<version>`).
3. **`sqlite3_flutter_libs` silently not bundling `libsqlite3.so`.** The app installs and launches fine, but any DB query throws `Failed to load dynamic library 'libsqlite3.so': dlopen failed: library "libsqlite3.so" not found`. Some pub.dev releases of this package (anything tagged `+eol`) are deprecation markers pointing at Dart's native-assets/hooks pipeline, which may not actually produce/bundle the library depending on the Flutter SDK version. Pin to the last classic pre-deprecation release instead (currently `^0.5.42` in `pubspec.yaml`) and verify by checking the built APK directly: `unzip -l build/app/outputs/flutter-apk/app-debug.apk | grep libsqlite3.so` should list it for every target ABI.
4. **`local_auth` biometric prompt does nothing on Android.** `MainActivity` must extend `io.flutter.embedding.android.FlutterFragmentActivity`, not the default `FlutterActivity` — the biometric prompt needs a `FragmentActivity` to attach to and fails silently otherwise. Already fixed in `android/app/src/main/kotlin/.../MainActivity.kt`; don't revert it back to `FlutterActivity`.
