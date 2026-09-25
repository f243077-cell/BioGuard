#!/usr/bin/env bash
# BioGuard — start the full local stack (MQTT broker, backend API, and
# three simulated devices) with Docker Compose.
#
# Usage:
#   ./scripts/start_dev.sh          # build (if needed) and run in the foreground
#   ./scripts/start_dev.sh -d       # same, but detached
#   ./scripts/start_dev.sh down     # stop everything this script started
#
# Anything after the script name is forwarded to `docker compose`, so any
# compose flag works here too (e.g. `./scripts/start_dev.sh up --no-build`).

set -euo pipefail

# Resolve BioGuard/ (this script's parent directory) regardless of where
# it's invoked from, so `./scripts/start_dev.sh` works from anywhere.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/.."

if ! command -v docker >/dev/null 2>&1; then
    echo "Docker is required — install it from https://docs.docker.com/get-docker/" >&2
    exit 1
fi
if ! docker compose version >/dev/null 2>&1; then
    echo "Docker Compose v2 is required (the 'docker compose' subcommand, bundled with Docker Desktop)." >&2
    exit 1
fi

if [ ! -f .env ] && [ -f .env.example ]; then
    cp .env.example .env
    echo "Created .env from .env.example — edit it to change ports or set a real JWT_SECRET_KEY."
fi

if [ "${1-}" = "down" ]; then
    shift
    exec docker compose down "$@"
fi

# Reflects whatever's actually in .env, so this stays correct if you've
# changed the ports there.
if [ -f .env ]; then
    set -a
    # shellcheck disable=SC1091
    . ./.env
    set +a
fi

echo "Starting BioGuard:"
echo "  MQTT broker:  localhost:${MQTT_PORT:-1883}"
echo "  Backend API:  http://localhost:${BACKEND_PORT:-8000}  (interactive docs at /docs)"
echo

exec docker compose up --build "$@"
