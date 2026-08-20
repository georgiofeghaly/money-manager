# Money Manager

Private, offline-first personal finance tracker. No ads, no analytics, no cloud — your data stays on your device unless you run your own sync backend (see [../backend](../backend)).

See [../PRD.md](../PRD.md) for the full project plan (requirements, architecture, roadmap, current status) and [DESIGN.md](DESIGN.md) for the app's design system and code conventions.

## Running

```sh
flutter pub get
flutter run
```

Needs a JDK 21 pinned via `android/gradle.properties` and a couple of Android SDK components installed manually — see [gotchas noted in DESIGN.md](DESIGN.md) if the build fails with a cryptic Gradle error.

## Testing

```sh
flutter analyze
flutter test
```
