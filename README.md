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

