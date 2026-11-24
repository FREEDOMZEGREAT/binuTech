-- ============================================================
-- Biniyam Tech Mobile Center — Seed Data
-- Source: web/lib/shop-data.ts (mock catalog)
-- FK-safe order: categories → brands → products → variants → inventory
--                → delivery_zones → admin bootstrap
-- Idempotent-ish: uses ON CONFLICT DO NOTHING on natural keys so re-running
-- is safe for local dev. NOT for production seeding (Phase 5 uses owner data).
-- ============================================================

BEGIN;

-- ------------------------------------------------------------
-- 1. CATEGORIES  (SRS §3.1 — 5 top-level categories)
-- slug = shop-data.ts CategoryId; name/blurb from CATEGORY_META
-- ------------------------------------------------------------
INSERT INTO categories (name, slug, parent_id, sort_order, is_active) VALUES
  ('Flagship Phones',   'flagship',      NULL, 1, TRUE),
  ('Mid-Range Phones',  'mid-range',     NULL, 2, TRUE),
  ('Budget Phones',     'budget',        NULL, 3, TRUE),
  ('Feature Phones',    'feature-phone', NULL, 4, TRUE),
  ('Mobile Accessories','accessories',   NULL, 5, TRUE)
ON CONFLICT (slug) DO NOTHING;

-- ------------------------------------------------------------
-- 2. BRANDS  (deduped from Product.brand in shop-data.ts)
-- ------------------------------------------------------------
INSERT INTO brands (name, slug, logo_url) VALUES
  ('Samsung', 'samsung', NULL),
  ('Apple',   'apple',   NULL),
  ('Tecno',   'tecno',   NULL),
  ('Infinix', 'infinix', NULL),
  ('Xiaomi',  'xiaomi',  NULL),
  ('itel',    'itel',    NULL),
  ('Nokia',   'nokia',   NULL),
  ('Biniyam', 'biniyam', NULL),
  ('Oraimo',  'oraimo',  NULL),
  ('SanDisk', 'sandisk', NULL),
  ('Anker',   'anker',   NULL)
ON CONFLICT (slug) DO NOTHING;

-- ------------------------------------------------------------
-- 3. PRODUCTS  (20 products from shop-data.ts)
-- slug = shop-data.ts Product.id
-- specs = JSONB array of {label,value}
-- icon_key = shop-data.ts Product.icon (lucide key, decision Q1/1a)
-- is_featured = shop-data.ts Product.featured
-- ------------------------------------------------------------
INSERT INTO products (name, slug, category_id, brand_id, description, specs, images, is_featured, is_active, icon_key)
SELECT p.name, p.slug, c.id, b.id, p.tagline,
       p.specs::jsonb, '[]'::jsonb, p.featured, TRUE, p.icon
FROM (VALUES
  ('Samsung Galaxy S24 Ultra','galaxy-s24-ultra','flagship','samsung',
   'Titanium body, 200MP camera and Galaxy AI',
   '[{"label":"Display","value":"6.8\" QHD+ AMOLED, 120Hz"},{"label":"Battery","value":"5000 mAh, 45W fast charge"},{"label":"Camera","value":"200MP main + 50MP periscope"},{"label":"Warranty","value":"1 year official warranty"}]',
   TRUE,'smartphone'),
  ('Apple iPhone 15','iphone-15','flagship','apple',
   'Dynamic Island, 48MP camera, USB-C',
   '[{"label":"Display","value":"6.1\" Super Retina XDR"},{"label":"Chip","value":"A16 Bionic"},{"label":"Camera","value":"48MP dual system"},{"label":"Warranty","value":"1 year store warranty"}]',
   TRUE,'smartphone'),
  ('Samsung Galaxy A55 5G','galaxy-a55','mid-range','samsung',
   'Super AMOLED 120Hz with 5G speed',
   '[{"label":"Display","value":"6.6\" Super AMOLED, 120Hz"},{"label":"Battery","value":"5000 mAh, 25W"},{"label":"Memory","value":"8GB RAM"},{"label":"Warranty","value":"1 year official warranty"}]',
   TRUE,'smartphone'),
  ('Tecno Camon 30','camon-30','mid-range','tecno',
   '50MP portrait camera with slim design',
   '[{"label":"Display","value":"6.78\" AMOLED, 120Hz"},{"label":"Battery","value":"5000 mAh, 70W ultra charge"},{"label":"Memory","value":"8GB RAM + 256GB"},{"label":"Warranty","value":"1 year official warranty"}]',
   FALSE,'smartphone'),
  ('Infinix Note 40','note-40','mid-range','infinix',
   'Fast 70W charging and big AMOLED screen',
   '[{"label":"Display","value":"6.78\" AMOLED, 120Hz"},{"label":"Battery","value":"5000 mAh, 70W Hyper Charge"},{"label":"Memory","value":"8GB RAM + 256GB"},{"label":"Warranty","value":"1 year official warranty"}]',
   FALSE,'smartphone'),
  ('Xiaomi Redmi Note 13','redmi-note-13','mid-range','xiaomi',
   '108MP camera with slim AMOLED body',
   '[{"label":"Display","value":"6.67\" AMOLED, 120Hz"},{"label":"Battery","value":"5000 mAh, 33W"},{"label":"Camera","value":"108MP triple camera"},{"label":"Warranty","value":"1 year store warranty"}]',
   FALSE,'smartphone'),
  ('Samsung Galaxy A15','galaxy-a15','budget','samsung',
   'Super AMOLED display at a friendly price',
   '[{"label":"Display","value":"6.5\" Super AMOLED"},{"label":"Battery","value":"5000 mAh, 25W"},{"label":"Memory","value":"4GB RAM + 128GB"},{"label":"Warranty","value":"1 year official warranty"}]',
   TRUE,'smartphone'),
  ('Tecno Spark 20','spark-20','budget','tecno',
   'Big screen and 90Hz smoothness',
   '[{"label":"Display","value":"6.6\" HD+, 90Hz"},{"label":"Battery","value":"5000 mAh, 18W"},{"label":"Memory","value":"4GB RAM + 128GB"},{"label":"Warranty","value":"1 year official warranty"}]',
   FALSE,'smartphone'),
  ('Infinix Hot 40i','hot-40i','budget','infinix',
   'All-day battery with punch-hole design',
   '[{"label":"Display","value":"6.6\" HD+, 90Hz"},{"label":"Battery","value":"5000 mAh, 18W"},{"label":"Memory","value":"8GB RAM + 256GB"},{"label":"Warranty","value":"1 year official warranty"}]',
   FALSE,'smartphone'),
  ('itel A70','itel-a70','budget','itel',
   'Android 13 Go with big battery',
   '[{"label":"Display","value":"6.6\" HD+ notch"},{"label":"Battery","value":"5000 mAh"},{"label":"Memory","value":"3GB RAM + 64GB"},{"label":"Warranty","value":"1 year official warranty"}]',
   FALSE,'smartphone'),
  ('Nokia 105 (2024)','nokia-105','feature-phone','nokia',
   'Weeks of battery, built to last',
   '[{"label":"Display","value":"1.8\" QQVGA"},{"label":"Battery","value":"Up to 20 days standby"},{"label":"Extras","value":"FM radio, flashlight, dual SIM"},{"label":"Warranty","value":"1 year official warranty"}]',
   FALSE,'smartphone'),
  ('Nokia 110 (2024)','nokia-110','feature-phone','nokia',
   'Dual SIM with camera and MP3 player',
   '[{"label":"Display","value":"1.8\" QQVGA"},{"label":"Battery","value":"Up to 18 days standby"},{"label":"Extras","value":"Camera, FM radio, MP3"},{"label":"Warranty","value":"1 year official warranty"}]',
   FALSE,'smartphone'),
  ('Biniyam SoundPods TWS','tws-buds','accessories','biniyam',
   'True wireless earbuds with charging case',
   '[{"label":"Playback","value":"Up to 5 hours per charge"},{"label":"Extras","value":"Touch controls, ENC calls"},{"label":"Compatibility","value":"All phones via Bluetooth 5.3"},{"label":"Warranty","value":"6 months store warranty"}]',
   TRUE,'headphones'),
  ('Oraimo PowerGen 20000mAh','powerbank-20k','accessories','oraimo',
   'Triple-output power bank with flashlight',
   '[{"label":"Capacity","value":"20000 mAh"},{"label":"Output","value":"22.5W fast charge, 3 ports"},{"label":"Compatibility","value":"All phones and tablets"},{"label":"Warranty","value":"6 months store warranty"}]',
   FALSE,'battery'),
  ('Braided USB-C Cable 2m','typec-cable','accessories','oraimo',
   'Fast-charge braided cable, 2 meters',
   '[{"label":"Current","value":"Up to 5A fast charging"},{"label":"Length","value":"2 meters braided nylon"},{"label":"Compatibility","value":"All USB-C phones"},{"label":"Warranty","value":"3 months store warranty"}]',
   FALSE,'cable'),
  ('20W USB-C Fast Wall Adapter','adapter-20w','accessories','anker',
   'Compact PD adapter for quick top-ups',
   '[{"label":"Power","value":"20W Power Delivery"},{"label":"Ports","value":"1x USB-C PD"},{"label":"Compatibility","value":"iPhone, Samsung, and more"},{"label":"Warranty","value":"6 months store warranty"}]',
   FALSE,'plug'),
  ('Shockproof Armor Case','armor-case','accessories','biniyam',
   'Military-grade drop protection case',
   '[{"label":"Material","value":"TPU + PC hybrid"},{"label":"Protection","value":"Corner airbags, raised edges"},{"label":"Compatibility","value":"Popular Samsung and iPhone models"},{"label":"Warranty","value":"1 month replacement"}]',
   FALSE,'shield'),
  ('9H Tempered Glass Protector','tempered-glass','accessories','biniyam',
   'Crystal-clear scratch protection',
   '[{"label":"Hardness","value":"9H tempered glass"},{"label":"Finish","value":"Anti-fingerprint coating"},{"label":"Compatibility","value":"Popular phone models in store"},{"label":"Warranty","value":"Installation included"}]',
   FALSE,'shield'),
  ('128GB microSD Card','memory-128','accessories','sandisk',
   'Class 10 card for photos and media',
   '[{"label":"Capacity","value":"128GB"},{"label":"Speed","value":"Up to 120 MB/s read"},{"label":"Compatibility","value":"Phones, tablets, cameras"},{"label":"Warranty","value":"1 year limited warranty"}]',
   FALSE,'hard-drive'),
  ('Bluetooth Go-Play Speaker','btspeaker','accessories','oraimo',
   'Loud 10W speaker with deep bass',
   '[{"label":"Output","value":"10W stereo sound"},{"label":"Battery","value":"Up to 8 hours playback"},{"label":"Extras","value":"AUX, microSD, FM radio"},{"label":"Warranty","value":"6 months store warranty"}]',
   FALSE,'speaker'),
  ('Fit Band 8 Smart Band','smart-band','accessories','oraimo',
   'Fitness tracking with 14-day battery',
   '[{"label":"Display","value":"1.57\" AMOLED touch"},{"label":"Battery","value":"Up to 14 days"},{"label":"Extras","value":"Heart rate, sleep, sport modes"},{"label":"Warranty","value":"6 months store warranty"}]',
   FALSE,'watch')
) AS p(name, slug, category_slug, brand_slug, tagline, specs, featured, icon)
JOIN categories c ON c.slug = p.category_slug
JOIN brands    b ON b.slug = p.brand_slug
ON CONFLICT (slug) DO NOTHING;

-- ------------------------------------------------------------
-- 4. PRODUCT VARIANTS  (~30 rows)
-- sku  = "{product_slug}:{variant_id}"  — stable public reference
-- attributes = {"label": "<variant label>"}  — keeps the human-readable string
-- ------------------------------------------------------------
INSERT INTO product_variants (product_id, sku, attributes, price_etb, compare_at_price, image_url, is_active)
SELECT pr.id, v.sku, v.attributes::jsonb, v.price, v.compare_at, NULL, TRUE
FROM (VALUES
  ('galaxy-s24-ultra:512-ti','galaxy-s24-ultra','{"label":"512GB · Titanium Gray"}',134999,139999),
  ('galaxy-s24-ultra:256-ti','galaxy-s24-ultra','{"label":"256GB · Titanium Black"}',124999,NULL),
  ('iphone-15:128-blk','iphone-15','{"label":"128GB · Black"}',119999,NULL),
  ('iphone-15:256-blk','iphone-15','{"label":"256GB · Blue"}',129999,NULL),
  ('galaxy-a55:128-awesome','galaxy-a55','{"label":"128GB · Awesome Navy"}',47999,NULL),
  ('galaxy-a55:256-awesome','galaxy-a55','{"label":"256GB · Awesome Lilac"}',52999,NULL),
  ('camon-30:256-basics','camon-30','{"label":"256GB · Basaltic Dark"}',29999,NULL),
  ('note-40:256-titan','note-40','{"label":"256GB · Titan Gold"}',27499,NULL),
  ('redmi-note-13:128-mint','redmi-note-13','{"label":"128GB · Mint Green"}',26999,NULL),
  ('redmi-note-13:256-midnight','redmi-note-13','{"label":"256GB · Midnight Black"}',29999,NULL),
  ('galaxy-a15:128-blue','galaxy-a15','{"label":"128GB · Blue Black"}',24999,NULL),
  ('galaxy-a15:128-yellow','galaxy-a15','{"label":"128GB · Light Blue"}',24999,NULL),
  ('spark-20:128-magic','spark-20','{"label":"128GB · Magic Skin Blue"}',15499,NULL),
  ('hot-40i:256-palm','hot-40i','{"label":"256GB · Palm Blue"}',13999,NULL),
  ('itel-a70:64-black','itel-a70','{"label":"64GB · Brillant Gold"}',9999,NULL),
  ('nokia-105:std-black','nokia-105','{"label":"Standard · Black"}',2799,NULL),
  ('nokia-110:std-blue','nokia-110','{"label":"Standard · Blue"}',3299,NULL),
  ('tws-buds:std-white','tws-buds','{"label":"Standard · White"}',2499,2999),
  ('powerbank-20k:std','powerbank-20k','{"label":"Standard · Black"}',3499,NULL),
  ('typec-cable:std','typec-cable','{"label":"Standard · Black"}',499,NULL),
  ('adapter-20w:std','adapter-20w','{"label":"Standard · White"}',1499,NULL),
  ('armor-case:a15','armor-case','{"label":"For Galaxy A15 · Black"}',599,NULL),
  ('armor-case:a55','armor-case','{"label":"For Galaxy A55 · Black"}',599,NULL),
  ('armor-case:ip15','armor-case','{"label":"For iPhone 15 · Black"}',799,NULL),
  ('tempered-glass:std','tempered-glass','{"label":"Universal cut (fit at store)"}',349,NULL),
  ('memory-128:std','memory-128','{"label":"Standard · Black"}',899,NULL),
  ('btspeaker:std','btspeaker','{"label":"Standard · Black"}',2199,NULL),
  ('smart-band:std','smart-band','{"label":"Standard · Black"}',3999,NULL)
) AS v(sku, product_slug, attributes, price, compare_at)
JOIN products pr ON pr.slug = v.product_slug
ON CONFLICT (sku) DO NOTHING;

-- ------------------------------------------------------------
-- 5. INVENTORY  (stock counts from shop-data.ts Variant.stock)
-- low_stock_threshold default 5 unless stock=0
-- ------------------------------------------------------------
INSERT INTO inventory (variant_id, quantity, low_stock_threshold)
SELECT pv.id, s.qty, COALESCE(s.threshold, 5)
FROM (VALUES
  ('galaxy-s24-ultra:512-ti', 4,  5),
  ('galaxy-s24-ultra:256-ti', 6,  5),
  ('iphone-15:128-blk', 3, 5),
  ('iphone-15:256-blk', 2, 5),
  ('galaxy-a55:128-awesome', 8, 5),
  ('galaxy-a55:256-awesome', 5, 5),
  ('camon-30:256-basics', 10, 5),
  ('note-40:256-titan', 7, 5),
  ('redmi-note-13:128-mint', 9, 5),
  ('redmi-note-13:256-midnight', 4, 5),
  ('galaxy-a15:128-blue', 12, 5),
  ('galaxy-a15:128-yellow', 0, 5),      -- out of stock in mock
  ('spark-20:128-magic', 15, 5),
  ('hot-40i:256-palm', 11, 5),
  ('itel-a70:64-black', 20, 5),
  ('nokia-105:std-black', 30, 5),
  ('nokia-110:std-blue', 18, 5),
  ('tws-buds:std-white', 25, 5),
  ('powerbank-20k:std', 14, 5),
  ('typec-cable:std', 40, 5),
  ('adapter-20w:std', 22, 5),
  ('armor-case:a15', 16, 5),
  ('armor-case:a55', 12, 5),
  ('armor-case:ip15', 9, 5),
  ('tempered-glass:std', 50, 5),
  ('memory-128:std', 26, 5),
  ('btspeaker:std', 10, 5),
  ('smart-band:std', 8, 5)
) AS s(sku, qty, threshold)
JOIN product_variants pv ON pv.sku = s.sku
ON CONFLICT (variant_id) DO NOTHING;

-- ------------------------------------------------------------
-- 6. DELIVERY ZONES  (11 zones from shop-data.ts DELIVERY_ZONES)
-- ------------------------------------------------------------
INSERT INTO delivery_zones (name, slug, fee_etb, estimated_days, is_active, sort_order) VALUES
  ('Bole',               'bole',          150, '1-2 days', TRUE, 1),
  ('Kirkos',             'kirkos',        130, '1-2 days', TRUE, 2),
  ('Arada',              'arada',         130, '1-2 days', TRUE, 3),
  ('Addis Ketema',       'addis-ketema',  140, '1-2 days', TRUE, 4),
  ('Yeka',               'yeka',          160, '2-3 days', TRUE, 5),
  ('Gullele',            'gullele',       150, '2-3 days', TRUE, 6),
  ('Lideta',             'lideta',        140, '1-2 days', TRUE, 7),
  ('Nifas Silk-Lafto',   'nifas-silk',    150, '2-3 days', TRUE, 8),
  ('Kolfe Keranio',      'kolfe',         160, '2-3 days', TRUE, 9),
  ('Akaki Kality',       'akaki',         180, '2-4 days', TRUE, 10),
  ('Outside Addis Ababa','outside',       300, '3-5 days', TRUE, 11)
ON CONFLICT (slug) DO NOTHING;

-- ------------------------------------------------------------
-- 7. ADMIN BOOTSTRAP  (Decision Q3/3a: password from env)
-- If ADMIN_INIT_PASSWORD is unset, this INSERT is a no-op — admin created
-- manually via `make admin` instead.
-- Hash: bcrypt at cost 12, computed at seed time via pgcrypto crypt().
-- ------------------------------------------------------------
DO $$
DECLARE
  v_email    TEXT := COALESCE(current_setting('app.admin_email',    TRUE), 'admin@biniyam.local');
  v_password TEXT := COALESCE(current_setting('app.admin_password', TRUE), '');
BEGIN
  IF v_password = '' THEN
    RAISE NOTICE 'ADMIN_INIT_PASSWORD not set — skipping admin bootstrap. Run `make admin` to create one.';
    RETURN;
  END IF;

  INSERT INTO admin_users (email, password_hash, role, is_active)
  VALUES (v_email, crypt(v_password, gen_salt('bf', 12)), 'admin', TRUE)
  ON CONFLICT (email) DO NOTHING;
END $$;

COMMIT;