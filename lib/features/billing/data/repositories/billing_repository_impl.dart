import '../../../../core/database/database_helper.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../domain/entities/bill.dart';
import '../../domain/entities/sale_type.dart';

abstract class BillingRepository {
  Future<Bill> saveBill({
    required List<CartItem> items, String billType, double discountAmount,
    String paymentMode, List<SplitPayment>? splitPayments,
    int? customerId, String? customerName,
    String? customerAddress, String? customerGstin,
  });
  Future<List<Bill>> getBillsByDate(DateTime date);
  Future<Map<String, double>> getDailySummary(DateTime date);
  Future<Map<String, double>> getMonthlySummary(int year, int month);
}

class BillingRepositoryImpl implements BillingRepository {
  final DatabaseHelper _dbHelper;
  BillingRepositoryImpl(this._dbHelper);

  String _genBillNumber() {
    final now = DateTime.now();
    return '${now.year}${now.month.toString().padLeft(2,'0')}${now.day.toString().padLeft(2,'0')}-${now.millisecond.toString().padLeft(4,'0')}';
  }

  @override
  Future<Bill> saveBill({
    required List<CartItem> items, String billType = 'retail',
    double discountAmount = 0.0, String paymentMode = 'cash',
    List<SplitPayment>? splitPayments,
    int? customerId, String? customerName, String? customerAddress, String? customerGstin,
  }) async {
    final db = await _dbHelper.database;
    final now = DateTime.now();
    final bt = billType == 'wholesale' ? BillType.wholesale : BillType.retail;

    // If split payments provided, override paymentMode and build summary string
    final bool isSplit = splitPayments != null && splitPayments.isNotEmpty;
    String effectivePaymentMode = paymentMode;
    String? splitSummary;
    if (isSplit) {
      effectivePaymentMode = 'split';
      splitSummary = splitPayments.map((s) {
        final label = PaymentMode.values
            .firstWhere((m) => m.name == s.mode, orElse: () => PaymentMode.cash)
            .label;
        return '$label ${CurrencyFormatter.format(s.amount)}';
      }).join(' + ');
    }

    double totalAmount = items.fold(0.0, (s, i) => s + i.totalFor(bt)) - discountAmount;
    double totalProfit = items.fold(0.0, (s, i) => s + i.profitFor(bt));
    double gstTotal = items.fold(0.0, (s, i) => s + i.gstAmountFor(bt));

    return await db.transaction((txn) async {
      final billId = await txn.insert('bills', {
        'bill_number': _genBillNumber(), 'bill_type': billType,
        'customer_id': customerId, 'customer_name': customerName,
        'customer_address': customerAddress, 'customer_gstin': customerGstin,
        'total_amount': totalAmount, 'total_profit': totalProfit,
        'discount_amount': discountAmount, 'gst_total': gstTotal,
        'cgst_total': gstTotal / 2, 'sgst_total': gstTotal / 2,
        'payment_mode': effectivePaymentMode,
        'split_payment_summary': splitSummary,
        'created_at': now.toIso8601String(),
      });

      // Store individual split entries
      if (isSplit) {
        for (final split in splitPayments) {
          await txn.insert('bill_payment_splits', {
            'bill_id': billId,
            'payment_mode': split.mode,
            'amount': split.amount,
          });
        }
      }

      final billItems = <BillItem>[];
      for (final cartItem in items) {
        final effectivePrice = cartItem.effectivePrice(bt);
        final gstAmt = cartItem.gstAmountFor(bt);
        final itemTotal = cartItem.totalFor(bt);
        final itemSaleType = cartItem.saleType.value;
        final itemId = await txn.insert('bill_items', {
          'bill_id': billId, 'product_id': cartItem.productId,
          'product_name': cartItem.productName, 'quantity': cartItem.quantity,
          'unit': cartItem.unit, 'unit_price': effectivePrice,
          'purchase_price': cartItem.purchasePrice,
          'gst_rate': cartItem.gstRate, 'gst_amount': gstAmt, 'total_price': itemTotal,
          'sale_uom_id': cartItem.saleUomId,
          'conversion_qty': cartItem.conversionQty,
          'sale_type': itemSaleType,
        });
        // Deduct stock — wholesale items deduct wholesaleToRetailQty per unit
        final double baseQtyToDeduct;
        if (cartItem.saleType == SaleType.wholesale && cartItem.wholesaleToRetailQty > 1.0) {
          baseQtyToDeduct = cartItem.quantity * cartItem.wholesaleToRetailQty;
        } else {
          baseQtyToDeduct = cartItem.quantity * cartItem.conversionQty;
        }
        await txn.rawUpdate(
            'UPDATE products SET stock_quantity = stock_quantity - ?, updated_at = ? WHERE id = ?',
            [baseQtyToDeduct, now.toIso8601String(), cartItem.productId]);

        billItems.add(BillItem(id: itemId, billId: billId, productId: cartItem.productId,
            productName: cartItem.productName, quantity: cartItem.quantity, unit: cartItem.unit,
            unitPrice: effectivePrice, purchasePrice: cartItem.purchasePrice,
            gstRate: cartItem.gstRate, gstAmount: gstAmt, totalPrice: itemTotal));
      }

      return Bill(id: billId, billNumber: 'BILL-$billId', billType: billType,
          items: billItems, totalAmount: totalAmount, totalProfit: totalProfit,
          discountAmount: discountAmount, gstTotal: gstTotal, cgstTotal: gstTotal/2,
          sgstTotal: gstTotal/2, paymentMode: effectivePaymentMode,
          splitPaymentSummary: splitSummary,
          customerId: customerId,
          customerName: customerName, customerAddress: customerAddress,
          customerGstin: customerGstin, createdAt: now);
    });
  }

  @override
  Future<List<Bill>> getBillsByDate(DateTime date) async {
    final db = await _dbHelper.database;
    final dateStr = date.toIso8601String().substring(0, 10);
    final rows = await db.query('bills', where: "created_at LIKE ?", whereArgs: ['$dateStr%'], orderBy: 'created_at DESC');
    return rows.map((r) => Bill(
      id: r['id'] as int, billNumber: r['bill_number'] as String,
      billType: r['bill_type'] as String? ?? 'retail', items: [],
      totalAmount: (r['total_amount'] as num).toDouble(),
      totalProfit: (r['total_profit'] as num).toDouble(),
      customerName: r['customer_name'] as String?,
      paymentMode: r['payment_mode'] as String? ?? 'cash',
      createdAt: DateTime.parse(r['created_at'] as String),
    )).toList();
  }

  @override
  Future<Map<String, double>> getDailySummary(DateTime date) async {
    final db = await _dbHelper.database;
    final dateStr = date.toIso8601String().substring(0, 10);
    final result = await db.rawQuery(
        'SELECT COALESCE(SUM(total_amount),0) as sales, COALESCE(SUM(total_profit),0) as profit, COUNT(*) as bill_count FROM bills WHERE created_at LIKE ?',
        ['$dateStr%']);
    final row = result.first;
    return {'sales': (row['sales'] as num).toDouble(), 'profit': (row['profit'] as num).toDouble(), 'billCount': (row['bill_count'] as num).toDouble()};
  }

  @override
  Future<Map<String, double>> getMonthlySummary(int year, int month) async {
    final db = await _dbHelper.database;
    final prefix = '$year-${month.toString().padLeft(2,'0')}';
    final result = await db.rawQuery(
        'SELECT COALESCE(SUM(total_amount),0) as sales, COALESCE(SUM(total_profit),0) as profit, COUNT(*) as bill_count FROM bills WHERE created_at LIKE ?',
        ['$prefix%']);
    final row = result.first;
    return {'sales': (row['sales'] as num).toDouble(), 'profit': (row['profit'] as num).toDouble(), 'billCount': (row['bill_count'] as num).toDouble()};
  }
}