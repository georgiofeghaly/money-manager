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
- Settings (`features/settings/presentation/settings_screen.dart`) is also where not-yet-built roadmap items get a disabled placeholder row ("Coming soon" section — currently just Sync) as they're planned but not implemented — remove the placeholder the same PR that implements the real feature. Implemented security-relevant settings (e.g. the PIN/biometric lock) get a normal, non-disabled row describing their current state instead.

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
- This currently covers **connecting to a server + logging in + changing your password only** — there is no data sync yet (no push/pull of accounts/transactions/etc., that's Phase 3). Don't assume `ConnectionPhase.loggedIn` means data is syncing; it only means there's a valid session.
- Changing your password revokes every other device's session server-side (see `backend/src/modules/auth/auth.routes.ts`), so the change-password success message says so — don't remove that copy if you touch `change_password_sheet.dart`.
- The PIN has the equivalent flow: `LockController.changePin()` (verifies the current PIN via `PinStorage.verifyPin` before calling `setPin`) + `features/lock/presentation/change_pin_sheet.dart`, reachable from Settings → Security. Any future "change credential" flow (PIN, password, and eventually a device PIN reset) should follow this same current→new→confirm shape rather than inventing a new one.

## Known Android build gotchas

If `flutter run`/Gradle fails with a cryptic error on a fresh machine setup, check these before re-diagnosing from scratch — none of them are caused by anything in this codebase:

1. **`IllegalArgumentException: <jdk version>` from Gradle's Kotlin DSL compiler.** Android Studio's bundled JDK can be newer than Gradle's embedded Kotlin/IntelliJ platform supports parsing. Fix: install a JDK 21 (LTS) separately and pin it in `android/gradle.properties` via `org.gradle.java.home=<path>` — Android Studio's own "Gradle JVM" IDE setting does **not** affect `flutter run`/`gradlew` invoked from the command line or VS Code, only its own internal sync.
2. **AGP's SDK auto-installer failing** (`InstallFailedException`) for the NDK or CMake mid-build. Install the missing component manually via the Android cmdline-tools: `cmdline-tools/latest/bin/android.exe sdk install "cmake/3.22.1"` (package id format is `<name>/<version>`, a slash — not the legacy `sdkmanager`'s `<name>;<version>`).
3. **`sqlite3_flutter_libs` silently not bundling `libsqlite3.so`.** The app installs and launches fine, but any DB query throws `Failed to load dynamic library 'libsqlite3.so': dlopen failed: library "libsqlite3.so" not found`. Some pub.dev releases of this package (anything tagged `+eol`) are deprecation markers pointing at Dart's native-assets/hooks pipeline, which may not actually produce/bundle the library depending on the Flutter SDK version. Pin to the last classic pre-deprecation release instead (currently `^0.5.42` in `pubspec.yaml`) and verify by checking the built APK directly: `unzip -l build/app/outputs/flutter-apk/app-debug.apk | grep libsqlite3.so` should list it for every target ABI.
4. **`local_auth` biometric prompt does nothing on Android.** `MainActivity` must extend `io.flutter.embedding.android.FlutterFragmentActivity`, not the default `FlutterActivity` — the biometric prompt needs a `FragmentActivity` to attach to and fails silently otherwise. Already fixed in `android/app/src/main/kotlin/.../MainActivity.kt`; don't revert it back to `FlutterActivity`.
