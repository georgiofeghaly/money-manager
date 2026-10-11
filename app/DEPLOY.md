# Deploying the Android app

1. Bump the version in `pubspec.yaml` (`version: 1.0.0+1` → `+2`, etc.) if you want Android to treat it as an update rather than a reinstall.
2. Build the release APK:
   ```sh
   flutter build apk --release
   ```
   Output: `build/app/outputs/flutter-apk/app-release.apk`
3. Install on your phone — either:
   - Plugged in via USB: `adb install -r build/app/outputs/flutter-apk/app-release.apk`
   - Or copy the APK to the phone and open it (enable "Install unknown apps" for whatever app you use to open it, first time only)

Note: release builds currently use the debug signing config (no dedicated release keystore set up) — fine for sideloading to your own device, not set up for Play Store distribution.

If a schema change touched `app/lib/core/db/database.dart` (new/changed table), the phone picks it up automatically on next launch via Drift's migration — no reinstall needed unless something else broke.
