# AI Chat on Flutter

Flutter Android app with guest chat access, an Oracle-hosted Node.js API, PostgreSQL, and Ollama.

## Project

- Flutter SDK: `3.41.2` via FVM
- Android package: `com.deploydulupulangnanti.neurax`
- Backend database: PostgreSQL
- AI runtime: Ollama on the Oracle VM

## Flutter Setup

Update `.env`:

```env
API_BASE_URL=http://168.110.194.144
GOOGLE_SERVER_CLIENT_ID=your-google-web-client-id.apps.googleusercontent.com
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

Copy the repository to the Oracle VM, then create `server/.env` from `server/.env.example`:

Start the API and database:

```bash
docker compose -f docker-compose.oracle.yml up -d --build
```

Health check:

```bash
curl http://localhost/health

```

The compose file runs Caddy in front of the API. Caddy publishes ports `80` and `443`, then creates HTTPS automatically for `api.amarlo.online` after the DNS record points to the Oracle VM public IP.

## Git Hook

This repo includes a pre-commit hook that increments the Flutter build number in `pubspec.yaml` by `+1` on every commit.

Enable it once:

```bash
git config core.hooksPath .githooks
```
