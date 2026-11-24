#!/usr/bin/env sh
set -eu

docker compose exec -T db pg_dump -U "${POSTGRES_USER:-binutech}" "${POSTGRES_DB:-binutech}"

