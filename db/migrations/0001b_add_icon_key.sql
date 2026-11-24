-- ============================================================
-- Step 2b addendum — Decision Q1 (1a): add products.icon_key
-- Reason: mock UI uses lucide icon keys; real photos arrive Phase 5.
-- Nullable; can be dropped later without touching anything else.
-- ============================================================
BEGIN;
ALTER TABLE products ADD COLUMN icon_key TEXT;
COMMIT;