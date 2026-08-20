<table border="0">
<tr>
<td>

# Money Manager

A private, offline-first money tracker I built for myself — track accounts, transactions, categories and budgets without handing your financial data to some app in the cloud.

**Android only** for now.

</td>
<td align="right" valign="top">

[![Download APK](https://img.shields.io/badge/Download-APK-3DDC84?style=for-the-badge&logo=android&logoColor=white)](../../releases/latest)

</td>
</tr>
</table>

- **`app/`** — the Flutter app. Works fully offline with a local SQLite database.
- **`backend/`** — an optional self-hosted sync server (Bun + Postgres) if you want to sync between your own devices. Not required to just use the app.

## Get the app

Click the **Download APK** button above (or go to [Releases](../../releases)), grab the latest `app-release.apk`, and install it on your Android phone. You'll need to allow "install from unknown sources" once, since it's not from the Play Store.

## Build it yourself

```sh
cd app
flutter pub get
flutter build apk --release
```

The APK ends up at `app/build/app/outputs/flutter-apk/app-release.apk`.

More details in [app/README.md](app/README.md) and [backend/README.md](backend/README.md). The full project plan/architecture is in [PRD.md](PRD.md).

## License

MIT — do whatever you want with it.
