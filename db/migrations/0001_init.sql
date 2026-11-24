-- ============================================================
-- Biniyam Tech Mobile Center — Initial Schema
-- SRS Version: 1.0  |  Migration: 0001_init
-- Faithful to SRS §6.1 "Core Data Entities" (Table 6-1)
-- Constraint C-3 / NFR-05: NO card numbers, NO wallet credentials.
-- v1.1 entities (Customer, Address) are RESERVED as comments only.
-- ============================================================

BEGIN;

-- ------------------------------------------------------------
-- 0. Extensions
-- ------------------------------------------------------------
CREATE EXTENSION IF NOT EXISTS "pgcrypto";   -- gen_random_uuid()
CREATE EXTENSION IF NOT EXISTS "citext";     -- case-insensitive email

-- ------------------------------------------------------------
-- 1. Category  (SRS 6.1: name, slug, parent_id, sort_order, is_active)
-- ------------------------------------------------------------
CREATE TABLE categories (
  id          BIGSERIAL    PRIMARY KEY,
  name        TEXT         NOT NULL,
  slug        TEXT         NOT NULL UNIQUE,
  parent_id   BIGINT       REFERENCES categories(id) ON DELETE SET NULL,
  sort_order  INT          NOT NULL DEFAULT 0,
  is_active   BOOLEAN      NOT NULL DEFAULT TRUE,
  created_at  TIMESTAMPTZ  NOT NULL DEFAULT now(),
  updated_at  TIMESTAMPTZ  NOT NULL DEFAULT now()
);
CREATE INDEX idx_categories_parent ON categories(parent_id);
CREATE INDEX idx_categories_active ON categories(is_active) WHERE is_active;

-- ------------------------------------------------------------
-- 2. Brand  (SRS 6.1: name, slug, logo_url)
-- ------------------------------------------------------------
CREATE TABLE brands (
  id          BIGSERIAL    PRIMARY KEY,
  name        TEXT         NOT NULL UNIQUE,
  slug        TEXT         NOT NULL UNIQUE,
  logo_url    TEXT,
  created_at  TIMESTAMPTZ  NOT NULL DEFAULT now()
);

-- ------------------------------------------------------------
-- 3. Product  (SRS 6.1: name, slug, category_id, brand_id,
--              description, specs JSONB, images)
-- ------------------------------------------------------------
CREATE TABLE products (
  id           BIGSERIAL    PRIMARY KEY,
  name         TEXT         NOT NULL,
  slug         TEXT         NOT NULL UNIQUE,
  category_id  BIGINT       NOT NULL REFERENCES categories(id) ON DELETE RESTRICT,
  brand_id     BIGINT       NOT NULL REFERENCES brands(id)     ON DELETE RESTRICT,
  description  TEXT         NOT NULL DEFAULT '',
  specs        JSONB        NOT NULL DEFAULT '[]'::jsonb,   -- [{label, value}, ...]
  images       JSONB        NOT NULL DEFAULT '[]'::jsonb,   -- [url, ...]
  is_featured  BOOLEAN      NOT NULL DEFAULT FALSE,          -- drives FR-01 featured
  is_active    BOOLEAN      NOT NULL DEFAULT TRUE,           -- drives FR-27 hide
  created_at   TIMESTAMPTZ  NOT NULL DEFAULT now(),
  updated_at   TIMESTAMPTZ  NOT NULL DEFAULT now()
);
CREATE INDEX idx_products_category ON products(category_id);
CREATE INDEX idx_products_brand    ON products(brand_id);
CREATE INDEX idx_products_featured ON products(is_featured) WHERE is_featured AND is_active;
CREATE INDEX idx_products_active   ON products(is_active) WHERE is_active;
-- Search (FR-08) — trigram indexes added in migration 0002 when pg_trgm enabled
-- CREATE INDEX idx_products_name_trgm ON products USING gin (name gin_trgm_ops);

-- ------------------------------------------------------------
-- 4. ProductVariant  (SRS 6.1: product_id, attributes JSONB
--                     (colour, storage), price_etb, compare_at_price)
-- ------------------------------------------------------------
CREATE TABLE product_variants (
  id                BIGSERIAL     PRIMARY KEY,
  product_id        BIGINT        NOT NULL REFERENCES products(id) ON DELETE CASCADE,
  sku               TEXT          NOT NULL UNIQUE,             -- internal stable ID for cart/order refs
  attributes        JSONB         NOT NULL DEFAULT '{}'::jsonb, -- {colour: "...", storage: "128GB"}
  price_etb         NUMERIC(12,2) NOT NULL CHECK (price_etb >= 0),
  compare_at_price  NUMERIC(12,2)          CHECK (compare_at_price IS NULL OR compare_at_price >= price_etb),
  image_url         TEXT,
  is_active         BOOLEAN       NOT NULL DEFAULT TRUE,
  created_at        TIMESTAMPTZ   NOT NULL DEFAULT now(),
  updated_at        TIMESTAMPTZ   NOT NULL DEFAULT now()
);
CREATE INDEX idx_variants_product ON product_variants(product_id);
CREATE INDEX idx_variants_active  ON product_variants(is_active) WHERE is_active;

-- ------------------------------------------------------------
-- 5. Inventory  (SRS 6.1: variant_id, quantity, low_stock_threshold)
-- Separate table per SRS — NOT a column on variants.
-- ------------------------------------------------------------
CREATE TABLE inventory (
  variant_id           BIGINT       PRIMARY KEY REFERENCES product_variants(id) ON DELETE CASCADE,
  quantity             INT          NOT NULL DEFAULT 0 CHECK (quantity >= 0),
  low_stock_threshold  INT          NOT NULL DEFAULT 5 CHECK (low_stock_threshold >= 0),
  updated_at           TIMESTAMPTZ  NOT NULL DEFAULT now()
);
CREATE INDEX idx_inventory_low_stock ON inventory(variant_id) WHERE quantity <= low_stock_threshold;

-- ------------------------------------------------------------
-- 6. Cart  (SRS 6.1: session_token, created_at, expires_at)
-- Guest carts; survives ≥14 days (FR-14 uses localStorage client-side,
-- server cart is the source of truth at checkout validation).
-- ------------------------------------------------------------
CREATE TABLE carts (
  id             BIGSERIAL     PRIMARY KEY,
  session_token  TEXT          NOT NULL UNIQUE,
  created_at     TIMESTAMPTZ   NOT NULL DEFAULT now(),
  expires_at     TIMESTAMPTZ   NOT NULL DEFAULT (now() + INTERVAL '30 days')
);
CREATE INDEX idx_carts_expires ON carts(expires_at);

CREATE TABLE cart_items (
  id          BIGSERIAL  PRIMARY KEY,
  cart_id     BIGINT     NOT NULL REFERENCES carts(id) ON DELETE CASCADE,
  variant_id  BIGINT     NOT NULL REFERENCES product_variants(id) ON DELETE CASCADE,
  quantity    INT        NOT NULL CHECK (quantity > 0),
  added_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (cart_id, variant_id)
);

-- ------------------------------------------------------------
-- 7. DeliveryZone  (SRS 6.1: name, fee_etb, estimated_days)
-- ------------------------------------------------------------
CREATE TABLE delivery_zones (
  id              BIGSERIAL     PRIMARY KEY,
  name            TEXT          NOT NULL UNIQUE,
  slug            TEXT          NOT NULL UNIQUE,
  fee_etb         NUMERIC(10,2) NOT NULL CHECK (fee_etb >= 0),
  estimated_days  TEXT          NOT NULL,          -- e.g. '1-2 days'
  is_active       BOOLEAN       NOT NULL DEFAULT TRUE,
  sort_order      INT           NOT NULL DEFAULT 0
);

-- ------------------------------------------------------------
-- 8. Order  (SRS 6.1: order_no, customer contact, address,
--            zone fee, total_etb, status, payment_method)
-- Order status lifecycle (FR-23):
--   pending_payment → paid → preparing → out_for_delivery
--   → delivered | cancelled
-- ------------------------------------------------------------
CREATE TYPE order_status AS ENUM (
  'pending_payment',
  'paid',
  'preparing',
  'out_for_delivery',
  'delivered',
  'cancelled'
);

CREATE TYPE payment_method AS ENUM ('telebirr', 'chapa', 'cod');

CREATE TABLE orders (
  id                BIGSERIAL        PRIMARY KEY,
  order_no          TEXT             NOT NULL UNIQUE,          -- 'BT-123456' (FR-21)
  status            order_status     NOT NULL DEFAULT 'pending_payment',
  payment_method    payment_method   NOT NULL,
  customer_name     TEXT             NOT NULL,
  customer_phone    TEXT             NOT NULL,                 -- +251 format (FR-16)
  city              TEXT             NOT NULL DEFAULT 'Addis Ababa',
  sub_city          TEXT             NOT NULL,                 -- zone name snapshot
  delivery_zone_id  BIGINT           NOT NULL REFERENCES delivery_zones(id) ON DELETE RESTRICT,
  address           TEXT             NOT NULL,
  delivery_note     TEXT,
  zone_fee_etb      NUMERIC(10,2)    NOT NULL CHECK (zone_fee_etb >= 0),
  items_total_etb   NUMERIC(12,2)    NOT NULL CHECK (items_total_etb >= 0),
  total_etb         NUMERIC(12,2)    NOT NULL CHECK (total_etb >= 0),
  placed_at         TIMESTAMPTZ      NOT NULL DEFAULT now(),
  updated_at        TIMESTAMPTZ      NOT NULL DEFAULT now(),
  CONSTRAINT chk_total_matches CHECK (
    total_etb = items_total_etb + zone_fee_etb
  )
);
CREATE INDEX idx_orders_status     ON orders(status);
CREATE INDEX idx_orders_phone      ON orders(customer_phone);
CREATE INDEX idx_orders_placed_at  ON orders(placed_at DESC);
CREATE INDEX idx_orders_lookup     ON orders(order_no, customer_phone);  -- FR-22 lookup

-- ------------------------------------------------------------
-- 9. OrderItem  (SRS 6.1: order_id, variant_id, unit_price_etb, quantity)
-- Plus denormalised name/label snapshots so later catalog edits never
-- distort historical records (SRS 6.1 "Orders snapshot prices").
-- ------------------------------------------------------------
CREATE TABLE order_items (
  id              BIGSERIAL     PRIMARY KEY,
  order_id        BIGINT        NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
  variant_id      BIGINT        NOT NULL REFERENCES product_variants(id) ON DELETE RESTRICT,
  product_name    TEXT          NOT NULL,          -- snapshot
  variant_label   TEXT          NOT NULL,          -- snapshot (e.g. "256GB · Blue")
  unit_price_etb  NUMERIC(12,2) NOT NULL CHECK (unit_price_etb >= 0),  -- snapshot
  quantity        INT           NOT NULL CHECK (quantity > 0),
  line_total_etb  NUMERIC(12,2) NOT NULL CHECK (line_total_etb >= 0),
  CONSTRAINT chk_line_total CHECK (line_total_etb = unit_price_etb * quantity)
);
CREATE INDEX idx_order_items_order ON order_items(order_id);
CREATE INDEX idx_order_items_variant ON order_items(variant_id);

-- ------------------------------------------------------------
-- 10. Payment  (SRS 6.1: order_id, provider, reference_no,
--              status, verified_at)
-- NFR-05: NO card numbers, NO wallet credentials ever stored here.
-- Only provider reference IDs + status flags.
-- ------------------------------------------------------------
CREATE TYPE payment_status AS ENUM ('pending', 'verified', 'failed', 'refunded');

CREATE TABLE payments (
  id            BIGSERIAL       PRIMARY KEY,
  order_id      BIGINT          NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
  provider      payment_method  NOT NULL,               -- telebirr | chapa | cod
  reference_no  TEXT,                                   -- provider-side transaction ref
  status        payment_status  NOT NULL DEFAULT 'pending',
  verified_at   TIMESTAMPTZ,
  amount_etb    NUMERIC(12,2)   NOT NULL CHECK (amount_etb >= 0),
  raw_payload   JSONB,                                  -- webhook payload (sanitised; no secrets)
  created_at    TIMESTAMPTZ     NOT NULL DEFAULT now(),
  updated_at    TIMESTAMPTZ     NOT NULL DEFAULT now()
);
CREATE INDEX idx_payments_order    ON payments(order_id);
CREATE INDEX idx_payments_provider ON payments(provider, reference_no);
CREATE INDEX idx_payments_status   ON payments(status);

-- ------------------------------------------------------------
-- 11. AdminUser  (SRS 6.1: email, password_hash, role, last_login_at)
-- ------------------------------------------------------------
CREATE TABLE admin_users (
  id             BIGSERIAL     PRIMARY KEY,
  email          CITEXT        NOT NULL UNIQUE,
  password_hash  TEXT          NOT NULL,                -- bcrypt/argon2 (FR-26)
  role           TEXT          NOT NULL DEFAULT 'admin',
  last_login_at  TIMESTAMPTZ,
  is_active      BOOLEAN       NOT NULL DEFAULT TRUE,
  created_at     TIMESTAMPTZ   NOT NULL DEFAULT now()
);
CREATE INDEX idx_admin_active ON admin_users(is_active) WHERE is_active;

-- ------------------------------------------------------------
-- 12. v1.1 RESERVED ENTITIES (SRS §8.2 — do NOT create yet)
-- Kept here as a placeholder so we don't accidentally design them wrong.
-- ------------------------------------------------------------
-- Customer      (phone, password_hash, name)  -- v1.1
-- Address       (customer_id, zone_id, detail, is_default)  -- v1.1
-- ProductReview (product_id, customer_id, rating, body)  -- v1.1
-- Wishlist / WishlistItem  -- v1.1

-- ------------------------------------------------------------
-- 13. Triggers — updated_at maintenance
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION touch_updated_at() RETURNS trigger AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_categories_updated    BEFORE UPDATE ON categories        FOR EACH ROW EXECUTE FUNCTION touch_updated_at();
CREATE TRIGGER trg_products_updated      BEFORE UPDATE ON products          FOR EACH ROW EXECUTE FUNCTION touch_updated_at();
CREATE TRIGGER trg_variants_updated      BEFORE UPDATE ON product_variants  FOR EACH ROW EXECUTE FUNCTION touch_updated_at();
CREATE TRIGGER trg_inventory_updated     BEFORE UPDATE ON inventory         FOR EACH ROW EXECUTE FUNCTION touch_updated_at();
CREATE TRIGGER trg_orders_updated        BEFORE UPDATE ON orders            FOR EACH ROW EXECUTE FUNCTION touch_updated_at();
CREATE TRIGGER trg_payments_updated      BEFORE UPDATE ON payments          FOR EACH ROW EXECUTE FUNCTION touch_updated_at();

COMMIT;