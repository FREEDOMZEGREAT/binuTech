# ============================================================
# Biniyam Tech — root Makefile
# ============================================================

DATABASE_URL ?= postgres://biniyam:biniyam@localhost:5432/biniyam?sslmode=disable
PSQL         := psql "$(DATABASE_URL)"

.PHONY: help db-reset db-seed db-migrate db-shell admin

help:
	@echo "Targets:"
	@echo "  make db-migrate   Apply all migrations (0001, 0001b, ...) in order"
	@echo "  make db-seed      Seed from web/lib/shop-data.ts (mock catalog)"
	@echo "  make db-reset     DROP + migrate + seed (destroys local data)"
	@echo "  make db-shell     Open psql shell"
	@echo "  make admin        Create admin user (prompts for password)"

db-migrate:
	@for f in db/migrations/*.sql; do \
	  echo "→ $$f"; $(PSQL) -v ON_ERROR_STOP=1 -f "$$f" || exit 1; \
	done

db-seed:
	$(PSQL) -v ON_ERROR_STOP=1 \
	  -c "SELECT set_config('app.admin_email', '$${ADMIN_EMAIL:-admin@biniyam.local}', false);" \
	  -c "SELECT set_config('app.admin_password', '$${ADMIN_INIT_PASSWORD:-}', false);"
	$(PSQL) -v ON_ERROR_STOP=1 -f db/seed/seed.sql

db-reset:
	$(PSQL) -c "DROP SCHEMA public CASCADE; CREATE SCHEMA public;"
	$(MAKE) db-migrate
	$(MAKE) db-seed

db-shell:
	$(PSQL)

admin:
	@read -p "Admin email [admin@biniyam.local]: " email; email=$${email:-admin@biniyam.local}; \
	read -s -p "Password: " pw; echo; \
	$(PSQL) -v ON_ERROR_STOP=1 -c "INSERT INTO admin_users (email, password_hash) \
	  VALUES ('$$email', crypt('$$pw', gen_salt('bf', 12))) \
	  ON CONFLICT (email) DO UPDATE SET password_hash = EXCLUDED.password_hash;"