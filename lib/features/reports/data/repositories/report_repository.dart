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
}
