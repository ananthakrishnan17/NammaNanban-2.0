import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

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
    return await openDatabase(path, version: 10,
        onCreate: _createDB, onUpgrade: _upgradeDB,
        onConfigure: (db) async => await db.execute('PRAGMA foreign_keys = ON'));
  }

  Future<void> _createDB(Database db, int version) async {
    final now = DateTime.now().toIso8601String();

    await db.execute('''CREATE TABLE shop_settings (id INTEGER PRIMARY KEY AUTOINCREMENT,
      shop_name TEXT NOT NULL, address TEXT, phone TEXT, logo_path TEXT,
      currency TEXT DEFAULT 'Rs.', tax_enabled INTEGER DEFAULT 0, tax_rate REAL DEFAULT 0.0,
      thank_you_msg TEXT DEFAULT 'Thank you!', default_bill_type TEXT DEFAULT 'retail',
      app_language TEXT DEFAULT 'en')''');

    await db.execute('''CREATE TABLE categories (id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL UNIQUE, icon TEXT, color TEXT, created_at TEXT NOT NULL)''');

    await db.execute('''CREATE TABLE brands (id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL UNIQUE, description TEXT, created_at TEXT NOT NULL)''');

    await db.execute('''CREATE TABLE uom_units (id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL UNIQUE, short_name TEXT NOT NULL, uom_type TEXT DEFAULT 'count',
      created_at TEXT NOT NULL)''');

    await db.execute('''CREATE TABLE customers (id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL, phone TEXT, address TEXT, gst_number TEXT,
      credit_limit REAL DEFAULT 0.0, outstanding_balance REAL DEFAULT 0.0,
      is_active INTEGER DEFAULT 1, created_at TEXT NOT NULL, updated_at TEXT NOT NULL)''');

    await db.execute('''CREATE TABLE suppliers (id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL, phone TEXT, address TEXT, gst_number TEXT,
      outstanding_balance REAL DEFAULT 0.0, is_active INTEGER DEFAULT 1,
      created_at TEXT NOT NULL, updated_at TEXT NOT NULL)''');

    await db.execute('''CREATE TABLE products (id INTEGER PRIMARY KEY AUTOINCREMENT,
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
      created_at TEXT NOT NULL, updated_at TEXT NOT NULL,
      FOREIGN KEY (category_id) REFERENCES categories (id),
      FOREIGN KEY (brand_id) REFERENCES brands (id),
      FOREIGN KEY (uom_id) REFERENCES uom_units (id))''');

    // ── product_uoms: Multiple UOM per product (NEW v3) ─────────────────────
    await db.execute('''CREATE TABLE product_uoms (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      product_id INTEGER NOT NULL,
      uom_id INTEGER NOT NULL,
      uom_name TEXT NOT NULL,
      uom_short_name TEXT NOT NULL,
      conversion_qty REAL NOT NULL DEFAULT 1.0,
      selling_price REAL NOT NULL,
      wholesale_price REAL DEFAULT 0.0,
      purchase_price REAL DEFAULT 0.0,
      is_default INTEGER DEFAULT 0,
      FOREIGN KEY (product_id) REFERENCES products (id) ON DELETE CASCADE,
      FOREIGN KEY (uom_id) REFERENCES uom_units (id))''');

    // ── app_users: Admin/User roles (NEW v3) ─────────────────────────────────
    await db.execute('''CREATE TABLE app_users (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      username TEXT NOT NULL UNIQUE,
      pin TEXT NOT NULL,
      role TEXT NOT NULL DEFAULT 'user',
      can_bill INTEGER DEFAULT 1,
      can_view_reports INTEGER DEFAULT 0,
      can_manage_products INTEGER DEFAULT 0,
      can_manage_masters INTEGER DEFAULT 0,
      can_view_expenses INTEGER DEFAULT 0,
      can_manage_purchase INTEGER DEFAULT 0,
      can_view_dashboard INTEGER DEFAULT 1,
      is_active INTEGER DEFAULT 1,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL)''');

    await db.execute('''CREATE TABLE bills (id INTEGER PRIMARY KEY AUTOINCREMENT,
      bill_number TEXT NOT NULL UNIQUE, bill_type TEXT DEFAULT 'retail',
      customer_id INTEGER, customer_name TEXT, customer_address TEXT, customer_gstin TEXT,
      total_amount REAL NOT NULL, total_profit REAL NOT NULL DEFAULT 0.0,
      discount_amount REAL DEFAULT 0.0, gst_total REAL DEFAULT 0.0,
      cgst_total REAL DEFAULT 0.0, sgst_total REAL DEFAULT 0.0, igst_total REAL DEFAULT 0.0,
      payment_mode TEXT DEFAULT 'cash', split_payment_summary TEXT, billed_by_user_id INTEGER, notes TEXT,
      status TEXT DEFAULT 'active', is_modified INTEGER DEFAULT 0, modification_note TEXT,
      created_at TEXT NOT NULL, FOREIGN KEY (customer_id) REFERENCES customers (id))''');

    await db.execute('''CREATE TABLE bill_payment_splits (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      bill_id INTEGER NOT NULL,
      payment_mode TEXT NOT NULL,
      amount REAL NOT NULL,
      FOREIGN KEY (bill_id) REFERENCES bills (id) ON DELETE CASCADE)''');

    await db.execute('''CREATE TABLE bill_items (id INTEGER PRIMARY KEY AUTOINCREMENT,
      bill_id INTEGER NOT NULL, product_id INTEGER NOT NULL, product_name TEXT NOT NULL,
      quantity REAL NOT NULL, unit TEXT NOT NULL, unit_price REAL NOT NULL,
      purchase_price REAL NOT NULL DEFAULT 0.0, discount_amount REAL DEFAULT 0.0,
      gst_rate REAL DEFAULT 0.0, gst_amount REAL DEFAULT 0.0, total_price REAL NOT NULL,
      sale_uom_id INTEGER DEFAULT NULL, conversion_qty REAL DEFAULT 1.0,
      sale_type TEXT DEFAULT 'retail',
      FOREIGN KEY (bill_id) REFERENCES bills (id) ON DELETE CASCADE,
      FOREIGN KEY (product_id) REFERENCES products (id))''');

    await db.execute('''CREATE TABLE held_bills (id INTEGER PRIMARY KEY AUTOINCREMENT,
      hold_name TEXT, bill_type TEXT DEFAULT 'retail', customer_id INTEGER,
      customer_name TEXT, discount_amount REAL DEFAULT 0.0,
      payment_mode TEXT DEFAULT 'cash', created_at TEXT NOT NULL)''');

    await db.execute('''CREATE TABLE held_bill_items (id INTEGER PRIMARY KEY AUTOINCREMENT,
      held_bill_id INTEGER NOT NULL, product_id INTEGER NOT NULL, product_name TEXT NOT NULL,
      quantity REAL NOT NULL, unit TEXT NOT NULL, unit_price REAL NOT NULL,
      purchase_price REAL DEFAULT 0.0, gst_rate REAL DEFAULT 0.0,
      gst_inclusive INTEGER DEFAULT 1, total_price REAL NOT NULL,
      FOREIGN KEY (held_bill_id) REFERENCES held_bills (id) ON DELETE CASCADE)''');

    await db.execute('''CREATE TABLE purchases (id INTEGER PRIMARY KEY AUTOINCREMENT,
      purchase_number TEXT NOT NULL UNIQUE, supplier_id INTEGER, supplier_name TEXT,
      total_amount REAL NOT NULL, gst_total REAL DEFAULT 0.0, discount_amount REAL DEFAULT 0.0,
      payment_mode TEXT DEFAULT 'cash', notes TEXT, purchase_date TEXT NOT NULL,
      created_at TEXT NOT NULL, FOREIGN KEY (supplier_id) REFERENCES suppliers (id))''');

    await db.execute('''CREATE TABLE purchase_items (id INTEGER PRIMARY KEY AUTOINCREMENT,
      purchase_id INTEGER NOT NULL, product_id INTEGER NOT NULL, product_name TEXT NOT NULL,
      quantity REAL NOT NULL, unit TEXT NOT NULL, unit_cost REAL NOT NULL,
      gst_rate REAL DEFAULT 0.0, gst_amount REAL DEFAULT 0.0, total_cost REAL NOT NULL,
      FOREIGN KEY (purchase_id) REFERENCES purchases (id) ON DELETE CASCADE)''');

    await db.execute('''CREATE TABLE sale_returns (id INTEGER PRIMARY KEY AUTOINCREMENT,
      return_number TEXT NOT NULL UNIQUE, original_bill_id INTEGER, original_bill_number TEXT,
      return_type TEXT DEFAULT 'return', customer_id INTEGER, customer_name TEXT,
      total_return_amount REAL NOT NULL, refund_mode TEXT DEFAULT 'cash',
      reason TEXT, created_at TEXT NOT NULL)''');

    await db.execute('''CREATE TABLE sale_return_items (id INTEGER PRIMARY KEY AUTOINCREMENT,
      return_id INTEGER NOT NULL, product_id INTEGER NOT NULL, product_name TEXT NOT NULL,
      quantity REAL NOT NULL, unit TEXT NOT NULL, unit_price REAL NOT NULL, total_price REAL NOT NULL,
      FOREIGN KEY (return_id) REFERENCES sale_returns (id) ON DELETE CASCADE)''');

    await db.execute('''CREATE TABLE expenses (id INTEGER PRIMARY KEY AUTOINCREMENT,
      category TEXT NOT NULL, description TEXT, amount REAL NOT NULL,
      date TEXT NOT NULL, created_at TEXT NOT NULL, is_raw_material INTEGER DEFAULT 0)''');

    await db.execute('''CREATE TABLE stock_adjustments (id INTEGER PRIMARY KEY AUTOINCREMENT,
      product_id INTEGER NOT NULL, adjustment_type TEXT NOT NULL, quantity REAL NOT NULL,
      reason TEXT, created_at TEXT NOT NULL,
      FOREIGN KEY (product_id) REFERENCES products (id))''');

    // ── license_cache: Local copy of mobile-number based license ────────────
    await db.execute('''CREATE TABLE license_cache (
      id TEXT PRIMARY KEY,
      mobile_number TEXT NOT NULL,
      license_type TEXT NOT NULL DEFAULT 'offline',
      device_id TEXT,
      activated_at TEXT NOT NULL,
      expires_at TEXT NOT NULL,
      is_active INTEGER DEFAULT 1,
      created_at TEXT NOT NULL)''');

    // ── sync_queue: Pending cloud sync items for Online license ──────────────
    await db.execute('''CREATE TABLE sync_queue (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      table_name TEXT NOT NULL,
      record_id TEXT NOT NULL,
      operation TEXT NOT NULL DEFAULT 'create',
      payload TEXT NOT NULL,
      status TEXT NOT NULL DEFAULT 'pending',
      created_at TEXT NOT NULL,
      retry_count INTEGER DEFAULT 0)''');

    await _seed(db, now);
  }

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
      for (final cmd in v2cmds) { try { await db.execute(cmd); } catch (_) {} }
    }
    if (oldVersion < 3) {
      // product_uoms table
      try {
        await db.execute('''CREATE TABLE IF NOT EXISTS product_uoms (
          id INTEGER PRIMARY KEY AUTOINCREMENT, product_id INTEGER NOT NULL,
          uom_id INTEGER NOT NULL, uom_name TEXT NOT NULL, uom_short_name TEXT NOT NULL,
          conversion_qty REAL NOT NULL DEFAULT 1.0, selling_price REAL NOT NULL,
          wholesale_price REAL DEFAULT 0.0, purchase_price REAL DEFAULT 0.0,
          is_default INTEGER DEFAULT 0,
          FOREIGN KEY (product_id) REFERENCES products (id) ON DELETE CASCADE,
          FOREIGN KEY (uom_id) REFERENCES uom_units (id))''');
      } catch (_) {}
      // app_users table
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
      // billed_by_user_id column to bills
      try { await db.execute('ALTER TABLE bills ADD COLUMN billed_by_user_id INTEGER'); } catch (_) {}
    }
    if (oldVersion < 4) {
      // gst_inclusive column to held_bill_items (preserves correct GST behaviour on restore)
      try { await db.execute('ALTER TABLE held_bill_items ADD COLUMN gst_inclusive INTEGER DEFAULT 1'); } catch (_) {}
    }
    if (oldVersion < 5) {
      // split_payment_summary column to bills
      try { await db.execute('ALTER TABLE bills ADD COLUMN split_payment_summary TEXT'); } catch (_) {}
      // bill_payment_splits table for multi-mode payments
      try {
        await db.execute('''CREATE TABLE IF NOT EXISTS bill_payment_splits (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          bill_id INTEGER NOT NULL,
          payment_mode TEXT NOT NULL,
          amount REAL NOT NULL,
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
          customer_id INTEGER NOT NULL,
          customer_name TEXT NOT NULL,
          points_type TEXT NOT NULL,
          points REAL NOT NULL DEFAULT 0.0,
          balance REAL NOT NULL DEFAULT 0.0,
          reference_id TEXT,
          note TEXT,
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
          id TEXT PRIMARY KEY,
          mobile_number TEXT NOT NULL,
          license_type TEXT NOT NULL DEFAULT 'offline',
          device_id TEXT,
          activated_at TEXT NOT NULL,
          expires_at TEXT NOT NULL,
          is_active INTEGER DEFAULT 1,
          created_at TEXT NOT NULL)''');
      } catch (_) {}
      try {
        await db.execute('''CREATE TABLE IF NOT EXISTS sync_queue (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          table_name TEXT NOT NULL,
          record_id TEXT NOT NULL,
          operation TEXT NOT NULL DEFAULT 'create',
          payload TEXT NOT NULL,
          status TEXT NOT NULL DEFAULT 'pending',
          created_at TEXT NOT NULL,
          retry_count INTEGER DEFAULT 0)''');
      } catch (_) {}
    }
    await _seed(db, now);
  }

  Future<void> _seed(Database db, String now) async {
    for (final c in [
      {'name': 'Beverages', 'icon': '☕', 'color': '#FF6B35'},
      {'name': 'Food', 'icon': '🍱', 'color': '#4CAF50'},
      {'name': 'Snacks', 'icon': '🍪', 'color': '#FF9800'},
      {'name': 'Sweets', 'icon': '🍬', 'color': '#E91E63'},
      {'name': 'Others', 'icon': '📦', 'color': '#9E9E9E'},
    ]) { try { await db.insert('categories', {...c, 'created_at': now}); } catch (_) {} }

    for (final u in [
      {'name': 'Piece', 'short_name': 'Pcs', 'uom_type': 'count'},
      {'name': 'Kilogram', 'short_name': 'Kg', 'uom_type': 'weight'},
      {'name': 'Gram', 'short_name': 'g', 'uom_type': 'weight'},
      {'name': 'Litre', 'short_name': 'L', 'uom_type': 'volume'},
      {'name': 'Millilitre', 'short_name': 'ml', 'uom_type': 'volume'},
      {'name': 'Dozen', 'short_name': 'Doz', 'uom_type': 'count'},
      {'name': 'Pack', 'short_name': 'Pk', 'uom_type': 'count'},
      {'name': 'Box', 'short_name': 'Box', 'uom_type': 'count'},
      {'name': 'Bottle', 'short_name': 'Btl', 'uom_type': 'count'},
      {'name': 'Metre', 'short_name': 'm', 'uom_type': 'length'},
    ]) { try { await db.insert('uom_units', {...u, 'created_at': now}); } catch (_) {} }
  }

  Future<void> close() async {
    final db = await instance.database;
    db.close();
    _database = null;
  }
}