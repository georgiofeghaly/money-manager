#!/usr/bin/env bash
# One-command bring-up: network, build, postgres, migrate, api.
# Re-run any time to rebuild + re-migrate after a git pull.
set -euo pipefail
cd "$(dirname "$0")"

if [ ! -f .env ]; then
  echo "Missing .env — copy .env.example to .env and set POSTGRES_PASSWORD/JWT_SECRET first." >&2
  exit 1
fi

if ! docker network inspect npm-network >/dev/null 2>&1; then
  echo "Creating npm-network..."
  docker network create npm-network
fi

echo "Building api image..."
docker compose build api

echo "Starting postgres..."
docker compose up -d --wait postgres

echo "Running migrations..."
docker compose run --rm api bun run src/scripts/migrate.ts

echo "Starting api..."
docker compose up -d --wait api

echo "Building web image..."
docker compose build web

echo "Starting web..."
docker compose up -d --wait web

echo "Health check..."
docker compose exec -T api bun -e "const r = await fetch('http://localhost:3000/health'); console.log(await r.text());" \
  || echo "warning: health check failed — check 'docker compose logs api'"

echo "Done."
