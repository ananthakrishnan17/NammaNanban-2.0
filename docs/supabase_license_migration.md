# Supabase Migration: Dual License System

## Overview

This migration adds support for:
- Mobile-number-based license activation
- Two license types: `offline` and `online`
- Device binding per license
- Sync log for tracking cloud sync operations

---

## 1. Update `licenses` Table

Add the following columns to the existing `licenses` table (or run a fresh migration):

```sql
-- Add mobile_number as primary identity (unique, not null)
ALTER TABLE licenses ADD COLUMN mobile_number TEXT UNIQUE;

-- License type: 'offline' or 'online'
ALTER TABLE licenses ADD COLUMN license_type TEXT NOT NULL DEFAULT 'offline';

-- Device binding
ALTER TABLE licenses ADD COLUMN device_id TEXT;

-- Activation timestamp
ALTER TABLE licenses ADD COLUMN activated_at TIMESTAMPTZ;
```

### Full `licenses` table schema (for new Supabase projects):

```sql
CREATE TABLE licenses (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  mobile_number TEXT NOT NULL UNIQUE,
  license_type TEXT NOT NULL DEFAULT 'offline'
    CHECK (license_type IN ('offline', 'online')),
  device_id TEXT,
  activated_at TIMESTAMPTZ,
  expires_at TIMESTAMPTZ NOT NULL,
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),

  -- Legacy fields (keep for backward compatibility)
  license_key TEXT UNIQUE,
  company_name TEXT,
  plan TEXT DEFAULT 'basic',
  max_users INTEGER DEFAULT 2
);

-- Index for fast lookup by mobile number
CREATE INDEX idx_licenses_mobile ON licenses(mobile_number);

-- Row Level Security
ALTER TABLE licenses ENABLE ROW LEVEL SECURITY;

-- Allow reads with valid license key OR mobile number
CREATE POLICY "read_own_license" ON licenses
  FOR SELECT USING (true);  -- Adjust based on your RLS strategy
```

---

## 2. Create `sync_log` Table

Tracks which records have been synced to Supabase (for Online license users):

```sql
CREATE TABLE sync_log (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  license_id UUID NOT NULL REFERENCES licenses(id),
  table_name TEXT NOT NULL,
  record_id TEXT NOT NULL,
  operation TEXT NOT NULL CHECK (operation IN ('create', 'update', 'delete')),
  synced_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(license_id, table_name, record_id)
);

CREATE INDEX idx_sync_log_license ON sync_log(license_id);
```

---

## 3. Bills Sync Table (for Online license)

Online license bills are synced to `bills_sync` (already referenced in `supabase_sync_service.dart`).
Make sure it has a `id` column for upsert:

```sql
CREATE TABLE IF NOT EXISTS bills_sync (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  license_id UUID REFERENCES licenses(id),
  local_bill_id INTEGER,
  bill_number TEXT NOT NULL,
  bill_type TEXT DEFAULT 'retail',
  customer_name TEXT,
  total_amount REAL NOT NULL,
  total_profit REAL DEFAULT 0,
  discount_amount REAL DEFAULT 0,
  gst_total REAL DEFAULT 0,
  payment_mode TEXT DEFAULT 'cash',
  billed_by TEXT,
  items_json JSONB,
  created_at TIMESTAMPTZ NOT NULL,
  synced_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(license_id, bill_number)
);
```

---

## 4. Products Sync Table (for Online license)

```sql
CREATE TABLE IF NOT EXISTS products_sync (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  license_id UUID REFERENCES licenses(id),
  local_product_id INTEGER,
  name TEXT NOT NULL,
  category_name TEXT,
  brand_name TEXT,
  purchase_price REAL DEFAULT 0,
  selling_price REAL NOT NULL,
  wholesale_price REAL DEFAULT 0,
  stock_quantity REAL DEFAULT 0,
  unit TEXT DEFAULT 'piece',
  gst_rate REAL DEFAULT 0,
  is_active BOOLEAN DEFAULT true,
  updated_at TIMESTAMPTZ,
  synced_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(license_id, local_product_id)
);
```

---

## 5. How License Types Affect Data Flow

| Feature            | Offline License                      | Online License                        |
|--------------------|--------------------------------------|---------------------------------------|
| Login              | Supabase (requires internet once)    | Supabase (requires internet once)     |
| License check      | Local cache after first verify       | Local cache after first verify        |
| Bills              | Local SQLite only                    | Local SQLite + queue sync to Supabase |
| Products           | Local SQLite only                    | Local SQLite + sync to Supabase       |
| Sync queue         | Not used                             | Used for offline-first sync           |
| Google Drive backup| Available (manual/scheduled)         | Not primary backup                    |
| Internet required  | Only at initial activation           | Preferred but not required            |

---

## 6. Security Notes

- `mobile_number` is the **primary identity** — one license per number
- License activation binds the device via `device_id`
- No username-only activation allowed
- Supabase Row Level Security (RLS) should restrict license reads to authenticated calls
