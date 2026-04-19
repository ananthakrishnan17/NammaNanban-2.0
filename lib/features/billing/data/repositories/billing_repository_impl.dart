import '../../../../core/database/database_helper.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/sync/sync_service.dart';
import '../../../../core/sync/sync_status.dart';
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
  Future<void> deleteBill(int id);
}

class BillingRepositoryImpl implements BillingRepository {
  final DatabaseHelper _dbHelper;
  BillingRepositoryImpl(this._dbHelper);

  String _genBillNumber() {
    final now = DateTime.now();
    return '${now.year}${now.month.toString().padLeft(2,'0')}${now.day.toString().padLeft(2,'0')}'
        '-${now.hour.toString().padLeft(2,'0')}${now.minute.toString().padLeft(2,'0')}'
        '${now.second.toString().padLeft(2,'0')}${now.millisecond.toString().padLeft(3,'0')}';
  }

  /// Builds the items payload list from [BillItem]s for cloud sync.
  List<Map<String, dynamic>> _billItemsPayload(List<BillItem> items) {
    return items.map((i) => {
      'product_name': i.productName,
      'quantity': i.quantity,
      'unit': i.unit,
      'unit_price': i.unitPrice,
      'total_price': i.totalPrice,
      'gst_rate': i.gstRate,
    }).toList();
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

    final bill = await db.transaction((txn) async {
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

    // Enqueue bill for cloud sync (no-op for offline licenses)
    await SyncService.instance.enqueue(
      tableName: 'bills_sync',
      recordId: bill.id.toString(),
      operation: SyncOperation.create,
      payload: {
        'local_bill_id': bill.id,
        'bill_number': bill.billNumber,
        'bill_type': bill.billType,
        'customer_name': bill.customerName,
        'customer_address': bill.customerAddress,
        'customer_gstin': bill.customerGstin,
        'total_amount': bill.totalAmount,
        'total_profit': bill.totalProfit,
        'discount_amount': bill.discountAmount,
        'gst_total': bill.gstTotal,
        'payment_mode': bill.paymentMode,
        'split_payment_summary': bill.splitPaymentSummary,
        'items_json': _billItemsPayload(bill.items),
        'created_at': bill.createdAt.toIso8601String(),
      },
    );

    return bill;
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

  @override
  Future<void> deleteBill(int id) async {
    final db = await _dbHelper.database;
    final now = DateTime.now();
    await db.transaction((txn) async {
      // Query bill items joined with products to get the correct stock quantities
      final billItemRows = await txn.rawQuery('''
        SELECT bi.product_id, bi.quantity, bi.sale_type, bi.conversion_qty,
               COALESCE(p.wholesale_to_retail_qty, 1.0) as wholesale_to_retail_qty
        FROM bill_items bi
        LEFT JOIN products p ON bi.product_id = p.id
        WHERE bi.bill_id = ?
      ''', [id]);
      for (final row in billItemRows) {
        final productId = row['product_id'] as int?;
        if (productId == null) continue;
        final quantity = (row['quantity'] as num).toDouble();
        final saleType = row['sale_type'] as String? ?? 'retail';
        final conversionQty = (row['conversion_qty'] as num?)?.toDouble() ?? 1.0;
        final wholesaleToRetailQty =
            (row['wholesale_to_retail_qty'] as num?)?.toDouble() ?? 1.0;
        // Mirror the deduction logic used in saveBill
        final double baseQtyToRestore;
        if (saleType == 'wholesale' && wholesaleToRetailQty > 1.0) {
          baseQtyToRestore = quantity * wholesaleToRetailQty;
        } else {
          baseQtyToRestore = quantity * conversionQty;
        }
        await txn.rawUpdate(
          'UPDATE products SET stock_quantity = stock_quantity + ?, updated_at = ? WHERE id = ?',
          [baseQtyToRestore, now.toIso8601String(), productId],
        );
      }
      await txn.delete('bill_items', where: 'bill_id = ?', whereArgs: [id]);
      await txn.delete('bill_payment_splits', where: 'bill_id = ?', whereArgs: [id]);
      await txn.delete('bills', where: 'id = ?', whereArgs: [id]);
    });
  }
}