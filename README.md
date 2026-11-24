# BinuTech E-Commerce

BinuTech is a Next.js storefront backed by a Go API and PostgreSQL database.

## Structure

- `frontend/` - Next.js customer and admin web application
- `api/` - Go HTTP API
- `db/migrations/` - ordered PostgreSQL migrations
- `db/seed/` - development seed data
- `docs/` - requirements, API, security and operations documentation
- `e2e/` - Playwright end-to-end tests
- `infra/` - reverse proxy and deployment assets
- `.github/workflows/` - CI and deployment workflows

## Local development

1. Copy `.env.example` to `.env`.
2. Start the services: `docker compose up --build`
3. Open the storefront at `http://localhost:3000`.
4. API health endpoint: `http://localhost:8080/health`.

The frontend currently lives in `frontend/`. It can be renamed to `web/` later once
imports and deployment configuration are updated.

## Neon PostgreSQL setup

Neon is not configured yet. The API accepts any PostgreSQL connection URL, but
Docker Compose currently has a local PostgreSQL fallback.

1. Create or open your Neon project.
2. Copy `.env.example` to `.env`.
3. Replace `DATABASE_URL` with the Neon connection string:

   ```env
   DATABASE_URL=postgresql://USER:PASSWORD@YOUR_NEON_HOST/neondb?sslmode=require
   ```

4. Apply migrations to Neon, in filename order:

   With the Go migration command (no Docker required):

   ```powershell
   cd api
   go run ./cmd/migrate ../db/migrations
   ```

   Alternatively, with Docker:

   ```powershell
   docker run --rm -v ${PWD}/db/migrations:/migrations postgres:15-alpine `
     sh -c 'for file in /migrations/*.sql; do psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f "$file" || exit 1; done'
   ```

   PowerShell requires `$DATABASE_URL` to be passed into the container:

   ```powershell
   $env:DATABASE_URL = (Get-Content .env | Where-Object { $_ -match '^DATABASE_URL=' }) -replace '^DATABASE_URL=', ''
   docker run --rm -e DATABASE_URL="$env:DATABASE_URL" -v ${PWD}/db/migrations:/migrations postgres:15-alpine sh -c 'for file in /migrations/*.sql; do psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f "$file" || exit 1; done'
   ```

5. Optional seed data:

   ```powershell
   cd api
   go run ./cmd/migrate ../db/seed
   ```

   Or use Docker:

   ```powershell
   docker run --rm -e DATABASE_URL="$env:DATABASE_URL" -v ${PWD}/db/seed:/seed postgres:15-alpine sh -c 'psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f /seed/seed.sql'
   ```

6. Start API and frontend:

   ```powershell
   docker compose up --build
   ```

