-- ============================================================
-- NammaNanban 2.0 — Supabase PostgreSQL Schema
-- Apply this in your Supabase SQL editor (Database → SQL Editor)
-- ============================================================
-- MIGRATION v11 — Phase 1 ERP Refactor
--   Added:   catalog_items, item_uoms, transactions, ledger_entries
--   Kept:    licenses, shop_users, bills_sync, products_sync,
--            expenses_sync, purchases_sync, subscriptions
--            (legacy tables retained for backward-compatibility
--             during migration; drop them in Phase 4 cutover)
-- ============================================================

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ─────────────────────────────────────────────────────────────
-- 1. licenses  (unchanged)
-- ─────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS licenses (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  license_key     TEXT NOT NULL UNIQUE,
  company_name    TEXT NOT NULL,
  plan            TEXT NOT NULL CHECK (plan IN ('basic', 'standard')),
  max_users       INTEGER NOT NULL DEFAULT 1,
  mobile_number   TEXT NOT NULL,
  license_type    TEXT NOT NULL CHECK (license_type IN ('offline', 'online')),
  device_id       TEXT,
  is_active       BOOLEAN NOT NULL DEFAULT TRUE,
  activated_at    TIMESTAMPTZ,
  expires_at      TIMESTAMPTZ,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_licenses_license_key ON licenses (license_key);
CREATE INDEX IF NOT EXISTS idx_licenses_mobile      ON licenses (mobile_number);

-- ─────────────────────────────────────────────────────────────
-- 2. shop_users  (unchanged)
-- ─────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS shop_users (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  license_id      UUID NOT NULL REFERENCES licenses (id) ON DELETE CASCADE,
  username        TEXT NOT NULL,
  pin_hash        TEXT NOT NULL,
  role            TEXT NOT NULL CHECK (role IN ('admin', 'user')),
  can_view_sales   BOOLEAN NOT NULL DEFAULT FALSE,
  can_add_product  BOOLEAN NOT NULL DEFAULT FALSE,
  can_delete_bill  BOOLEAN NOT NULL DEFAULT FALSE,
  can_add_expense  BOOLEAN NOT NULL DEFAULT FALSE,
  can_view_reports BOOLEAN NOT NULL DEFAULT FALSE,
  is_active        BOOLEAN NOT NULL DEFAULT TRUE,
  created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (license_id, username)
);

CREATE INDEX IF NOT EXISTS idx_shop_users_license ON shop_users (license_id);

CREATE OR REPLACE FUNCTION check_user_limit()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE
  current_count INTEGER;
  max_allowed   INTEGER;
BEGIN
  SELECT COUNT(*) INTO current_count
    FROM shop_users
   WHERE license_id = NEW.license_id AND is_active = TRUE;

  SELECT max_users INTO max_allowed
    FROM licenses
   WHERE id = NEW.license_id;

  IF current_count >= max_allowed THEN
    RAISE EXCEPTION 'User limit reached for this license (max: %)', max_allowed;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_check_user_limit ON shop_users;
CREATE TRIGGER trg_check_user_limit
  BEFORE INSERT ON shop_users
  FOR EACH ROW EXECUTE FUNCTION check_user_limit();

-- ─────────────────────────────────────────────────────────────
-- 3. bills_sync  (LEGACY — retained for migration period)
-- ─────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS bills_sync (
  id                    UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  license_id            UUID NOT NULL REFERENCES licenses (id) ON DELETE CASCADE,
  local_bill_id         BIGINT NOT NULL,
  bill_number           TEXT NOT NULL,
  bill_type             TEXT NOT NULL DEFAULT 'retail',
  customer_name         TEXT,
  customer_address      TEXT,
  customer_gstin        TEXT,
  total_amount          NUMERIC(12, 2) NOT NULL DEFAULT 0,
  total_profit          NUMERIC(12, 2) NOT NULL DEFAULT 0,
  discount_amount       NUMERIC(12, 2) NOT NULL DEFAULT 0,
  gst_total             NUMERIC(12, 2) NOT NULL DEFAULT 0,
  payment_mode          TEXT NOT NULL DEFAULT 'cash',
  split_payment_summary TEXT,
  billed_by             TEXT,
  items_json            JSONB NOT NULL DEFAULT '[]',
  status                TEXT NOT NULL DEFAULT 'synced',
  created_at            TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  synced_at             TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (license_id, local_bill_id)
);

CREATE INDEX IF NOT EXISTS idx_bills_sync_license    ON bills_sync (license_id);
CREATE INDEX IF NOT EXISTS idx_bills_sync_created_at ON bills_sync (created_at);

-- ─────────────────────────────────────────────────────────────
-- 4. products_sync  (LEGACY — retained for migration period)
-- ─────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS products_sync (
  id                  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  license_id          UUID NOT NULL REFERENCES licenses (id) ON DELETE CASCADE,
  local_product_id    BIGINT NOT NULL,
  name                TEXT NOT NULL,
  category_name       TEXT,
  brand_name          TEXT,
  purchase_price      NUMERIC(12, 2) NOT NULL DEFAULT 0,
  selling_price       NUMERIC(12, 2) NOT NULL DEFAULT 0,
  wholesale_price     NUMERIC(12, 2) NOT NULL DEFAULT 0,
  stock_quantity      NUMERIC(12, 3) NOT NULL DEFAULT 0,
  unit                TEXT NOT NULL DEFAULT 'piece',
  gst_rate            NUMERIC(5, 2) NOT NULL DEFAULT 0,
  is_active           BOOLEAN NOT NULL DEFAULT TRUE,
  updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  synced_at           TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (license_id, local_product_id)
);

CREATE INDEX IF NOT EXISTS idx_products_sync_license ON products_sync (license_id);
CREATE INDEX IF NOT EXISTS idx_products_sync_name    ON products_sync (license_id, name);

-- ─────────────────────────────────────────────────────────────
-- 5. expenses_sync  (LEGACY — retained for migration period)
-- ─────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS expenses_sync (
  id                UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  license_id        UUID NOT NULL REFERENCES licenses (id) ON DELETE CASCADE,
  local_expense_id  BIGINT NOT NULL,
  category          TEXT,
  description       TEXT,
  amount            NUMERIC(12, 2) NOT NULL DEFAULT 0,
  expense_date      DATE NOT NULL,
  added_by          TEXT,
  created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  synced_at         TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (license_id, local_expense_id)
);

CREATE INDEX IF NOT EXISTS idx_expenses_sync_license ON expenses_sync (license_id);
CREATE INDEX IF NOT EXISTS idx_expenses_sync_date    ON expenses_sync (license_id, expense_date);

-- ─────────────────────────────────────────────────────────────
-- 6. purchases_sync  (LEGACY — retained for migration period)
-- ─────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS purchases_sync (
  id                  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  license_id          UUID NOT NULL REFERENCES licenses (id) ON DELETE CASCADE,
  local_purchase_id   BIGINT NOT NULL,
  supplier_name       TEXT,
  invoice_number      TEXT,
  total_amount        NUMERIC(12, 2) NOT NULL DEFAULT 0,
  purchase_date       DATE NOT NULL,
  items_json          JSONB NOT NULL DEFAULT '[]',
  notes               TEXT,
  created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  synced_at           TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (license_id, local_purchase_id)
);

CREATE INDEX IF NOT EXISTS idx_purchases_sync_license ON purchases_sync (license_id);
CREATE INDEX IF NOT EXISTS idx_purchases_sync_date    ON purchases_sync (license_id, purchase_date);

-- ─────────────────────────────────────────────────────────────
-- 7. subscriptions  (unchanged)
-- ─────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS subscriptions (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  license_id      UUID NOT NULL REFERENCES licenses (id) ON DELETE CASCADE,
  plan            TEXT NOT NULL,
  amount          NUMERIC(10, 2) NOT NULL,
  currency        TEXT NOT NULL DEFAULT 'INR',
  payment_id      TEXT,
  payment_status  TEXT NOT NULL DEFAULT 'pending',
  starts_at       TIMESTAMPTZ,
  ends_at         TIMESTAMPTZ,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_subscriptions_license ON subscriptions (license_id);

-- =============================================================
-- NEW ERP CORE TABLES — v11
-- =============================================================

-- ─────────────────────────────────────────────────────────────
-- 8. catalog_items  (replaces products_sync long-term)
--
--    Design decisions:
--    • item_type drives UI & BLoC behaviour:
--        'physical'         → classic product with stock tracking
--        'service'          → no stock; uses hourly_rate in attributes
--        'composite_recipe' → BOM-based; explodes ingredients on sale
--    • attributes JSONB stores type-specific data without schema changes:
--        BOM:     {"ingredients": [{"item_id": "<uuid>", "qty": 150, "uom": "ml"}]}
--        Service: {"hourly_rate": 500, "min_billing_minutes": 30}
--    • base_uom is the canonical unit; item_uoms holds multipliers.
--    • cloud_id ties local SQLite rows to their Supabase UUID after sync.
-- ─────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS catalog_items (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  license_id      UUID NOT NULL REFERENCES licenses (id) ON DELETE CASCADE,
  name            TEXT NOT NULL,
  item_type       TEXT NOT NULL DEFAULT 'physical'
                    CHECK (item_type IN ('physical', 'service', 'composite_recipe')),
  -- Canonical measurement unit (e.g. 'ml', 'kg', 'hour', 'piece')
  base_uom        TEXT NOT NULL DEFAULT 'piece',
  -- Flexible bag for type-specific metadata (BOM, hourly rate, custom fields)
  attributes      JSONB NOT NULL DEFAULT '{}',
  selling_price   NUMERIC(12, 2) NOT NULL DEFAULT 0,
  purchase_price  NUMERIC(12, 2) NOT NULL DEFAULT 0,
  gst_rate        NUMERIC(5, 2)  NOT NULL DEFAULT 0,
  category_name   TEXT,
  brand_name      TEXT,
  barcode         TEXT,
  hsn_code        TEXT,
  is_active       BOOLEAN NOT NULL DEFAULT TRUE,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_catalog_items_license   ON catalog_items (license_id);
CREATE INDEX IF NOT EXISTS idx_catalog_items_name      ON catalog_items (license_id, name);
CREATE INDEX IF NOT EXISTS idx_catalog_items_type      ON catalog_items (license_id, item_type);
-- GIN index enables fast JSONB queries (BOM ingredient lookup, attribute search)
CREATE INDEX IF NOT EXISTS idx_catalog_items_attrs_gin ON catalog_items USING GIN (attributes);

-- ─────────────────────────────────────────────────────────────
-- 9. item_uoms — UOM conversion multipliers per catalog item
--
--    Design decisions:
--    • multiplier = how many base_uom units this UOM equals.
--      e.g. for Milk (base_uom = ml):
--        Cup    multiplier=150  →  1 cup    = 150 ml
--        Glass  multiplier=200  →  1 glass  = 200 ml
--        Bottle multiplier=500  →  1 bottle = 500 ml
--    • Prices are NEVER stored here — computed at runtime by PricingStrategy:
--        uom_price = (item.selling_price / base_multiplier) × this.multiplier
--    • is_base=true marks the row that mirrors catalog_items.base_uom (multiplier=1).
-- ─────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS item_uoms (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  item_id     UUID NOT NULL REFERENCES catalog_items (id) ON DELETE CASCADE,
  uom_name    TEXT NOT NULL,              -- human label: 'Cup', 'Litre', 'Dozen'
  multiplier  NUMERIC(14, 6) NOT NULL DEFAULT 1,
  is_base     BOOLEAN NOT NULL DEFAULT FALSE,
  UNIQUE (item_id, uom_name)
);

CREATE INDEX IF NOT EXISTS idx_item_uoms_item ON item_uoms (item_id);

-- ─────────────────────────────────────────────────────────────
-- 10. transactions — Generic business event log
--
--    Design decisions:
--    • Replaces bills_sync + expenses_sync + purchases_sync with one table.
--    • type covers every business flow across all verticals.
--    • tags JSONB absorbs all retail-specific nullable columns that would
--      be NULL for non-retail events (customer_name, payment_mode, etc.).
--      Common tag keys: bill_number, customer_name, supplier_name,
--                       payment_mode, notes, billed_by, discount_amount
--    • total_amount is a denormalised summary; ledger_entries is authoritative.
-- ─────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS transactions (
  id            UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  license_id    UUID NOT NULL REFERENCES licenses (id) ON DELETE CASCADE,
  type          TEXT NOT NULL
                  CHECK (type IN (
                    'sale', 'purchase', 'expense', 'waste',
                    'stock_adjustment', 'internal_transfer',
                    'sale_return', 'purchase_return'
                  )),
  total_amount  NUMERIC(14, 2) NOT NULL DEFAULT 0,
  tags          JSONB NOT NULL DEFAULT '{}',
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_transactions_license    ON transactions (license_id);
CREATE INDEX IF NOT EXISTS idx_transactions_type       ON transactions (license_id, type);
CREATE INDEX IF NOT EXISTS idx_transactions_created_at ON transactions (license_id, created_at);
CREATE INDEX IF NOT EXISTS idx_transactions_tags_gin   ON transactions USING GIN (tags);

-- ─────────────────────────────────────────────────────────────
-- 11. ledger_entries — Double-entry bookkeeping
--
--    Design decisions:
--    • Every transaction produces ≥2 entries that balance (debits = credits).
--    • account_type maps to standard P&L / Balance Sheet buckets:
--        income     → revenue lines (Phase 4 P&L grouping)
--        cogs       → cost of goods sold (deducted from inventory value)
--        expense    → operational expenditure
--        inventory  → raw material / finished goods asset
--        asset      → cash, receivable, fixed assets
--        liability  → payable, advance received
--        waste      → spoilage / write-off (feeds margin deduction in Phase 4)
--    • amount is always positive; credit/debit direction is inferred by BLoC
--      from account_type (income/liability = credit; others = debit).
--    • quantity_change (signed, in base_uom units) IS the inventory sub-ledger.
--      Negative = stock outflow (sale, waste), positive = inflow (purchase).
--      No separate stock_movements table needed.
-- ─────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS ledger_entries (
  id                     UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  transaction_id         UUID NOT NULL REFERENCES transactions (id) ON DELETE CASCADE,
  account_type           TEXT NOT NULL
                           CHECK (account_type IN (
                             'income', 'cogs', 'expense',
                             'inventory', 'asset', 'liability', 'waste'
                           )),
  amount                 NUMERIC(14, 2) NOT NULL DEFAULT 0,
  -- NULL for non-inventory entries (e.g. pure cash expense)
  linked_catalog_item_id UUID REFERENCES catalog_items (id) ON DELETE SET NULL,
  -- Signed quantity in base_uom: negative = outflow, positive = inflow
  quantity_change        NUMERIC(14, 6),
  created_at             TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_ledger_transaction   ON ledger_entries (transaction_id);
CREATE INDEX IF NOT EXISTS idx_ledger_account_type  ON ledger_entries (account_type);
CREATE INDEX IF NOT EXISTS idx_ledger_catalog_item  ON ledger_entries (linked_catalog_item_id);
-- Composite index for Phase 4 P&L aggregation
CREATE INDEX IF NOT EXISTS idx_ledger_license_acct  ON ledger_entries (transaction_id, account_type);

-- ─────────────────────────────────────────────────────────────
-- Row Level Security
-- ─────────────────────────────────────────────────────────────
ALTER TABLE licenses        ENABLE ROW LEVEL SECURITY;
ALTER TABLE shop_users      ENABLE ROW LEVEL SECURITY;
ALTER TABLE bills_sync      ENABLE ROW LEVEL SECURITY;
ALTER TABLE products_sync   ENABLE ROW LEVEL SECURITY;
ALTER TABLE expenses_sync   ENABLE ROW LEVEL SECURITY;
ALTER TABLE purchases_sync  ENABLE ROW LEVEL SECURITY;
ALTER TABLE subscriptions   ENABLE ROW LEVEL SECURITY;
ALTER TABLE catalog_items   ENABLE ROW LEVEL SECURITY;
ALTER TABLE item_uoms       ENABLE ROW LEVEL SECURITY;
ALTER TABLE transactions    ENABLE ROW LEVEL SECURITY;
ALTER TABLE ledger_entries  ENABLE ROW LEVEL SECURITY;

-- Legacy tables
CREATE POLICY "anon_all_licenses"       ON licenses       FOR ALL TO anon USING (true) WITH CHECK (true);
CREATE POLICY "anon_all_shop_users"     ON shop_users     FOR ALL TO anon USING (true) WITH CHECK (true);
CREATE POLICY "anon_all_bills_sync"     ON bills_sync     FOR ALL TO anon USING (true) WITH CHECK (true);
CREATE POLICY "anon_all_products_sync"  ON products_sync  FOR ALL TO anon USING (true) WITH CHECK (true);
CREATE POLICY "anon_all_expenses_sync"  ON expenses_sync  FOR ALL TO anon USING (true) WITH CHECK (true);
CREATE POLICY "anon_all_purchases_sync" ON purchases_sync FOR ALL TO anon USING (true) WITH CHECK (true);
CREATE POLICY "anon_all_subscriptions"  ON subscriptions  FOR ALL TO anon USING (true) WITH CHECK (true);

-- New ERP tables
-- NOTE: Replace 'true' USING clause with a JWT-claim check in production:
--   USING ((current_setting('request.jwt.claims', true)::jsonb ->> 'license_id')::uuid = license_id)
CREATE POLICY "anon_all_catalog_items"  ON catalog_items  FOR ALL TO anon USING (true) WITH CHECK (true);
CREATE POLICY "anon_all_item_uoms"      ON item_uoms      FOR ALL TO anon USING (true) WITH CHECK (true);
CREATE POLICY "anon_all_transactions"   ON transactions   FOR ALL TO anon USING (true) WITH CHECK (true);
CREATE POLICY "anon_all_ledger_entries" ON ledger_entries FOR ALL TO anon USING (true) WITH CHECK (true);
