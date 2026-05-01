import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

/// DatabaseHelper — NammaNanban 2.0
///
/// Version history:
///   v1–v10  Legacy retail POS tables (bills, products, expenses, etc.)
///   v11     Phase 1 ERP Refactor:
///   v12     Phase 3 UI Redesign:
///             + catalog_items   (replaces products long-term; supports
///                                physical / service / composite_recipe)
///             + item_uoms       (UOM conversion multipliers per item)
///             + erp_transactions (generic business-event log; replaces
///                                 bills + expenses + purchases)
///             + ledger_entries  (double-entry bookkeeping sub-ledger)
///   v13     unit_role TEXT DEFAULT 'sale' on product_uoms
///   v14     direction TEXT DEFAULT 'debit' on ledger_entries (explicit
///            debit/credit for balance validation & Ledger Dashboard)
///
/// All legacy tables are kept intact so existing devices continue to work
/// during the migration period. They will be dropped in Phase 4 cutover.
class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;
  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('shop_pos.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);
    return await openDatabase(
      path,
      version: 15, // v14: direction on ledger_entries + sale_return_items conversion cols
                   // v15: day_close table for EOD settlement + batches table
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
      onConfigure: (db) async => await db.execute('PRAGMA foreign_keys = ON'),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // onCreate — fresh install
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> _createDB(Database db, int version) async {
    final now = DateTime.now().toIso8601String();
    await _createLegacyTables(db);
    await _createErpTables(db);
    await _seed(db, now);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Legacy tables (v1–v10) — extracted for clarity, logic unchanged
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> _createLegacyTables(Database db) async {
    await db.execute('''CREATE TABLE shop_settings (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      shop_name TEXT NOT NULL, address TEXT, phone TEXT, logo_path TEXT,
      currency TEXT DEFAULT 'Rs.', tax_enabled INTEGER DEFAULT 0,
      tax_rate REAL DEFAULT 0.0, thank_you_msg TEXT DEFAULT 'Thank you!',
      default_bill_type TEXT DEFAULT 'retail', app_language TEXT DEFAULT 'en')''');

    await db.execute('''CREATE TABLE categories (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL UNIQUE, icon TEXT, color TEXT, created_at TEXT NOT NULL)''');

    await db.execute('''CREATE TABLE brands (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL UNIQUE, description TEXT, created_at TEXT NOT NULL)''');

    await db.execute('''CREATE TABLE uom_units (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL UNIQUE, short_name TEXT NOT NULL,
      uom_type TEXT DEFAULT 'count', created_at TEXT NOT NULL)''');

    await db.execute('''CREATE TABLE customers (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL, phone TEXT, address TEXT, gst_number TEXT,
      credit_limit REAL DEFAULT 0.0, outstanding_balance REAL DEFAULT 0.0,
      is_active INTEGER DEFAULT 1, created_at TEXT NOT NULL, updated_at TEXT NOT NULL)''');

    await db.execute('''CREATE TABLE suppliers (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL, phone TEXT, address TEXT, gst_number TEXT,
      outstanding_balance REAL DEFAULT 0.0, is_active INTEGER DEFAULT 1,
      created_at TEXT NOT NULL, updated_at TEXT NOT NULL)''');

    await db.execute('''CREATE TABLE products (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL, category_id INTEGER, brand_id INTEGER,
      purchase_price REAL NOT NULL DEFAULT 0.0, selling_price REAL NOT NULL,
      wholesale_price REAL DEFAULT 0.0, stock_quantity REAL NOT NULL DEFAULT 0.0,
      unit TEXT NOT NULL DEFAULT 'piece', uom_id INTEGER,
      low_stock_threshold REAL DEFAULT 5.0, gst_rate REAL DEFAULT 0.0,
      gst_inclusive INTEGER DEFAULT 1, rate_type TEXT DEFAULT 'fixed',
      barcode TEXT, hsn_code TEXT, is_active INTEGER DEFAULT 1,
      wholesale_unit TEXT DEFAULT 'bag', retail_unit TEXT DEFAULT 'kg',
      wholesale_to_retail_qty REAL DEFAULT 1.0, retail_price REAL DEFAULT 0.0,
      stock_wholesale_qty REAL DEFAULT 0.0, stock_retail_qty REAL DEFAULT 0.0,
      item_type TEXT DEFAULT 'physical', attributes TEXT DEFAULT '{}',
      created_at TEXT NOT NULL, updated_at TEXT NOT NULL,
      FOREIGN KEY (category_id) REFERENCES categories (id),
      FOREIGN KEY (brand_id)    REFERENCES brands (id),
      FOREIGN KEY (uom_id)      REFERENCES uom_units (id))''');

    await db.execute('''CREATE TABLE product_uoms (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      product_id INTEGER NOT NULL, uom_id INTEGER NOT NULL,
      uom_name TEXT NOT NULL, uom_short_name TEXT NOT NULL,
      conversion_qty REAL NOT NULL DEFAULT 1.0, selling_price REAL NOT NULL,
      wholesale_price REAL DEFAULT 0.0, purchase_price REAL DEFAULT 0.0,
      is_default INTEGER DEFAULT 0, unit_role TEXT NOT NULL DEFAULT 'sale',
      FOREIGN KEY (product_id) REFERENCES products (id) ON DELETE CASCADE,
      FOREIGN KEY (uom_id)     REFERENCES uom_units (id))''');

    await db.execute('''CREATE TABLE app_users (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      username TEXT NOT NULL UNIQUE, pin TEXT NOT NULL,
      role TEXT NOT NULL DEFAULT 'user',
      can_bill INTEGER DEFAULT 1, can_view_reports INTEGER DEFAULT 0,
      can_manage_products INTEGER DEFAULT 0, can_manage_masters INTEGER DEFAULT 0,
      can_view_expenses INTEGER DEFAULT 0, can_manage_purchase INTEGER DEFAULT 0,
      can_view_dashboard INTEGER DEFAULT 1, is_active INTEGER DEFAULT 1,
      created_at TEXT NOT NULL, updated_at TEXT NOT NULL)''');

    await db.execute('''CREATE TABLE bills (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      bill_number TEXT NOT NULL UNIQUE, bill_type TEXT DEFAULT 'retail',
      customer_id INTEGER, customer_name TEXT, customer_address TEXT,
      customer_gstin TEXT, total_amount REAL NOT NULL,
      total_profit REAL NOT NULL DEFAULT 0.0, discount_amount REAL DEFAULT 0.0,
      gst_total REAL DEFAULT 0.0, cgst_total REAL DEFAULT 0.0,
      sgst_total REAL DEFAULT 0.0, igst_total REAL DEFAULT 0.0,
      payment_mode TEXT DEFAULT 'cash', split_payment_summary TEXT,
      billed_by_user_id INTEGER, notes TEXT, status TEXT DEFAULT 'active',
      is_modified INTEGER DEFAULT 0, modification_note TEXT, created_at TEXT NOT NULL,
      FOREIGN KEY (customer_id) REFERENCES customers (id))''');

    await db.execute('''CREATE TABLE bill_payment_splits (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      bill_id INTEGER NOT NULL, payment_mode TEXT NOT NULL, amount REAL NOT NULL,
      FOREIGN KEY (bill_id) REFERENCES bills (id) ON DELETE CASCADE)''');

    await db.execute('''CREATE TABLE bill_items (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      bill_id INTEGER NOT NULL, product_id INTEGER NOT NULL,
      product_name TEXT NOT NULL, quantity REAL NOT NULL, unit TEXT NOT NULL,
      unit_price REAL NOT NULL, purchase_price REAL NOT NULL DEFAULT 0.0,
      discount_amount REAL DEFAULT 0.0, gst_rate REAL DEFAULT 0.0,
      gst_amount REAL DEFAULT 0.0, total_price REAL NOT NULL,
      sale_uom_id INTEGER DEFAULT NULL, conversion_qty REAL DEFAULT 1.0,
      sale_type TEXT DEFAULT 'retail',
      FOREIGN KEY (bill_id)    REFERENCES bills (id) ON DELETE CASCADE,
      FOREIGN KEY (product_id) REFERENCES products (id))''');

    await db.execute('''CREATE TABLE held_bills (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      hold_name TEXT, bill_type TEXT DEFAULT 'retail', customer_id INTEGER,
      customer_name TEXT, discount_amount REAL DEFAULT 0.0,
      payment_mode TEXT DEFAULT 'cash', created_at TEXT NOT NULL)''');

    await db.execute('''CREATE TABLE held_bill_items (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      held_bill_id INTEGER NOT NULL, product_id INTEGER NOT NULL,
      product_name TEXT NOT NULL, quantity REAL NOT NULL, unit TEXT NOT NULL,
      unit_price REAL NOT NULL, purchase_price REAL DEFAULT 0.0,
      gst_rate REAL DEFAULT 0.0, gst_inclusive INTEGER DEFAULT 1,
      total_price REAL NOT NULL,
      FOREIGN KEY (held_bill_id) REFERENCES held_bills (id) ON DELETE CASCADE)''');

    await db.execute('''CREATE TABLE purchases (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      purchase_number TEXT NOT NULL UNIQUE, supplier_id INTEGER,
      supplier_name TEXT, total_amount REAL NOT NULL, gst_total REAL DEFAULT 0.0,
      discount_amount REAL DEFAULT 0.0, payment_mode TEXT DEFAULT 'cash',
      notes TEXT, purchase_date TEXT NOT NULL, created_at TEXT NOT NULL,
      FOREIGN KEY (supplier_id) REFERENCES suppliers (id))''');

    await db.execute('''CREATE TABLE purchase_items (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      purchase_id INTEGER NOT NULL, product_id INTEGER NOT NULL,
      product_name TEXT NOT NULL, quantity REAL NOT NULL, unit TEXT NOT NULL,
      unit_cost REAL NOT NULL, gst_rate REAL DEFAULT 0.0,
      gst_amount REAL DEFAULT 0.0, total_cost REAL NOT NULL,
      FOREIGN KEY (purchase_id) REFERENCES purchases (id) ON DELETE CASCADE)''');

    await db.execute('''CREATE TABLE sale_returns (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      return_number TEXT NOT NULL UNIQUE, original_bill_id INTEGER,
      original_bill_number TEXT, return_type TEXT DEFAULT 'return',
      customer_id INTEGER, customer_name TEXT,
      total_return_amount REAL NOT NULL, refund_mode TEXT DEFAULT 'cash',
      reason TEXT, created_at TEXT NOT NULL)''');

    await db.execute('''CREATE TABLE sale_return_items (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      return_id INTEGER NOT NULL, product_id INTEGER NOT NULL,
      product_name TEXT NOT NULL, quantity REAL NOT NULL, unit TEXT NOT NULL,
      unit_price REAL NOT NULL, total_price REAL NOT NULL,
      FOREIGN KEY (return_id)  REFERENCES sale_returns (id) ON DELETE CASCADE)''');

    await db.execute('''CREATE TABLE expenses (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      category TEXT NOT NULL, description TEXT, amount REAL NOT NULL,
      date TEXT NOT NULL, created_at TEXT NOT NULL,
      is_raw_material INTEGER DEFAULT 0)''');

    await db.execute('''CREATE TABLE stock_adjustments (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      product_id INTEGER NOT NULL, adjustment_type TEXT NOT NULL,
      quantity REAL NOT NULL, reason TEXT, created_at TEXT NOT NULL,
      FOREIGN KEY (product_id) REFERENCES products (id))''');

    await db.execute('''CREATE TABLE crm_points_ledger (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      customer_id INTEGER NOT NULL, customer_name TEXT NOT NULL,
      points_type TEXT NOT NULL, points REAL NOT NULL DEFAULT 0.0,
      balance REAL NOT NULL DEFAULT 0.0, reference_id TEXT, note TEXT,
      created_at TEXT NOT NULL,
      FOREIGN KEY (customer_id) REFERENCES customers (id))''');

    await db.execute('''CREATE TABLE license_cache (
      id TEXT PRIMARY KEY, mobile_number TEXT NOT NULL,
      license_type TEXT NOT NULL DEFAULT 'offline', device_id TEXT,
      activated_at TEXT NOT NULL, expires_at TEXT NOT NULL,
      is_active INTEGER DEFAULT 1, created_at TEXT NOT NULL)''');

    await db.execute('''CREATE TABLE sync_queue (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      table_name TEXT NOT NULL, record_id TEXT NOT NULL,
      operation TEXT NOT NULL DEFAULT 'create', payload TEXT NOT NULL,
      status TEXT NOT NULL DEFAULT 'pending', created_at TEXT NOT NULL,
      retry_count INTEGER DEFAULT 0)''');
  }

  // ─────────────────────────────────────────────────────────────────────────
  // ERP tables (v11) — Phase 1 additions
  // ─────────────────────────────────────────────────────────────────────────

  /// Creates the four Phase-1 ERP tables.
  ///
  /// Called from both [_createDB] (fresh install) and [_upgradeDB]
  /// (oldVersion < 11). Every statement is wrapped in try/catch so a
  /// partial upgrade can be retried safely.
  Future<void> _createErpTables(Database db) async {
    // ── catalog_items ──────────────────────────────────────────────────────
    // Replaces the rigid products table with a type-driven catalogue.
    //
    // item_type values:
    //   'physical'         → classic product; has stock_quantity in ledger
    //   'service'          → no stock tracking; BLoC reads hourly_rate from
    //                        attributes JSON for pricing
    //   'composite_recipe' → BOM-based; BLoC explodes attributes.ingredients
    //                        into individual ledger_entries on each sale
    //
    // attributes (TEXT/JSON) stores type-specific data without adding
    // nullable columns. Examples:
    //   physical:          {} or {"low_stock_threshold": 5}
    //   service:           {"hourly_rate": 500, "min_billing_minutes": 30}
    //   composite_recipe:  {"ingredients": [
    //                         {"item_id": 1, "qty": 150.0, "uom": "ml"},
    //                         {"item_id": 2, "qty": 5.0,   "uom": "g"}
    //                       ]}
    //
    // cloud_id stores the Supabase UUID written back after a successful sync
    // via the existing sync_queue worker — zero changes to sync service needed.
    try {
      await db.execute('''CREATE TABLE IF NOT EXISTS catalog_items (
        id             INTEGER PRIMARY KEY AUTOINCREMENT,
        cloud_id       TEXT UNIQUE,
        license_id     TEXT NOT NULL,
        name           TEXT NOT NULL,
        item_type      TEXT NOT NULL DEFAULT 'physical'
                         CHECK (item_type IN ('physical','service','composite_recipe')),
        base_uom       TEXT NOT NULL DEFAULT 'piece',
        attributes     TEXT NOT NULL DEFAULT '{}',
        selling_price  REAL NOT NULL DEFAULT 0.0,
        purchase_price REAL NOT NULL DEFAULT 0.0,
        gst_rate       REAL NOT NULL DEFAULT 0.0,
        category_name  TEXT,
        brand_name     TEXT,
        barcode        TEXT,
        hsn_code       TEXT,
        is_active      INTEGER NOT NULL DEFAULT 1,
        created_at     TEXT NOT NULL,
        updated_at     TEXT NOT NULL)''');
    } catch (_) {}

    // ── item_uoms ──────────────────────────────────────────────────────────
    // One row per sellable / purchasable unit for a catalog item.
    //
    // multiplier = how many base_uom units this UOM equals.
    //   Milk (base_uom='ml'):
    //     Cup    multiplier=150  → 1 cup    = 150 ml
    //     Glass  multiplier=200  → 1 glass  = 200 ml
    //     Bottle multiplier=500  → 1 bottle = 500 ml
    //
    // Prices are NEVER stored here. PricingStrategy computes them at runtime:
    //   uom_price = (catalog_item.selling_price / base_multiplier) × multiplier
    //
    // is_base=1 marks the row corresponding to catalog_items.base_uom
    // (multiplier=1). The BLoC uses this flag to skip conversion.
    try {
      await db.execute('''CREATE TABLE IF NOT EXISTS item_uoms (
        id         INTEGER PRIMARY KEY AUTOINCREMENT,
        item_id    INTEGER NOT NULL REFERENCES catalog_items (id) ON DELETE CASCADE,
        uom_name   TEXT NOT NULL,
        multiplier REAL NOT NULL DEFAULT 1.0,
        is_base    INTEGER NOT NULL DEFAULT 0,
        UNIQUE (item_id, uom_name))''');
    } catch (_) {}

    // ── erp_transactions ───────────────────────────────────────────────────
    // One row per business event. Replaces bills + expenses + purchases with
    // a single domain-agnostic table that works for every vertical.
    //
    // type values:
    //   sale, purchase, expense, waste, stock_adjustment,
    //   internal_transfer, sale_return, purchase_return
    //
    // tags (TEXT/JSON) absorbs all nullable retail-specific columns so the
    // core table stays slim and domain-agnostic. Common tag keys:
    //   bill_number, customer_name, supplier_name, payment_mode, notes,
    //   billed_by, discount_amount, split_payment_summary
    //
    // total_amount is a denormalised fast-read summary; ledger_entries holds
    // the authoritative line-item breakdown.
    try {
      await db.execute('''CREATE TABLE IF NOT EXISTS erp_transactions (
        id           INTEGER PRIMARY KEY AUTOINCREMENT,
        cloud_id     TEXT UNIQUE,
        license_id   TEXT NOT NULL,
        type         TEXT NOT NULL
                       CHECK (type IN (
                         'sale','purchase','expense','waste',
                         'stock_adjustment','internal_transfer',
                         'sale_return','purchase_return'
                       )),
        total_amount REAL NOT NULL DEFAULT 0.0,
        tags         TEXT NOT NULL DEFAULT '{}',
        created_at   TEXT NOT NULL,
        updated_at   TEXT NOT NULL)''');
    } catch (_) {}

    // ── ledger_entries ─────────────────────────────────────────────────────
    // Double-entry bookkeeping. Every erp_transaction produces ≥2 rows that
    // balance (sum of amounts by credit accounts = sum by debit accounts).
    //
    // account_type → P&L / Balance Sheet bucket:
    //   income     credit  Revenue from sales
    //   cogs       debit   Cost of goods sold; paired with inventory credit
    //   expense    debit   Operational expenditure (rent, salary, etc.)
    //   inventory  debit/credit  Raw material / finished goods asset
    //   asset      debit/credit  Cash, receivable, fixed assets
    //   liability  credit  Payable, advance received
    //   waste      debit   Spoilage / write-off (margin deduction in Phase 4)
    //
    // amount is always positive. Credit/debit direction is inferred by BLoC
    // from account_type (income & liability = credit; all others = debit).
    //
    // quantity_change (signed, in base_uom) IS the inventory sub-ledger:
    //   negative = stock outflow (sale / waste / transfer out)
    //   positive = stock inflow  (purchase / return / transfer in)
    // No separate stock_movements table is needed.
    try {
      await db.execute('''CREATE TABLE IF NOT EXISTS ledger_entries (
        id                     INTEGER PRIMARY KEY AUTOINCREMENT,
        transaction_id         INTEGER NOT NULL
                                 REFERENCES erp_transactions (id) ON DELETE CASCADE,
        account_type           TEXT NOT NULL
                                 CHECK (account_type IN (
                                   'income','cogs','expense',
                                   'inventory','asset','liability','waste'
                                 )),
        direction              TEXT NOT NULL DEFAULT 'debit',
        amount                 REAL NOT NULL DEFAULT 0.0,
        linked_catalog_item_id INTEGER REFERENCES catalog_items (id) ON DELETE SET NULL,
        quantity_change        REAL,
        created_at             TEXT NOT NULL)''');
    } catch (_) {}

    // ── day_close ─────────────────────────────────────────────────────────
    try {
      await db.execute('''CREATE TABLE IF NOT EXISTS day_close (
        id               INTEGER PRIMARY KEY AUTOINCREMENT,
        close_date       TEXT NOT NULL UNIQUE,
        cash_opening     REAL NOT NULL DEFAULT 0.0,
        cash_closing     REAL NOT NULL DEFAULT 0.0,
        cash_variance    REAL NOT NULL DEFAULT 0.0,
        total_sales      REAL NOT NULL DEFAULT 0.0,
        total_expenses   REAL NOT NULL DEFAULT 0.0,
        total_returns    REAL NOT NULL DEFAULT 0.0,
        total_purchases  REAL NOT NULL DEFAULT 0.0,
        cash_sales       REAL NOT NULL DEFAULT 0.0,
        digital_sales    REAL NOT NULL DEFAULT 0.0,
        bill_count       INTEGER NOT NULL DEFAULT 0,
        notes            TEXT,
        closed_by        TEXT,
        created_at       TEXT NOT NULL)''');
    } catch (_) {}

    // ── batches ───────────────────────────────────────────────────────────
    try {
      await db.execute('''CREATE TABLE IF NOT EXISTS batches (
        id           INTEGER PRIMARY KEY AUTOINCREMENT,
        product_id   INTEGER NOT NULL REFERENCES products (id) ON DELETE CASCADE,
        purchase_id  INTEGER REFERENCES purchases (id) ON DELETE SET NULL,
        batch_number TEXT,
        expiry_date  TEXT,
        qty_in       REAL NOT NULL DEFAULT 0.0,
        qty_remaining REAL NOT NULL DEFAULT 0.0,
        unit_cost    REAL NOT NULL DEFAULT 0.0,
        created_at   TEXT NOT NULL)''');
    } catch (_) {}
  }

  // ─────────────────────────────────────────────────────────────────────────
  // onUpgrade — incremental migration
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    final now = DateTime.now().toIso8601String();

    if (oldVersion < 2) {
      final v2cmds = [
        'ALTER TABLE shop_settings ADD COLUMN default_bill_type TEXT DEFAULT "retail"',
        'ALTER TABLE shop_settings ADD COLUMN app_language TEXT DEFAULT "en"',
        'ALTER TABLE products ADD COLUMN brand_id INTEGER',
        'ALTER TABLE products ADD COLUMN wholesale_price REAL DEFAULT 0.0',
        'ALTER TABLE products ADD COLUMN uom_id INTEGER',
        'ALTER TABLE products ADD COLUMN gst_rate REAL DEFAULT 0.0',
        'ALTER TABLE products ADD COLUMN gst_inclusive INTEGER DEFAULT 1',
        'ALTER TABLE products ADD COLUMN rate_type TEXT DEFAULT "fixed"',
        'ALTER TABLE products ADD COLUMN hsn_code TEXT',
        'ALTER TABLE bills ADD COLUMN bill_type TEXT DEFAULT "retail"',
        'ALTER TABLE bills ADD COLUMN customer_id INTEGER',
        'ALTER TABLE bills ADD COLUMN customer_address TEXT',
        'ALTER TABLE bills ADD COLUMN customer_gstin TEXT',
        'ALTER TABLE bills ADD COLUMN gst_total REAL DEFAULT 0.0',
        'ALTER TABLE bills ADD COLUMN cgst_total REAL DEFAULT 0.0',
        'ALTER TABLE bills ADD COLUMN sgst_total REAL DEFAULT 0.0',
        'ALTER TABLE bills ADD COLUMN igst_total REAL DEFAULT 0.0',
        'ALTER TABLE bill_items ADD COLUMN discount_amount REAL DEFAULT 0.0',
        'ALTER TABLE bill_items ADD COLUMN gst_rate REAL DEFAULT 0.0',
        'ALTER TABLE bill_items ADD COLUMN gst_amount REAL DEFAULT 0.0',
      ];
      for (final cmd in v2cmds) {
        try { await db.execute(cmd); } catch (_) {}
      }
    }

    if (oldVersion < 3) {
      try {
        await db.execute('''CREATE TABLE IF NOT EXISTS product_uoms (
          id INTEGER PRIMARY KEY AUTOINCREMENT, product_id INTEGER NOT NULL,
          uom_id INTEGER NOT NULL, uom_name TEXT NOT NULL,
          uom_short_name TEXT NOT NULL, conversion_qty REAL NOT NULL DEFAULT 1.0,
          selling_price REAL NOT NULL, wholesale_price REAL DEFAULT 0.0,
          purchase_price REAL DEFAULT 0.0, is_default INTEGER DEFAULT 0,
          FOREIGN KEY (product_id) REFERENCES products (id) ON DELETE CASCADE,
          FOREIGN KEY (uom_id) REFERENCES uom_units (id))''');
      } catch (_) {}
      try {
        await db.execute('''CREATE TABLE IF NOT EXISTS app_users (
          id INTEGER PRIMARY KEY AUTOINCREMENT, username TEXT NOT NULL UNIQUE,
          pin TEXT NOT NULL, role TEXT NOT NULL DEFAULT 'user',
          can_bill INTEGER DEFAULT 1, can_view_reports INTEGER DEFAULT 0,
          can_manage_products INTEGER DEFAULT 0, can_manage_masters INTEGER DEFAULT 0,
          can_view_expenses INTEGER DEFAULT 0, can_manage_purchase INTEGER DEFAULT 0,
          can_view_dashboard INTEGER DEFAULT 1, is_active INTEGER DEFAULT 1,
          created_at TEXT NOT NULL, updated_at TEXT NOT NULL)''');
      } catch (_) {}
      try { await db.execute('ALTER TABLE bills ADD COLUMN billed_by_user_id INTEGER'); } catch (_) {}
    }

    if (oldVersion < 4) {
      try { await db.execute('ALTER TABLE held_bill_items ADD COLUMN gst_inclusive INTEGER DEFAULT 1'); } catch (_) {}
    }

    if (oldVersion < 5) {
      try { await db.execute('ALTER TABLE bills ADD COLUMN split_payment_summary TEXT'); } catch (_) {}
      try {
        await db.execute('''CREATE TABLE IF NOT EXISTS bill_payment_splits (
          id INTEGER PRIMARY KEY AUTOINCREMENT, bill_id INTEGER NOT NULL,
          payment_mode TEXT NOT NULL, amount REAL NOT NULL,
          FOREIGN KEY (bill_id) REFERENCES bills (id) ON DELETE CASCADE)''');
      } catch (_) {}
    }

    if (oldVersion < 6) {
      try { await db.execute('ALTER TABLE bill_items ADD COLUMN sale_uom_id INTEGER DEFAULT NULL'); } catch (_) {}
      try { await db.execute('ALTER TABLE bill_items ADD COLUMN conversion_qty REAL DEFAULT 1.0'); } catch (_) {}
    }

    if (oldVersion < 7) {
      try { await db.execute("ALTER TABLE bills ADD COLUMN status TEXT DEFAULT 'active'"); } catch (_) {}
      try { await db.execute('ALTER TABLE bills ADD COLUMN is_modified INTEGER DEFAULT 0'); } catch (_) {}
      try { await db.execute('ALTER TABLE bills ADD COLUMN modification_note TEXT'); } catch (_) {}
      try {
        await db.execute('''CREATE TABLE IF NOT EXISTS crm_points_ledger (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          customer_id INTEGER NOT NULL, customer_name TEXT NOT NULL,
          points_type TEXT NOT NULL, points REAL NOT NULL DEFAULT 0.0,
          balance REAL NOT NULL DEFAULT 0.0, reference_id TEXT, note TEXT,
          created_at TEXT NOT NULL,
          FOREIGN KEY (customer_id) REFERENCES customers (id))''');
      } catch (_) {}
    }

    if (oldVersion < 8) {
      try { await db.execute('ALTER TABLE expenses ADD COLUMN is_raw_material INTEGER DEFAULT 0'); } catch (_) {}
    }

    if (oldVersion < 9) {
      try { await db.execute("ALTER TABLE products ADD COLUMN wholesale_unit TEXT DEFAULT 'bag'"); } catch (_) {}
      try { await db.execute("ALTER TABLE products ADD COLUMN retail_unit TEXT DEFAULT 'kg'"); } catch (_) {}
      try { await db.execute('ALTER TABLE products ADD COLUMN wholesale_to_retail_qty REAL DEFAULT 1.0'); } catch (_) {}
      try { await db.execute('ALTER TABLE products ADD COLUMN retail_price REAL DEFAULT 0.0'); } catch (_) {}
      try { await db.execute('ALTER TABLE products ADD COLUMN stock_wholesale_qty REAL DEFAULT 0.0'); } catch (_) {}
      try { await db.execute('ALTER TABLE products ADD COLUMN stock_retail_qty REAL DEFAULT 0.0'); } catch (_) {}
      try { await db.execute("ALTER TABLE bill_items ADD COLUMN sale_type TEXT DEFAULT 'retail'"); } catch (_) {}
    }

    if (oldVersion < 10) {
      try {
        await db.execute('''CREATE TABLE IF NOT EXISTS license_cache (
          id TEXT PRIMARY KEY, mobile_number TEXT NOT NULL,
          license_type TEXT NOT NULL DEFAULT 'offline', device_id TEXT,
          activated_at TEXT NOT NULL, expires_at TEXT NOT NULL,
          is_active INTEGER DEFAULT 1, created_at TEXT NOT NULL)''');
      } catch (_) {}
      try {
        await db.execute('''CREATE TABLE IF NOT EXISTS sync_queue (
          id INTEGER PRIMARY KEY AUTOINCREMENT, table_name TEXT NOT NULL,
          record_id TEXT NOT NULL, operation TEXT NOT NULL DEFAULT 'create',
          payload TEXT NOT NULL, status TEXT NOT NULL DEFAULT 'pending',
          created_at TEXT NOT NULL, retry_count INTEGER DEFAULT 0)''');
      } catch (_) {}
    }

    // ── v11 — Phase 1 ERP tables ───────────────────────────────────────────
    if (oldVersion < 11) {
      await _createErpTables(db);
    }

    // ── v12 — Phase 3: item_type + attributes on products ─────────────────
    if (oldVersion < 12) {
      try { await db.execute("ALTER TABLE products ADD COLUMN item_type TEXT DEFAULT 'physical'"); } catch (_) {}
      try { await db.execute("ALTER TABLE products ADD COLUMN attributes TEXT DEFAULT '{}'"); } catch (_) {}
    }

    // ── v13 — Base Inventory Unit: unit_role on product_uoms ──────────────
    // 'sale' (default) = sold to customer; 'purchase' = bought from supplier.
    // Existing rows keep DEFAULT 'sale' so billing is unaffected.
    if (oldVersion < 13) {
      try { await db.execute("ALTER TABLE product_uoms ADD COLUMN unit_role TEXT NOT NULL DEFAULT 'sale'"); } catch (_) {}
    }

    // ── v14 — Ledger direction + sale_return_items conversion columns ──────
    if (oldVersion < 14) {
      // Add direction to ledger_entries (debit by default)
      try { await db.execute("ALTER TABLE ledger_entries ADD COLUMN direction TEXT NOT NULL DEFAULT 'debit'"); } catch (_) {}
      // Add conversion info to sale_return_items for full audit trail
      try { await db.execute("ALTER TABLE sale_return_items ADD COLUMN sale_type TEXT DEFAULT 'retail'"); } catch (_) {}
      try { await db.execute("ALTER TABLE sale_return_items ADD COLUMN conversion_qty REAL DEFAULT 1.0"); } catch (_) {}
      try { await db.execute("ALTER TABLE sale_return_items ADD COLUMN wholesale_to_retail_qty REAL DEFAULT 1.0"); } catch (_) {}
      try { await db.execute("ALTER TABLE sale_return_items ADD COLUMN base_qty_restored REAL DEFAULT 0.0"); } catch (_) {}
      // Create ERP tables if not yet created (users upgrading from < v11)
      await _createErpTables(db);
    }

    // ── v15 — Day close + batches tables ───────────────────────────────────
    if (oldVersion < 15) {
      try {
        await db.execute('''CREATE TABLE IF NOT EXISTS day_close (
          id               INTEGER PRIMARY KEY AUTOINCREMENT,
          close_date       TEXT NOT NULL UNIQUE,
          cash_opening     REAL NOT NULL DEFAULT 0.0,
          cash_closing     REAL NOT NULL DEFAULT 0.0,
          cash_variance    REAL NOT NULL DEFAULT 0.0,
          total_sales      REAL NOT NULL DEFAULT 0.0,
          total_expenses   REAL NOT NULL DEFAULT 0.0,
          total_returns    REAL NOT NULL DEFAULT 0.0,
          total_purchases  REAL NOT NULL DEFAULT 0.0,
          cash_sales       REAL NOT NULL DEFAULT 0.0,
          digital_sales    REAL NOT NULL DEFAULT 0.0,
          bill_count       INTEGER NOT NULL DEFAULT 0,
          notes            TEXT,
          closed_by        TEXT,
          created_at       TEXT NOT NULL)''');
      } catch (_) {}
      try {
        await db.execute('''CREATE TABLE IF NOT EXISTS batches (
          id            INTEGER PRIMARY KEY AUTOINCREMENT,
          product_id    INTEGER NOT NULL REFERENCES products (id) ON DELETE CASCADE,
          purchase_id   INTEGER REFERENCES purchases (id) ON DELETE SET NULL,
          batch_number  TEXT,
          expiry_date   TEXT,
          qty_in        REAL NOT NULL DEFAULT 0.0,
          qty_remaining REAL NOT NULL DEFAULT 0.0,
          unit_cost     REAL NOT NULL DEFAULT 0.0,
          created_at    TEXT NOT NULL)''');
      } catch (_) {}
    }

    await _seed(db, now);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Seed data
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> _seed(Database db, String now) async {
    for (final c in [
      {'name': 'Beverages', 'icon': '☕', 'color': '#FF6B35'},
      {'name': 'Food',      'icon': '🍱', 'color': '#4CAF50'},
      {'name': 'Snacks',    'icon': '🍪', 'color': '#FF9800'},
      {'name': 'Sweets',    'icon': '🍬', 'color': '#E91E63'},
      {'name': 'Others',    'icon': '📦', 'color': '#9E9E9E'},
    ]) {
      try { await db.insert('categories', {...c, 'created_at': now}); } catch (_) {}
    }

    for (final u in [
      {'name': 'Piece',      'short_name': 'Pcs', 'uom_type': 'count'},
      {'name': 'Kilogram',   'short_name': 'Kg',  'uom_type': 'weight'},
      {'name': 'Gram',       'short_name': 'g',   'uom_type': 'weight'},
      {'name': 'Litre',      'short_name': 'L',   'uom_type': 'volume'},
      {'name': 'Millilitre', 'short_name': 'ml',  'uom_type': 'volume'},
      {'name': 'Dozen',      'short_name': 'Doz', 'uom_type': 'count'},
      {'name': 'Pack',       'short_name': 'Pk',  'uom_type': 'count'},
      {'name': 'Box',        'short_name': 'Box', 'uom_type': 'count'},
      {'name': 'Bottle',     'short_name': 'Btl', 'uom_type': 'count'},
      {'name': 'Metre',      'short_name': 'm',   'uom_type': 'length'},
    ]) {
      try { await db.insert('uom_units', {...u, 'created_at': now}); } catch (_) {}
    }
  }

  Future<void> close() async {
    final db = await instance.database;
    db.close();
    _database = null;
  }
}
