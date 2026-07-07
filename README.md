# AI Chat on Flutter

Flutter Android app with Google login, an Oracle-hosted Node.js API, PostgreSQL, and Ollama.

## Project

- Flutter SDK: `3.41.2` via FVM
- Android package: `com.seandyadryan.ai_chat_app`
- App API target: `http://168.110.194.144`
- Backend database: PostgreSQL
- AI runtime: Ollama on the Oracle VM

## Flutter Setup

```

Then run:

```bash
fvm flutter pub get
fvm flutter pub run flutter_launcher_icons
fvm flutter pub run flutter_native_splash:create
fvm flutter run
```

If FVM cannot create symlinks on Windows, run Flutter from the installed SDK directly:

```powershell
C:\Users\seandy.nugraha\fvm\versions\3.41.2\bin\flutter.bat pub get
```

## Oracle Server Deploy


Start the API and database:

```bash
docker compose -f docker-compose.oracle.yml up -d --build
```

Health check:

```bash
curl http://localhost/health
```

The compose file publishes the API on port `80`, matching the Oracle ingress rule you already opened. For production, put the API behind HTTPS on port `443`.

## Git Hook

This repo includes a pre-commit hook that increments the Flutter build number in `pubspec.yaml` by `+1` on every commit.

Enable it once:

```bash
git config core.hooksPath .githooks
```
