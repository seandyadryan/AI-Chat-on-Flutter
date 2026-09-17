# AI Chat on Flutter

Flutter Android app with Google sign-in, an Oracle-hosted Node.js API, PostgreSQL, and Google Gemini.

## Project

- Flutter SDK: `3.41.2` via FVM
- Android package: `com.deploydulupulangnanti.neurax`
- Backend database: PostgreSQL
- AI provider: Google Gemini API (`gemini-3.6-flash` by default)

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

Set `GEMINI_API_KEY` to your Google AI Studio API key and `GEMINI_MODEL` to the
desired Gemini text model. Keep the key only in the backend environment; never
put it in Flutter assets or commit it to Git. The backend calls Google's
[generateContent API](https://ai.google.dev/api/generate-content) over HTTPS.
Ollama is no longer required. Existing knowledge-base answers remain supported.

Start the API and database:

```bash
docker compose -f docker-compose.oracle.yml up -d --build
```

Health check:

```bash
curl http://localhost/health

```

The compose file runs Caddy in front of the API. Caddy publishes ports `80` and `443`, then creates HTTPS automatically for `api.amarlo.online` after the DNS record points to the Oracle VM public IP.

For an existing deployment, back up `server/.env` and the backend source, update
the backend files and Gemini environment variables, then rebuild only the API:

```bash
docker compose -f docker-compose.oracle.yml up -d --no-deps --build api
curl --fail https://api.amarlo.online/health
```

Preserve any server-specific Caddy routes used by other applications. The Flutter
API endpoints are unchanged, so this provider switch does not require a new APK.
The API sends the latest 20 chat messages to Gemini and times out after 45 seconds.

Run backend tests with `cd server && npm test`.

## Git Hook

This repo includes a pre-commit hook that increments the Flutter build number in `pubspec.yaml` by `+1` on every commit.

Enable it once:

```bash
git config core.hooksPath .githooks
```
