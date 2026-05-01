import 'dart:convert';

import 'package:sqflite/sqflite.dart' show ConflictAlgorithm;

import '../../../../core/database/database_helper.dart';
import '../../../billing/domain/entities/bill.dart';

class ReportRepository {
  final DatabaseHelper _db;
  ReportRepository(this._db);

  // ── Modified Bills ──────────────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getModifiedBills(
      {DateTime? from, DateTime? to}) async {
    final db = await _db.database;
    final f = from ?? DateTime(2020);
    final t = to ?? DateTime.now();
    return db.rawQuery(
      "SELECT * FROM bills WHERE is_modified=1 AND created_at BETWEEN ? AND ? ORDER BY created_at DESC",
      [f.toIso8601String(), t.toIso8601String()],
    );
  }

  // ── Cancelled Bills ─────────────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getCancelledBills(
      {DateTime? from, DateTime? to}) async {
    final db = await _db.database;
    final f = from ?? DateTime(2020);
    final t = to ?? DateTime.now();
    return db.rawQuery(
      "SELECT * FROM bills WHERE status='cancelled' AND created_at BETWEEN ? AND ? ORDER BY created_at DESC",
      [f.toIso8601String(), t.toIso8601String()],
    );
  }

  // ── Fast/Slow/Non-Moving Products ───────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getProductMovementReport(int days) async {
    final db = await _db.database;
    final since =
        DateTime.now().subtract(Duration(days: days)).toIso8601String();
    return db.rawQuery('''
      SELECT p.id as product_id, p.name as product_name,
        COALESCE(SUM(bi.quantity), 0) as total_qty_sold,
        COALESCE(SUM(bi.total_price), 0) as total_revenue,
        CASE
          WHEN COALESCE(SUM(bi.quantity), 0) > 10 THEN 'fast'
          WHEN COALESCE(SUM(bi.quantity), 0) > 0 THEN 'slow'
          ELSE 'non-moving'
        END as movement_type
      FROM products p
      LEFT JOIN bill_items bi ON bi.product_id = p.id
        AND bi.bill_id IN (SELECT id FROM bills WHERE created_at >= ?)
      WHERE p.is_active = 1
      GROUP BY p.id, p.name
      ORDER BY total_qty_sold DESC
    ''', [since]);
  }

  // ── Sales by Bill ───────────────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getSalesByBill(
      {required DateTime from, required DateTime to}) async {
    final db = await _db.database;
    return db.rawQuery('''
      SELECT b.*,
        GROUP_CONCAT(bi.product_name || ' x' || bi.quantity, ', ') as items_summary,
        COUNT(bi.id) as item_count
      FROM bills b
      LEFT JOIN bill_items bi ON bi.bill_id = b.id
      WHERE b.created_at BETWEEN ? AND ? AND (b.status IS NULL OR b.status != 'cancelled')
      GROUP BY b.id
      ORDER BY b.created_at DESC
    ''', [from.toIso8601String(), to.toIso8601String()]);
  }

  // ── Sales by Item ───────────────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getSalesByItem(
      {required DateTime from, required DateTime to}) async {
    final db = await _db.database;
    return db.rawQuery('''
      SELECT bi.product_name,
        SUM(bi.quantity) as total_qty,
        SUM(bi.total_price) as total_revenue,
        SUM((bi.unit_price - bi.purchase_price) * bi.quantity) as total_profit,
        COUNT(DISTINCT bi.bill_id) as bill_count
      FROM bill_items bi
      JOIN bills b ON b.id = bi.bill_id
      WHERE b.created_at BETWEEN ? AND ? AND (b.status IS NULL OR b.status != 'cancelled')
      GROUP BY bi.product_name
      ORDER BY total_revenue DESC
    ''', [from.toIso8601String(), to.toIso8601String()]);
  }

  // ── Day-wise Profit ─────────────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getDaywiseProfitReport(
      {required DateTime from, required DateTime to}) async {
    final db = await _db.database;
    final bills = await db.rawQuery('''
      SELECT DATE(created_at) as day,
        SUM(total_amount) as total_sales,
        SUM(total_profit) as total_profit,
        COUNT(*) as bill_count
      FROM bills
      WHERE created_at BETWEEN ? AND ? AND (status IS NULL OR status != 'cancelled')
      GROUP BY DATE(created_at)
      ORDER BY day ASC
    ''', [from.toIso8601String(), to.toIso8601String()]);

    final expenses = await db.rawQuery('''
      SELECT date as day, SUM(amount) as total_expenses
      FROM expenses
      WHERE date BETWEEN ? AND ?
      GROUP BY date
    ''', [from.toIso8601String().substring(0, 10), to.toIso8601String().substring(0, 10)]);

    final expMap = {for (final e in expenses) e['day'] as String: (e['total_expenses'] as num).toDouble()};
    return bills.map((b) {
      final day = b['day'] as String;
      final exp = expMap[day] ?? 0.0;
      return {...b, 'total_expenses': exp, 'net_profit': (b['total_profit'] as num).toDouble() - exp};
    }).toList();
  }

  // ── Total Bill Count (all-time, non-cancelled) ──────────────────────────────
  Future<int> getTotalBillCount() async {
    final db = await _db.database;
    final result = await db.rawQuery(
        "SELECT COUNT(*) as cnt FROM bills WHERE status IS NULL OR status != 'cancelled'");
    return (result.first['cnt'] as int? ?? 0);
  }

  // ── GST Report ──────────────────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getGstReport(
      {required DateTime from, required DateTime to}) async {
    final db = await _db.database;
    return db.rawQuery('''
      SELECT
        b.id as bill_id,
        b.bill_number,
        b.bill_type,
        b.customer_name,
        b.customer_gstin,
        b.created_at,
        b.total_amount,
        b.discount_amount,
        b.gst_total,
        b.cgst_total,
        b.sgst_total,
        b.payment_mode,
        bi.product_name,
        bi.quantity,
        bi.unit,
        bi.unit_price,
        bi.gst_rate,
        bi.gst_amount,
        bi.total_price
      FROM bills b
      JOIN bill_items bi ON bi.bill_id = b.id
      WHERE b.created_at BETWEEN ? AND ?
        AND (b.status IS NULL OR b.status != 'cancelled')
      ORDER BY b.created_at DESC, b.id, bi.id
    ''', [from.toIso8601String(), to.toIso8601String()]);
  }

  // ── Bill-wise Report ────────────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getBillwiseReport(
      {required DateTime from, required DateTime to}) async {
    final db = await _db.database;
    return db.rawQuery('''
      SELECT b.*,
        GROUP_CONCAT(bi.product_name || ' x' || bi.quantity, ', ') as items_summary,
        COUNT(bi.id) as item_count
      FROM bills b
      LEFT JOIN bill_items bi ON bi.bill_id = b.id
      WHERE b.created_at BETWEEN ? AND ? AND (b.status IS NULL OR b.status != 'cancelled')
      GROUP BY b.id
      ORDER BY b.created_at DESC
    ''', [from.toIso8601String(), to.toIso8601String()]);
  }

  // ── Get Bill By ID ──────────────────────────────────────────────────────────
  Future<Bill> getBillById(int id) async {
    final db = await _db.database;
    final rows = await db.query('bills', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) throw Exception('Bill #$id not found');
    final map = rows.first;
    final itemRows = await db.query('bill_items', where: 'bill_id = ?', whereArgs: [id]);
    final items = itemRows.map((r) => BillItem(
      id: r['id'] as int?,
      billId: id,
      productId: r['product_id'] as int? ?? 0,
      productName: r['product_name'] as String? ?? '',
      quantity: (r['quantity'] as num).toDouble(),
      unit: r['unit'] as String? ?? '',
      unitPrice: (r['unit_price'] as num).toDouble(),
      purchasePrice: (r['purchase_price'] as num?)?.toDouble() ?? 0.0,
      discountAmount: (r['discount_amount'] as num?)?.toDouble() ?? 0.0,
      gstRate: (r['gst_rate'] as num?)?.toDouble() ?? 0.0,
      gstAmount: (r['gst_amount'] as num?)?.toDouble() ?? 0.0,
      totalPrice: (r['total_price'] as num).toDouble(),
    )).toList();
    return Bill(
      id: map['id'] as int?,
      billNumber: map['bill_number'] as String,
      billType: map['bill_type'] as String? ?? 'retail',
      items: items,
      totalAmount: (map['total_amount'] as num).toDouble(),
      totalProfit: (map['total_profit'] as num?)?.toDouble() ?? 0.0,
      discountAmount: (map['discount_amount'] as num?)?.toDouble() ?? 0.0,
      gstTotal: (map['gst_total'] as num?)?.toDouble() ?? 0.0,
      cgstTotal: (map['cgst_total'] as num?)?.toDouble() ?? 0.0,
      sgstTotal: (map['sgst_total'] as num?)?.toDouble() ?? 0.0,
      paymentMode: map['payment_mode'] as String? ?? 'cash',
      splitPaymentSummary: map['split_payment_summary'] as String?,
      customerId: map['customer_id'] as int?,
      customerName: map['customer_name'] as String?,
      customerAddress: map['customer_address'] as String?,
      customerGstin: map['customer_gstin'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  // ── Hourly Sales ────────────────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getHourlySalesReport(DateTime date) async {
    final db = await _db.database;
    final day = date.toIso8601String().substring(0, 10);
    return db.rawQuery('''
      SELECT strftime('%H', created_at) as hour,
        SUM(total_amount) as total_sales,
        COUNT(*) as bill_count
      FROM bills
      WHERE DATE(created_at) = ? AND (status IS NULL OR status != 'cancelled')
      GROUP BY strftime('%H', created_at)
      ORDER BY hour ASC
    ''', [day]);
  }

  // ── Item-wise Report ────────────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getItemwiseReport(
      {required DateTime from, required DateTime to}) async {
    final db = await _db.database;
    return db.rawQuery('''
      SELECT bi.product_name, bi.quantity, bi.unit_price, bi.purchase_price,
        bi.total_price, b.bill_number, b.created_at,
        (bi.unit_price - bi.purchase_price) * bi.quantity as profit
      FROM bill_items bi
      JOIN bills b ON b.id = bi.bill_id
      WHERE b.created_at BETWEEN ? AND ? AND (b.status IS NULL OR b.status != 'cancelled')
      ORDER BY b.created_at DESC
    ''', [from.toIso8601String(), to.toIso8601String()]);
  }

  // ── Cashier-wise Sales ──────────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getCashierWiseSales(
      {required DateTime from, required DateTime to}) async {
    final db = await _db.database;
    return db.rawQuery('''
      SELECT COALESCE(u.username, 'Unknown') as cashier_name,
        COUNT(b.id) as bill_count,
        SUM(b.total_amount) as total_sales,
        SUM(b.total_profit) as total_profit
      FROM bills b
      LEFT JOIN app_users u ON u.id = b.billed_by_user_id
      WHERE b.created_at BETWEEN ? AND ? AND (b.status IS NULL OR b.status != 'cancelled')
      GROUP BY b.billed_by_user_id
      ORDER BY total_sales DESC
    ''', [from.toIso8601String(), to.toIso8601String()]);
  }

  // ── Category-wise Stock ─────────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getCategoryStockReport() async {
    final db = await _db.database;
    return db.rawQuery('''
      SELECT c.id as category_id, c.name as category_name, c.icon,
        COUNT(p.id) as product_count,
        SUM(p.stock_quantity) as total_stock_qty,
        SUM(p.stock_quantity * p.selling_price) as total_stock_value
      FROM categories c
      LEFT JOIN products p ON p.category_id = c.id AND p.is_active = 1
      GROUP BY c.id, c.name, c.icon
      ORDER BY total_stock_value DESC
    ''');
  }

  Future<List<Map<String, dynamic>>> getProductsByCategory(int categoryId) async {
    final db = await _db.database;
    return db.rawQuery('''
      SELECT id, name, stock_quantity, selling_price,
        stock_quantity * selling_price as stock_value
      FROM products
      WHERE category_id = ? AND is_active = 1
      ORDER BY name ASC
    ''', [categoryId]);
  }

  // ── Product Stock History ───────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getProductStockHistory(int productId,
      {DateTime? from, DateTime? to}) async {
    final db = await _db.database;
    final f = from ?? DateTime(2020);
    final t = to ?? DateTime.now();
    final sales = await db.rawQuery('''
      SELECT b.created_at, 'sale' as type, bi.quantity * -1 as qty_change,
        bi.total_price as amount, b.bill_number as reference
      FROM bill_items bi
      JOIN bills b ON b.id = bi.bill_id
      WHERE bi.product_id = ? AND b.created_at BETWEEN ? AND ?
    ''', [productId, f.toIso8601String(), t.toIso8601String()]);

    final purchases = await db.rawQuery('''
      SELECT p.created_at, 'purchase' as type, pi.quantity as qty_change,
        pi.total_cost as amount, p.purchase_number as reference
      FROM purchase_items pi
      JOIN purchases p ON p.id = pi.purchase_id
      WHERE pi.product_id = ? AND p.created_at BETWEEN ? AND ?
    ''', [productId, f.toIso8601String(), t.toIso8601String()]);

    final adjustments = await db.rawQuery('''
      SELECT created_at,
        CASE adjustment_type WHEN 'add' THEN 'adjustment_in' ELSE 'adjustment_out' END as type,
        CASE adjustment_type WHEN 'add' THEN quantity ELSE quantity * -1 END as qty_change,
        0.0 as amount, reason as reference
      FROM stock_adjustments
      WHERE product_id = ? AND created_at BETWEEN ? AND ?
    ''', [productId, f.toIso8601String(), t.toIso8601String()]);

    final all = [...sales, ...purchases, ...adjustments];
    all.sort((a, b) => (b['created_at'] as String).compareTo(a['created_at'] as String));
    return all;
  }

  // ── Supplier Statement ──────────────────────────────────────────────────────
  Future<Map<String, dynamic>> getSupplierStatement(int supplierId) async {
    final db = await _db.database;
    final suppliers = await db.query('suppliers', where: 'id = ?', whereArgs: [supplierId]);
    final purchases = await db.query('purchases',
        where: 'supplier_id = ?', whereArgs: [supplierId], orderBy: 'created_at DESC');
    return {'supplier': suppliers.isNotEmpty ? suppliers.first : {}, 'purchases': purchases};
  }

  Future<List<Map<String, dynamic>>> getAllSupplierBalances() async {
    final db = await _db.database;
    return db.rawQuery(
        "SELECT id, name, phone, outstanding_balance FROM suppliers WHERE is_active=1 ORDER BY name ASC");
  }

  // ── Customer Statement ──────────────────────────────────────────────────────
  Future<Map<String, dynamic>> getCustomerStatement(int customerId) async {
    final db = await _db.database;
    final customers = await db.query('customers', where: 'id = ?', whereArgs: [customerId]);
    final bills = await db.query('bills',
        where: 'customer_id = ? AND (status IS NULL OR status != ?)',
        whereArgs: [customerId, 'cancelled'],
        orderBy: 'created_at DESC');
    return {'customer': customers.isNotEmpty ? customers.first : {}, 'bills': bills};
  }

  Future<List<Map<String, dynamic>>> getAllCustomerBalances() async {
    final db = await _db.database;
    return db.rawQuery(
        "SELECT id, name, phone, outstanding_balance FROM customers WHERE is_active=1 ORDER BY name ASC");
  }

  // ── CRM Points ──────────────────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getCRMPointsBalances() async {
    final db = await _db.database;
    return db.rawQuery('''
      SELECT customer_id, customer_name, SUM(points) as total_points
      FROM crm_points_ledger
      GROUP BY customer_id, customer_name
      ORDER BY total_points DESC
    ''');
  }

  Future<List<Map<String, dynamic>>> getCRMStatement(int customerId) async {
    final db = await _db.database;
    return db.rawQuery(
        "SELECT * FROM crm_points_ledger WHERE customer_id=? ORDER BY created_at DESC",
        [customerId]);
  }

  // ── Cash Book ───────────────────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getCashBook(
      {required DateTime from, required DateTime to}) async {
    final db = await _db.database;
    final cashSales = await db.rawQuery('''
      SELECT created_at as date, 'in' as flow_type,
        'Cash Sale - Bill #' || bill_number as description, total_amount as amount
      FROM bills
      WHERE (payment_mode = 'cash' OR payment_mode = 'Cash')
        AND created_at BETWEEN ? AND ?
        AND (status IS NULL OR status != 'cancelled')
    ''', [from.toIso8601String(), to.toIso8601String()]);

    final splitCash = await db.rawQuery('''
      SELECT b.created_at as date, 'in' as flow_type,
        'Cash Split - Bill #' || b.bill_number as description, bps.amount as amount
      FROM bill_payment_splits bps
      JOIN bills b ON b.id = bps.bill_id
      WHERE (bps.payment_mode = 'cash' OR bps.payment_mode = 'Cash')
        AND b.created_at BETWEEN ? AND ?
        AND (b.payment_mode != 'cash' AND b.payment_mode != 'Cash')
    ''', [from.toIso8601String(), to.toIso8601String()]);

    final expenses = await db.rawQuery('''
      SELECT date, 'out' as flow_type,
        COALESCE(description, category) as description, amount
      FROM expenses
      WHERE date BETWEEN ? AND ?
    ''', [from.toIso8601String().substring(0, 10), to.toIso8601String().substring(0, 10)]);

    final all = [...cashSales, ...splitCash, ...expenses];
    all.sort((a, b) => (a['date'] as String).compareTo(b['date'] as String));
    return all;
  }

  // ── Bank Book ───────────────────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getBankBook(
      {required DateTime from, required DateTime to, String? mode}) async {
    final db = await _db.database;
    final modeFilter = mode != null
        ? "AND (LOWER(payment_mode) = LOWER(?))"
        : "AND LOWER(payment_mode) IN ('upi','card','bank','online')";
    final args = mode != null
        ? [from.toIso8601String(), to.toIso8601String(), mode]
        : [from.toIso8601String(), to.toIso8601String()];

    final digitalSales = await db.rawQuery('''
      SELECT created_at as date, 'in' as flow_type,
        payment_mode || ' Sale - Bill #' || bill_number as description, total_amount as amount
      FROM bills
      WHERE created_at BETWEEN ? AND ?
        AND (status IS NULL OR status != 'cancelled')
        $modeFilter
    ''', args);

    final splitDigital = await db.rawQuery('''
      SELECT b.created_at as date, 'in' as flow_type,
        bps.payment_mode || ' Split - Bill #' || b.bill_number as description, bps.amount as amount
      FROM bill_payment_splits bps
      JOIN bills b ON b.id = bps.bill_id
      WHERE b.created_at BETWEEN ? AND ?
        AND LOWER(bps.payment_mode) IN ('upi','card','bank','online')
    ''', [from.toIso8601String(), to.toIso8601String()]);

    final all = [...digitalSales, ...splitDigital];
    all.sort((a, b) => (a['date'] as String).compareTo(b['date'] as String));
    return all;
  }

  // ── Day Book ────────────────────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getDayBook(
      {required DateTime from, required DateTime to}) async {
    final db = await _db.database;
    final bills = await db.rawQuery('''
      SELECT created_at as date, 'sale' as tx_type,
        'Sale - Bill #' || bill_number as description,
        total_amount as amount, payment_mode
      FROM bills
      WHERE created_at BETWEEN ? AND ? AND (status IS NULL OR status != 'cancelled')
    ''', [from.toIso8601String(), to.toIso8601String()]);

    final purchases = await db.rawQuery('''
      SELECT created_at as date, 'purchase' as tx_type,
        'Purchase - ' || COALESCE(supplier_name, purchase_number) as description,
        total_amount as amount, payment_mode
      FROM purchases
      WHERE created_at BETWEEN ? AND ?
    ''', [from.toIso8601String(), to.toIso8601String()]);

    final expenses = await db.rawQuery('''
      SELECT date, 'expense' as tx_type,
        COALESCE(description, category) as description,
        amount, 'cash' as payment_mode
      FROM expenses
      WHERE date BETWEEN ? AND ?
    ''', [from.toIso8601String().substring(0, 10), to.toIso8601String().substring(0, 10)]);

    final returns = await db.rawQuery('''
      SELECT created_at as date, 'return' as tx_type,
        'Return - ' || COALESCE(original_bill_number, return_number) as description,
        total_return_amount as amount, refund_mode as payment_mode
      FROM sale_returns
      WHERE created_at BETWEEN ? AND ?
    ''', [from.toIso8601String(), to.toIso8601String()]);

    final all = [...bills, ...purchases, ...expenses, ...returns];
    all.sort((a, b) => (a['date'] as String).compareTo(b['date'] as String));
    return all;
  }

  // ── Profit & Loss ───────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> getProfitAndLoss(
      {required DateTime from, required DateTime to}) async {
    final db = await _db.database;
    final incomeResult = await db.rawQuery('''
      SELECT COALESCE(SUM(total_amount), 0) as income
      FROM bills
      WHERE created_at BETWEEN ? AND ? AND (status IS NULL OR status != 'cancelled')
    ''', [from.toIso8601String(), to.toIso8601String()]);

    final cogsResult = await db.rawQuery('''
      SELECT COALESCE(SUM(bi.purchase_price * bi.quantity), 0) as cogs
      FROM bill_items bi
      JOIN bills b ON b.id = bi.bill_id
      WHERE b.created_at BETWEEN ? AND ? AND (b.status IS NULL OR b.status != 'cancelled')
    ''', [from.toIso8601String(), to.toIso8601String()]);

    final expensesResult = await db.rawQuery('''
      SELECT COALESCE(SUM(amount), 0) as expenses
      FROM expenses
      WHERE date BETWEEN ? AND ?
    ''', [from.toIso8601String().substring(0, 10), to.toIso8601String().substring(0, 10)]);

    final returnsResult = await db.rawQuery('''
      SELECT COALESCE(SUM(total_return_amount), 0) as return_deductions
      FROM sale_returns
      WHERE created_at BETWEEN ? AND ?
    ''', [from.toIso8601String(), to.toIso8601String()]);

    final income = (incomeResult.first['income'] as num).toDouble();
    final cogs = (cogsResult.first['cogs'] as num).toDouble();
    final expenses = (expensesResult.first['expenses'] as num).toDouble();
    final returnDeductions = (returnsResult.first['return_deductions'] as num).toDouble();
    final netSales = income - returnDeductions;
    final grossProfit = netSales - cogs;
    final netProfit = grossProfit - expenses;

    return {
      'income': income,
      'return_deductions': returnDeductions,
      'net_sales': netSales,
      'cogs': cogs,
      'gross_profit': grossProfit,
      'expenses': expenses,
      'net_profit': netProfit,
      'profit_margin': netSales > 0 ? (netProfit / netSales) * 100 : 0.0,
    };
  }

  // ── Wholesale / Retail Stock Report ─────────────────────────────────────────
  /// Returns stock report with wholesale+retail breakdown for products
  /// that have wholesaleToRetailQty > 1
  Future<List<Map<String, dynamic>>> getWholesaleRetailStockReport() async {
    final db = await _db.database;
    return db.rawQuery('''
      SELECT 
        p.id, p.name, p.stock_quantity,
        p.wholesale_unit, p.retail_unit, p.wholesale_to_retail_qty,
        p.wholesale_price, p.retail_price,
        COALESCE(SUM(CASE WHEN IFNULL(bi.sale_type, 'retail') = 'wholesale' THEN bi.quantity ELSE 0 END), 0) as total_wholesale_sold,
        COALESCE(SUM(CASE WHEN IFNULL(bi.sale_type, 'retail') = 'retail' THEN bi.quantity ELSE 0 END), 0) as total_retail_sold,
        COALESCE(pur.total_purchased_bags, 0) as total_purchased_bags
      FROM products p
      LEFT JOIN bill_items bi ON bi.product_id = p.id
      LEFT JOIN bills b ON b.id = bi.bill_id AND (b.status IS NULL OR b.status != 'cancelled')
      LEFT JOIN (
        SELECT pi.product_id, SUM(pi.quantity) as total_purchased_bags
        FROM purchase_items pi
        GROUP BY pi.product_id
      ) pur ON pur.product_id = p.id
      WHERE p.wholesale_to_retail_qty > 1.0 AND p.is_active = 1
      GROUP BY p.id, p.name
      ORDER BY p.name ASC
    ''');
  }

  // ── Purchase Report ──────────────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getPurchaseReport({
    DateTime? from,
    DateTime? to,
    int? supplierId,
    int? productId,
    int? categoryId,
  }) async {
    final db = await _db.database;
    final f = from ?? DateTime(2020);
    final t = to ?? DateTime.now();

    String where = "p.purchase_date BETWEEN ? AND ?";
    final args = <dynamic>[
      f.toIso8601String().substring(0, 10),
      t.toIso8601String().substring(0, 10),
    ];

    if (supplierId != null) {
      where += " AND p.supplier_id = ?";
      args.add(supplierId);
    }
    if (productId != null) {
      where += " AND pi.product_id = ?";
      args.add(productId);
    }
    if (categoryId != null) {
      where += " AND pr.category_id = ?";
      args.add(categoryId);
    }

    return db.rawQuery('''
      SELECT 
        pi.id as item_id,
        pi.product_id,
        pi.product_name,
        pi.quantity,
        pi.unit,
        pi.unit_cost,
        pi.total_cost,
        p.purchase_number,
        p.purchase_date,
        COALESCE(p.supplier_name, 'N/A') as supplier_name,
        p.payment_mode,
        COALESCE(c.name, 'Uncategorized') as category_name
      FROM purchase_items pi
      JOIN purchases p ON p.id = pi.purchase_id
      LEFT JOIN products pr ON pr.id = pi.product_id
      LEFT JOIN categories c ON c.id = pr.category_id
      WHERE $where
      ORDER BY p.purchase_date DESC, p.id DESC
    ''', args);
  }

  // ── Product Stock & Sales Report ─────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getProductStockSalesReport({
    DateTime? from,
    DateTime? to,
    int? productId,
    int? categoryId,
  }) async {
    final db = await _db.database;
    final f = from ?? DateTime(2020);
    final t = to ?? DateTime.now();
    final fStr = f.toIso8601String().substring(0, 10);
    final tStr = t.toIso8601String().substring(0, 10);

    String outerWhere = "p.is_active = 1";
    final args = <dynamic>[fStr, tStr, fStr, tStr, fStr, tStr];

    if (productId != null) {
      outerWhere += " AND p.id = ?";
      args.add(productId);
    }
    if (categoryId != null) {
      outerWhere += " AND p.category_id = ?";
      args.add(categoryId);
    }

    return db.rawQuery('''
      SELECT
        p.id,
        p.name,
        COALESCE(p.unit, 'pcs') as unit,
        COALESCE(p.wholesale_unit, 'bag') as wholesale_unit,
        COALESCE(p.retail_unit, COALESCE(p.unit,'kg')) as retail_unit,
        COALESCE(p.wholesale_to_retail_qty, 1.0) as wholesale_to_retail_qty,
        p.selling_price,
        COALESCE(p.retail_price, p.selling_price) as retail_price,
        p.wholesale_price,
        p.stock_quantity as current_stock,

        COALESCE(pur.total_purchased_qty, 0) as total_purchased_qty,
        COALESCE(pur.total_purchase_value, 0) as total_purchase_value,

        COALESCE(wsales.total_wholesale_qty, 0) as total_wholesale_sold_qty,
        COALESCE(wsales.total_wholesale_value, 0) as total_wholesale_sold_value,

        COALESCE(rsales.total_retail_qty, 0) as total_retail_sold_qty,
        COALESCE(rsales.total_retail_value, 0) as total_retail_sold_value,

        COALESCE(
          (COALESCE(wsales.total_wholesale_qty,0) * COALESCE(p.wholesale_to_retail_qty,1.0))
          + COALESCE(rsales.total_retail_qty, 0),
          0
        ) as total_sold_base_qty,

        COALESCE(c.name, 'Uncategorized') as category_name

      FROM products p
      LEFT JOIN categories c ON c.id = p.category_id

      LEFT JOIN (
        SELECT pi.product_id,
          SUM(pi.quantity) as total_purchased_qty,
          SUM(pi.total_cost) as total_purchase_value
        FROM purchase_items pi
        JOIN purchases pu ON pu.id = pi.purchase_id
        WHERE pu.purchase_date BETWEEN ? AND ?
        GROUP BY pi.product_id
      ) pur ON pur.product_id = p.id

      LEFT JOIN (
        SELECT bi.product_id,
          SUM(bi.quantity) as total_wholesale_qty,
          SUM(bi.total_price) as total_wholesale_value
        FROM bill_items bi
        JOIN bills b ON b.id = bi.bill_id
        WHERE DATE(b.created_at) BETWEEN ? AND ?
          AND COALESCE(bi.sale_type, 'retail') = 'wholesale'
          AND (b.status IS NULL OR b.status != 'cancelled')
        GROUP BY bi.product_id
      ) wsales ON wsales.product_id = p.id

      LEFT JOIN (
        SELECT bi.product_id,
          SUM(bi.quantity) as total_retail_qty,
          SUM(bi.total_price) as total_retail_value
        FROM bill_items bi
        JOIN bills b ON b.id = bi.bill_id
        WHERE DATE(b.created_at) BETWEEN ? AND ?
          AND COALESCE(bi.sale_type, 'retail') != 'wholesale'
          AND (b.status IS NULL OR b.status != 'cancelled')
        GROUP BY bi.product_id
      ) rsales ON rsales.product_id = p.id

      WHERE $outerWhere
      ORDER BY p.name ASC
    ''', args);
  }

  // ── Filter Dropdown Helpers ───────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getAllSuppliers() async {
    final db = await _db.database;
    return db.query('suppliers', where: 'is_active = 1', orderBy: 'name ASC');
  }

  Future<List<Map<String, dynamic>>> getAllCategories() async {
    final db = await _db.database;
    return db.query('categories', orderBy: 'name ASC');
  }

  Future<List<Map<String, dynamic>>> getAllProductsForFilter() async {
    final db = await _db.database;
    return db.query('products',
        where: 'is_active = 1',
        columns: ['id', 'name'],
        orderBy: 'name ASC');
  }

  // ── Theoretical Yield Report ─────────────────────────────────────────────────
  /// Returns composite_recipe products with their theoretical yield based on
  /// current ingredient stock. Each row contains name, unit, max_yield,
  /// limiting_ingredient, bom_cost, and selling_price.
  Future<List<Map<String, dynamic>>> getTheoreticalYieldReport() async {
    final db = await _db.database;
    // Fetch all composite_recipe products (v12+; graceful fallback for older DBs)
    List<Map<String, dynamic>> recipes;
    try {
      recipes = await db.rawQuery(
          "SELECT id, name, unit, selling_price, attributes FROM products "
          "WHERE item_type = 'composite_recipe' AND is_active = 1");
    } catch (_) {
      return []; // item_type column not yet added
    }
    if (recipes.isEmpty) return [];

    // Fetch current stock for all products
    final stockRows = await db.rawQuery(
        "SELECT id, stock_quantity FROM products WHERE is_active = 1");
    final stockMap = <int, double>{
      for (final r in stockRows)
        (r['id'] as int): (r['stock_quantity'] as num).toDouble()
    };

    final results = <Map<String, dynamic>>[];
    for (final recipe in recipes) {
      final attributesStr = recipe['attributes'] as String? ?? '{}';
      late final List<dynamic> bomRaw;
      try {
        final decoded = jsonDecode(attributesStr) as Map<String, dynamic>?;
        bomRaw = decoded?['bom'] as List<dynamic>? ?? [];
      } catch (_) {
        bomRaw = [];
      }
      if (bomRaw.isEmpty) continue;

      double maxYield = double.infinity;
      String? limitingIngredient;
      double bomCost = 0;

      for (final ingRaw in bomRaw) {
        final ing = ingRaw as Map<String, dynamic>;
        final productId = ing['product_id'] as int?;
        final qty = (ing['quantity'] as num?)?.toDouble() ?? 0;
        final unitCost = (ing['unit_cost'] as num?)?.toDouble() ?? 0;
        bomCost += qty * unitCost;
        if (productId == null || qty <= 0) continue;
        final avail = stockMap[productId] ?? 0;
        final possible = avail / qty;
        if (possible < maxYield) {
          maxYield = possible;
          limitingIngredient = ing['product_name'] as String?;
        }
      }

      if (maxYield == double.infinity) maxYield = 0;

      results.add({
        'id': recipe['id'],
        'name': recipe['name'],
        'unit': recipe['unit'],
        'selling_price': recipe['selling_price'],
        'bom_cost': bomCost,
        'max_yield': maxYield.floorToDouble(),
        'limiting_ingredient': maxYield == 0 ? limitingIngredient : null,
      });
    }
    return results;
  }

  // ── Phase 4: Ledger-based Profit & Loss ─────────────────────────────────────
  /// Aggregates P&L from ledger_entries (double-entry sub-ledger introduced in
  /// Phase 1). Falls back to the legacy query when no ledger rows exist.
  Future<Map<String, dynamic>> getProfitAndLossFromLedger(
      {required DateTime from, required DateTime to}) async {
    final db = await _db.database;

    // Check if ledger_entries table exists and has data in range
    int ledgerCount = 0;
    try {
      final check = await db.rawQuery(
          "SELECT COUNT(*) as cnt FROM ledger_entries WHERE created_at BETWEEN ? AND ?",
          [from.toIso8601String(), to.toIso8601String()]);
      ledgerCount = (check.first['cnt'] as int? ?? 0);
    } catch (_) {}

    if (ledgerCount == 0) {
      // Fall back to legacy bills/expenses query
      return getProfitAndLoss(from: from, to: to);
    }

    // Aggregate by account_type from ledger_entries joined to erp_transactions
    final rows = await db.rawQuery('''
      SELECT le.account_type, SUM(le.amount) as total
      FROM ledger_entries le
      JOIN erp_transactions et ON et.id = le.transaction_id
      WHERE le.created_at BETWEEN ? AND ?
      GROUP BY le.account_type
    ''', [from.toIso8601String(), to.toIso8601String()]);

    final grouped = <String, double>{};
    for (final r in rows) {
      grouped[r['account_type'] as String] =
          (r['total'] as num?)?.toDouble() ?? 0;
    }

    final income = grouped['income'] ?? 0;
    final cogs = grouped['cogs'] ?? 0;
    final expenses = grouped['expense'] ?? 0;
    final waste = grouped['waste'] ?? 0; // spoilage / write-offs

    // Also pull returns from sale_returns for deduction
    final returnsResult = await db.rawQuery('''
      SELECT COALESCE(SUM(total_return_amount), 0) as return_deductions
      FROM sale_returns WHERE created_at BETWEEN ? AND ?
    ''', [from.toIso8601String(), to.toIso8601String()]);
    final returnDeductions =
        (returnsResult.first['return_deductions'] as num).toDouble();

    final netSales = income - returnDeductions;
    final grossProfit = netSales - cogs;
    final netProfit = grossProfit - expenses - waste;

    return {
      'income': income,
      'return_deductions': returnDeductions,
      'net_sales': netSales,
      'cogs': cogs,
      'gross_profit': grossProfit,
      'expenses': expenses,
      'waste': waste,
      'net_profit': netProfit,
      'profit_margin': netSales > 0 ? (netProfit / netSales) * 100 : 0.0,
      'source': 'ledger',
    };
  }

  // ── Ledger Balances (account-wise totals) ────────────────────────────────────
  /// Returns current balance for each account_type, aggregated from
  /// [ledger_entries]. Debit entries are positive, credit entries negative
  /// for asset/expense/cogs/inventory/waste accounts. For income/liability
  /// the balance is the net credit amount.
  Future<Map<String, double>> getLedgerBalances({
    DateTime? from,
    DateTime? to,
  }) async {
    final db = await _db.database;
    final f = from ?? DateTime(2000);
    final t = to ?? DateTime.now();
    try {
      final rows = await db.rawQuery('''
        SELECT account_type,
               direction,
               COALESCE(SUM(amount), 0) as total
        FROM ledger_entries
        WHERE created_at BETWEEN ? AND ?
        GROUP BY account_type, direction
      ''', [f.toIso8601String(), t.toIso8601String()]);

      final map = <String, double>{
        'income': 0, 'cogs': 0, 'expense': 0,
        'inventory': 0, 'asset': 0, 'liability': 0, 'waste': 0,
      };
      for (final r in rows) {
        final type = r['account_type'] as String;
        final dir = r['direction'] as String? ?? 'debit';
        final amt = (r['total'] as num).toDouble();
        final current = map[type] ?? 0;
        // Credit income/liability = positive balance; debit = negative balance
        if (type == 'income' || type == 'liability') {
          map[type] = current + (dir == 'credit' ? amt : -amt);
        } else {
          map[type] = current + (dir == 'debit' ? amt : -amt);
        }
      }
      return map;
    } catch (_) {
      return {'income': 0, 'cogs': 0, 'expense': 0, 'inventory': 0,
              'asset': 0, 'liability': 0, 'waste': 0};
    }
  }

  // ── Trial Balance ────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> getTrialBalance({
    required DateTime from,
    required DateTime to,
  }) async {
    final balances = await getLedgerBalances(from: from, to: to);
    final totalDebits = (balances['asset'] ?? 0) + (balances['cogs'] ?? 0) +
        (balances['expense'] ?? 0) + (balances['inventory'] ?? 0) +
        (balances['waste'] ?? 0);
    final totalCredits = (balances['income'] ?? 0) + (balances['liability'] ?? 0);
    return {
      ...balances,
      'total_debits': totalDebits,
      'total_credits': totalCredits,
      'is_balanced': (totalDebits - totalCredits).abs() < 0.01,
    };
  }

  // ── Customer Dr/Cr Ledger ────────────────────────────────────────────────────
  /// Returns a chronological Dr/Cr statement for a customer with running balance.
  /// Sources: bills (Dr), payments recorded in bill_payment_splits (Cr).
  Future<Map<String, dynamic>> getCustomerLedger(int customerId) async {
    final db = await _db.database;
    final customerRows = await db.query('customers',
        where: 'id = ?', whereArgs: [customerId]);
    if (customerRows.isEmpty) return {'customer': {}, 'entries': [], 'closing_balance': 0.0};

    final customer = customerRows.first;
    final double openingBalance =
        (customer['outstanding_balance'] as num?)?.toDouble() ?? 0;

    // Bills (debit — customer owes)
    final bills = await db.rawQuery('''
      SELECT created_at as date,
             'Invoice #' || bill_number as description,
             total_amount as debit, 0.0 as credit
      FROM bills
      WHERE customer_id = ? AND (status IS NULL OR status != 'cancelled')
      ORDER BY created_at ASC
    ''', [customerId]);

    // Returns (credit — customer is owed)
    final returns = await db.rawQuery('''
      SELECT sr.created_at as date,
             'Return #' || sr.return_number as description,
             0.0 as debit, sr.total_return_amount as credit
      FROM sale_returns sr
      JOIN bills b ON b.id = sr.original_bill_id
      WHERE b.customer_id = ?
      ORDER BY sr.created_at ASC
    ''', [customerId]);

    final all = [...bills, ...returns];
    all.sort((a, b) => (a['date'] as String).compareTo(b['date'] as String));

    // Compute running balance
    double balance = openingBalance;
    final entries = all.map((r) {
      final debit = (r['debit'] as num?)?.toDouble() ?? 0;
      final credit = (r['credit'] as num?)?.toDouble() ?? 0;
      balance += debit - credit;
      return {
        'date': r['date'],
        'description': r['description'],
        'debit': debit,
        'credit': credit,
        'balance': balance,
      };
    }).toList();

    return {
      'customer': customer,
      'opening_balance': openingBalance,
      'entries': entries,
      'closing_balance': balance,
    };
  }

  // ── Supplier Dr/Cr Ledger ────────────────────────────────────────────────────
  /// Returns a chronological Dr/Cr statement for a supplier with running balance.
  Future<Map<String, dynamic>> getSupplierLedger(int supplierId) async {
    final db = await _db.database;
    final supplierRows = await db.query('suppliers',
        where: 'id = ?', whereArgs: [supplierId]);
    if (supplierRows.isEmpty) return {'supplier': {}, 'entries': [], 'closing_balance': 0.0};

    final supplier = supplierRows.first;
    final double openingBalance =
        (supplier['outstanding_balance'] as num?)?.toDouble() ?? 0;

    // Purchases (credit — we owe supplier)
    final purchases = await db.rawQuery('''
      SELECT created_at as date,
             'Purchase #' || purchase_number as description,
             0.0 as debit, total_amount as credit
      FROM purchases
      WHERE supplier_id = ?
      ORDER BY created_at ASC
    ''', [supplierId]);

    double balance = openingBalance;
    final entries = (purchases as List<Map<String, dynamic>>).map((r) {
      final credit = (r['credit'] as num?)?.toDouble() ?? 0;
      balance += credit;
      return {
        'date': r['date'],
        'description': r['description'],
        'debit': 0.0,
        'credit': credit,
        'balance': balance,
      };
    }).toList();

    return {
      'supplier': supplier,
      'opening_balance': openingBalance,
      'entries': entries,
      'closing_balance': balance,
    };
  }

  // ── GSTR-1 Report ────────────────────────────────────────────────────────────
  /// Returns structured GSTR-1 data: B2B invoices, B2C invoices, HSN summary.
  Future<Map<String, dynamic>> getGstr1Report({
    required DateTime from,
    required DateTime to,
  }) async {
    final db = await _db.database;

    // B2B — bills with customer GSTIN
    final b2b = await db.rawQuery('''
      SELECT b.bill_number, b.created_at, b.customer_name, b.customer_gstin,
             b.total_amount, b.gst_total, b.cgst_total, b.sgst_total, b.igst_total,
             b.total_amount - b.gst_total as taxable_value
      FROM bills b
      WHERE b.created_at BETWEEN ? AND ?
        AND b.customer_gstin IS NOT NULL
        AND (b.status IS NULL OR b.status != 'cancelled')
      ORDER BY b.created_at DESC
    ''', [from.toIso8601String(), to.toIso8601String()]);

    // B2C — bills without GSTIN
    final b2cResult = await db.rawQuery('''
      SELECT
        COALESCE(SUM(b.total_amount - b.gst_total), 0) as taxable_value,
        COALESCE(SUM(b.cgst_total), 0) as cgst,
        COALESCE(SUM(b.sgst_total), 0) as sgst,
        COALESCE(SUM(b.igst_total), 0) as igst,
        COUNT(*) as invoice_count
      FROM bills b
      WHERE b.created_at BETWEEN ? AND ?
        AND (b.customer_gstin IS NULL OR b.customer_gstin = '')
        AND (b.status IS NULL OR b.status != 'cancelled')
    ''', [from.toIso8601String(), to.toIso8601String()]);

    // HSN-wise summary
    final hsn = await db.rawQuery('''
      SELECT COALESCE(p.hsn_code, 'N/A') as hsn_code,
             COALESCE(p.unit, 'Pcs') as unit,
             SUM(bi.quantity) as total_qty,
             SUM(bi.total_price - bi.gst_amount) as taxable_value,
             SUM(bi.gst_amount) as total_gst,
             bi.gst_rate
      FROM bill_items bi
      JOIN bills b ON b.id = bi.bill_id
      LEFT JOIN products p ON p.id = bi.product_id
      WHERE b.created_at BETWEEN ? AND ?
        AND (b.status IS NULL OR b.status != 'cancelled')
      GROUP BY p.hsn_code, bi.gst_rate
      ORDER BY taxable_value DESC
    ''', [from.toIso8601String(), to.toIso8601String()]);

    return {
      'period_from': from.toIso8601String().substring(0, 10),
      'period_to': to.toIso8601String().substring(0, 10),
      'b2b': b2b,
      'b2c': b2cResult.isNotEmpty ? b2cResult.first : {},
      'hsn_summary': hsn,
    };
  }

  // ── Day Close Summary ────────────────────────────────────────────────────────
  /// Computes all the numbers needed to close a business day.
  Future<Map<String, dynamic>> getDayCloseSummary(DateTime date) async {
    final db = await _db.database;
    final dateStr = date.toIso8601String().substring(0, 10);

    final salesResult = await db.rawQuery('''
      SELECT
        COALESCE(SUM(total_amount), 0) as total_sales,
        COUNT(*) as bill_count,
        COALESCE(SUM(CASE WHEN LOWER(payment_mode) IN ('cash') THEN total_amount ELSE 0 END), 0) as cash_sales,
        COALESCE(SUM(CASE WHEN LOWER(payment_mode) NOT IN ('cash','split') THEN total_amount ELSE 0 END), 0) as digital_sales
      FROM bills
      WHERE DATE(created_at) = ? AND (status IS NULL OR status != 'cancelled')
    ''', [dateStr]);

    final splitCash = await db.rawQuery('''
      SELECT COALESCE(SUM(bps.amount), 0) as split_cash
      FROM bill_payment_splits bps
      JOIN bills b ON b.id = bps.bill_id
      WHERE DATE(b.created_at) = ? AND LOWER(bps.payment_mode) = 'cash'
    ''', [dateStr]);

    final expensesResult = await db.rawQuery('''
      SELECT COALESCE(SUM(amount), 0) as total_expenses
      FROM expenses WHERE DATE(date) = ?
    ''', [dateStr]);

    final returnsResult = await db.rawQuery('''
      SELECT COALESCE(SUM(total_return_amount), 0) as total_returns
      FROM sale_returns WHERE DATE(created_at) = ?
    ''', [dateStr]);

    final purchasesResult = await db.rawQuery('''
      SELECT COALESCE(SUM(total_amount), 0) as total_purchases
      FROM purchases WHERE DATE(created_at) = ?
    ''', [dateStr]);

    final s = salesResult.first;
    final totalSales = (s['total_sales'] as num).toDouble();
    final billCount = (s['bill_count'] as int? ?? 0);
    final cashSales = (s['cash_sales'] as num).toDouble() +
        ((splitCash.first['split_cash'] as num?)?.toDouble() ?? 0);
    final digitalSales = (s['digital_sales'] as num).toDouble();
    final expenses = (expensesResult.first['total_expenses'] as num).toDouble();
    final returns = (returnsResult.first['total_returns'] as num).toDouble();
    final purchases = (purchasesResult.first['total_purchases'] as num).toDouble();

    return {
      'date': dateStr,
      'total_sales': totalSales,
      'bill_count': billCount,
      'cash_sales': cashSales,
      'digital_sales': digitalSales,
      'total_expenses': expenses,
      'total_returns': returns,
      'total_purchases': purchases,
      'net_cash': cashSales - expenses,
    };
  }

  // ── Day Close CRUD ───────────────────────────────────────────────────────────
  Future<bool> isDayClosed(DateTime date) async {
    final db = await _db.database;
    final dateStr = date.toIso8601String().substring(0, 10);
    final rows = await db.query('day_close',
        where: 'close_date = ?', whereArgs: [dateStr]);
    return rows.isNotEmpty;
  }

  Future<void> saveCloseDay({
    required DateTime date,
    required double cashOpening,
    required double cashClosing,
    required Map<String, dynamic> summary,
    String? notes,
    String? closedBy,
  }) async {
    final db = await _db.database;
    final dateStr = date.toIso8601String().substring(0, 10);
    final cashVariance = cashClosing -
        (cashOpening + (summary['cash_sales'] as num).toDouble() -
            (summary['total_expenses'] as num).toDouble());
    await db.insert('day_close', {
      'close_date': dateStr,
      'cash_opening': cashOpening,
      'cash_closing': cashClosing,
      'cash_variance': cashVariance,
      'total_sales': summary['total_sales'],
      'total_expenses': summary['total_expenses'],
      'total_returns': summary['total_returns'],
      'total_purchases': summary['total_purchases'],
      'cash_sales': summary['cash_sales'],
      'digital_sales': summary['digital_sales'],
      'bill_count': summary['bill_count'],
      'notes': notes,
      'closed_by': closedBy,
      'created_at': DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, dynamic>>> getDayCloseHistory({int limit = 30}) async {
    final db = await _db.database;
    try {
      return db.query('day_close', orderBy: 'close_date DESC', limit: limit);
    } catch (_) { return []; }
  }
}
