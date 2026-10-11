# Deploying the backend

On the server, in the repo root:

```sh
git pull
cd backend
```

**If a migration was added** (new file under `src/db/migrations/*.sql`):
```sh
docker compose run --rm api bun run migrate
```

**Always** — rebuild and restart the api container:
```sh
docker compose build api
docker compose up -d api
```

**Verify:**
```sh
curl http://localhost:3000/health
# → {"status":"ok"}
```

**Rebuild the web app too**, only if `app/` changed:
```sh
docker compose up -d --build web
```

## Checking a migration actually applied
```sh
docker compose exec postgres psql -U postgres -d money_manager -c '\d <table_name>'
```

## Full config, for reference
See `backend/README.md` — env vars (`.env`), Docker network setup (`npm-network`), first-time setup, sync protocol.
