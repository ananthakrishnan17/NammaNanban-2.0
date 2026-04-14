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
    return await openDatabase(path, version: 2, onCreate: _createDB, onUpgrade: _upgradeDB,
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
      created_at TEXT NOT NULL, updated_at TEXT NOT NULL,
      FOREIGN KEY (category_id) REFERENCES categories (id),
      FOREIGN KEY (brand_id) REFERENCES brands (id),
      FOREIGN KEY (uom_id) REFERENCES uom_units (id))''');

    await db.execute('''CREATE TABLE bills (id INTEGER PRIMARY KEY AUTOINCREMENT,
      bill_number TEXT NOT NULL UNIQUE, bill_type TEXT DEFAULT 'retail',
      customer_id INTEGER, customer_name TEXT, customer_address TEXT, customer_gstin TEXT,
      total_amount REAL NOT NULL, total_profit REAL NOT NULL DEFAULT 0.0,
      discount_amount REAL DEFAULT 0.0, gst_total REAL DEFAULT 0.0,
      cgst_total REAL DEFAULT 0.0, sgst_total REAL DEFAULT 0.0, igst_total REAL DEFAULT 0.0,
      payment_mode TEXT DEFAULT 'cash', notes TEXT, created_at TEXT NOT NULL,
      FOREIGN KEY (customer_id) REFERENCES customers (id))''');

    await db.execute('''CREATE TABLE bill_items (id INTEGER PRIMARY KEY AUTOINCREMENT,
      bill_id INTEGER NOT NULL, product_id INTEGER NOT NULL, product_name TEXT NOT NULL,
      quantity REAL NOT NULL, unit TEXT NOT NULL, unit_price REAL NOT NULL,
      purchase_price REAL NOT NULL DEFAULT 0.0, discount_amount REAL DEFAULT 0.0,
      gst_rate REAL DEFAULT 0.0, gst_amount REAL DEFAULT 0.0, total_price REAL NOT NULL,
      FOREIGN KEY (bill_id) REFERENCES bills (id) ON DELETE CASCADE,
      FOREIGN KEY (product_id) REFERENCES products (id))''');

    await db.execute('''CREATE TABLE held_bills (id INTEGER PRIMARY KEY AUTOINCREMENT,
      hold_name TEXT, bill_type TEXT DEFAULT 'retail', customer_id INTEGER,
      customer_name TEXT, discount_amount REAL DEFAULT 0.0,
      payment_mode TEXT DEFAULT 'cash', created_at TEXT NOT NULL)''');

    await db.execute('''CREATE TABLE held_bill_items (id INTEGER PRIMARY KEY AUTOINCREMENT,
      held_bill_id INTEGER NOT NULL, product_id INTEGER NOT NULL, product_name TEXT NOT NULL,
      quantity REAL NOT NULL, unit TEXT NOT NULL, unit_price REAL NOT NULL,
      purchase_price REAL DEFAULT 0.0, gst_rate REAL DEFAULT 0.0, total_price REAL NOT NULL,
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
      date TEXT NOT NULL, created_at TEXT NOT NULL)''');

    await db.execute('''CREATE TABLE stock_adjustments (id INTEGER PRIMARY KEY AUTOINCREMENT,
      product_id INTEGER NOT NULL, adjustment_type TEXT NOT NULL, quantity REAL NOT NULL,
      reason TEXT, created_at TEXT NOT NULL,
      FOREIGN KEY (product_id) REFERENCES products (id))''');

    await _seed(db, now);
  }

  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      final cmds = [
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
      for (final cmd in cmds) { try { await db.execute(cmd); } catch (_) {} }
      // Create all new tables
      await _createDB(db, newVersion);
    }
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

  Future<void> close() async { final db = await instance.database; db.close(); _database = null; }
}