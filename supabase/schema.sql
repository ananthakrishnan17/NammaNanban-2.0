-- ============================================================
-- NammaNanban 2.0 — Supabase PostgreSQL Schema
-- Apply this in your Supabase SQL editor (Database → SQL Editor)
-- ============================================================

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ─────────────────────────────────────────────────────────────
-- 1. licenses
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
-- 2. shop_users
-- ─────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS shop_users (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  license_id      UUID NOT NULL REFERENCES licenses (id) ON DELETE CASCADE,
  username        TEXT NOT NULL,
  pin_hash        TEXT NOT NULL,
  role            TEXT NOT NULL CHECK (role IN ('admin', 'user')),
  -- granular permissions
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

-- Trigger: enforce max_users per license on INSERT
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
-- 3. bills_sync
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
-- 4. products_sync
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
-- 5. expenses_sync
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
-- 6. purchases_sync
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
-- 7. subscriptions
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

-- ─────────────────────────────────────────────────────────────
-- Row Level Security
-- NOTE: The policies below are permissive for anon access to
-- allow the mobile app to operate without user-level JWT auth.
-- In production, replace anon policies with JWT-based policies
-- that verify license_id from the JWT claims.
-- ─────────────────────────────────────────────────────────────

ALTER TABLE licenses      ENABLE ROW LEVEL SECURITY;
ALTER TABLE shop_users    ENABLE ROW LEVEL SECURITY;
ALTER TABLE bills_sync    ENABLE ROW LEVEL SECURITY;
ALTER TABLE products_sync ENABLE ROW LEVEL SECURITY;
ALTER TABLE expenses_sync ENABLE ROW LEVEL SECURITY;
ALTER TABLE purchases_sync ENABLE ROW LEVEL SECURITY;
ALTER TABLE subscriptions ENABLE ROW LEVEL SECURITY;

-- licenses
CREATE POLICY "anon_all_licenses"      ON licenses      FOR ALL TO anon USING (true) WITH CHECK (true);
-- shop_users
CREATE POLICY "anon_all_shop_users"    ON shop_users    FOR ALL TO anon USING (true) WITH CHECK (true);
-- bills_sync
CREATE POLICY "anon_all_bills_sync"    ON bills_sync    FOR ALL TO anon USING (true) WITH CHECK (true);
-- products_sync
CREATE POLICY "anon_all_products_sync" ON products_sync FOR ALL TO anon USING (true) WITH CHECK (true);
-- expenses_sync
CREATE POLICY "anon_all_expenses_sync" ON expenses_sync FOR ALL TO anon USING (true) WITH CHECK (true);
-- purchases_sync
CREATE POLICY "anon_all_purchases_sync" ON purchases_sync FOR ALL TO anon USING (true) WITH CHECK (true);
-- subscriptions
CREATE POLICY "anon_all_subscriptions" ON subscriptions FOR ALL TO anon USING (true) WITH CHECK (true);
