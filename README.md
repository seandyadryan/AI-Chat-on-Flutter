# AI Chat on Flutter

Flutter Android app with guest chat access, an Oracle-hosted Node.js API, PostgreSQL, and Ollama.

## Project

- Flutter SDK: `3.41.2` via FVM
- Android package: `com.seandyadryan.ai_chat_app`
- App API target: `https://api.amarlo.online`
- Backend database: PostgreSQL
- AI runtime: Ollama on the Oracle VM

## Flutter Setup

Update `.env`:

```env
API_BASE_URL=https://api.amarlo.online
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

```env
PORT=8080
DATABASE_URL=postgresql://aiuser:GantiPasswordKuat123!@postgres:5432/aidb
JWT_SECRET=replace-with-a-long-random-secret
OLLAMA_BASE_URL=http://host.docker.internal:11434
OLLAMA_MODEL=llama3.2:3b
```

Start the API and database:

```bash
docker compose -f docker-compose.oracle.yml up -d --build
```

Health check:

```bash
curl http://localhost/health
curl https://api.amarlo.online/health
```

The compose file runs Caddy in front of the API. Caddy publishes ports `80` and `443`, then creates HTTPS automatically for `api.amarlo.online` after the DNS record points to the Oracle VM public IP.

## Git Hook

This repo includes a pre-commit hook that increments the Flutter build number in `pubspec.yaml` by `+1` on every commit.

Enable it once:

```bash
git config core.hooksPath .githooks
```
