import 'dart:convert';

import '../../../../core/database/database_helper.dart';
import '../../../../core/ledger/ledger_service.dart';
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
  Future<Bill> getBillById(int id);
  Future<List<Bill>> getAllBills({DateTime? fromDate, DateTime? toDate});
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
    bool isInterState = false,  // FIX BUG#2: pass true for inter-state (IGST) transactions
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

    // FIX BUG#4: clamp so totalAmount can never go negative
    double totalAmount = (items.fold(0.0, (s, i) => s + i.totalFor(bt)) - discountAmount)
        .clamp(0.0, double.infinity);
    double totalProfit = items.fold(0.0, (s, i) => s + i.profitFor(bt));
    double gstTotal = items.fold(0.0, (s, i) => s + i.gstAmountFor(bt));

    // FIX BUG#2: split GST correctly based on transaction type
    final double cgstAmount = isInterState ? 0.0 : gstTotal / 2;
    final double sgstAmount = isInterState ? 0.0 : gstTotal / 2;
    final double igstAmount = isInterState ? gstTotal : 0.0;

    // FIX BUG#1: generate bill number ONCE and reuse for both DB insert and returned object
    final String billNum = _genBillNumber();

    final bill = await db.transaction((txn) async {
      final billId = await txn.insert('bills', {
        'bill_number': billNum, 'bill_type': billType,  // FIX BUG#1
        'customer_id': customerId, 'customer_name': customerName,
        'customer_address': customerAddress, 'customer_gstin': customerGstin,
        'total_amount': totalAmount, 'total_profit': totalProfit,
        'discount_amount': discountAmount, 'gst_total': gstTotal,
        'cgst_total': cgstAmount, 'sgst_total': sgstAmount, 'igst_total': igstAmount,  // FIX BUG#2
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

        // BOM deduction: if composite_recipe, deduct each ingredient's stock
        try {
          final productRows = await txn.query('products',
              columns: ['item_type', 'attributes'],
              where: 'id = ?', whereArgs: [cartItem.productId]);
          if (productRows.isNotEmpty &&
              productRows.first['item_type'] == 'composite_recipe') {
            final attrStr = productRows.first['attributes'] as String? ?? '{}';
            final attrs = jsonDecode(attrStr) as Map<String, dynamic>? ?? {};
            final bom = (attrs['bom'] as List<dynamic>?) ?? [];
            for (final ing in bom) {
              final ingMap = ing as Map<String, dynamic>;
              final ingId = ingMap['product_id'] as int?;
              final ingQty = (ingMap['quantity'] as num?)?.toDouble() ?? 0;
              if (ingId != null && ingQty > 0) {
                final totalIngQty = ingQty * baseQtyToDeduct;
                await txn.rawUpdate(
                    'UPDATE products SET stock_quantity = stock_quantity - ?, updated_at = ? WHERE id = ?',
                    [totalIngQty, now.toIso8601String(), ingId]);
              }
            }
          }
        } catch (_) {}

        billItems.add(BillItem(id: itemId, billId: billId, productId: cartItem.productId,
            productName: cartItem.productName, quantity: cartItem.quantity, unit: cartItem.unit,
            unitPrice: effectivePrice, purchasePrice: cartItem.purchasePrice,
            gstRate: cartItem.gstRate, gstAmount: gstAmt, totalPrice: itemTotal));
      }

      // ── Double-entry ledger ─────────────────────────────────────────────
      // Sale journal:
      //   DR Asset (cash/bank)     totalAmount
      //   CR Income (sales)        totalAmount
      //   DR COGS                  totalCOGS  (per item: purchasePrice × baseQty)
      //   CR Inventory             totalCOGS
      try {
        final ledger = LedgerService.instance;
        final licenseId = await ledger.getLicenseId();
        final nowStr = now.toIso8601String();

        final ledgerEntries = <LedgerEntryInput>[];

        for (final cartItem in items) {
          final double baseQty;
          if (cartItem.saleType == SaleType.wholesale && cartItem.wholesaleToRetailQty > 1.0) {
            baseQty = cartItem.quantity * cartItem.wholesaleToRetailQty;
          } else {
            baseQty = cartItem.quantity * cartItem.conversionQty;
          }
          final cogs = cartItem.purchasePrice * baseQty;
          if (cogs > 0) {
            ledgerEntries.add(LedgerEntryInput(
              accountType: 'cogs', direction: 'debit', amount: cogs,
              quantityChange: -baseQty,
            ));
            ledgerEntries.add(LedgerEntryInput(
              accountType: 'inventory', direction: 'credit', amount: cogs,
              quantityChange: -baseQty,
            ));
          }
        }

        // DR Asset = totalAmount (cash/bank received)
        // CR Income = totalAmount
        ledgerEntries.addAll([
          LedgerEntryInput(accountType: 'asset', direction: 'debit', amount: totalAmount),
          LedgerEntryInput(accountType: 'income', direction: 'credit', amount: totalAmount),
        ]);

        // Adjust: if COGS entries are present, they are balanced within
        // themselves (each item has paired cogs-debit + inventory-credit).

        await ledger.recordTransaction(
          executor: txn,
          type: 'sale',
          totalAmount: totalAmount,
          tags: {
            'bill_number': billNum,
            'bill_id': billId,
            'customer_name': customerName,
            'payment_mode': effectivePaymentMode,
            'discount_amount': discountAmount,
          },
          licenseId: licenseId,
          createdAt: nowStr,
          entries: ledgerEntries,
        );
      } catch (_) {
        // Ledger write failure must NOT block the sale — re-throw so
        // the transaction rolls back to keep data consistent.
        rethrow;
      }

      return Bill(id: billId, billNumber: billNum, billType: billType,  // FIX BUG#1
          items: billItems, totalAmount: totalAmount, totalProfit: totalProfit,
          discountAmount: discountAmount, gstTotal: gstTotal, cgstTotal: cgstAmount,
          sgstTotal: sgstAmount, igstTotal: igstAmount,  // FIX BUG#2
          paymentMode: effectivePaymentMode,
          splitPaymentSummary: splitSummary,
          customerId: customerId,
          customerName: customerName, customerAddress: customerAddress,
          customerGstin: customerGstin, createdAt: now);
    });

    // Write double-entry ledger (best-effort; never fails the sale)
    try {
      final db2 = await _dbHelper.database;
      final licenseId = await LedgerService.resolveLicenseId(_dbHelper);
      await db2.transaction((txn) async {
        await LedgerService.instance.recordSale(
          txn: txn,
          totalAmount: bill.totalAmount,
          totalCost: items.fold(0.0, (s, i) => s + i.purchasePrice * i.quantity * i.conversionQty),
          licenseId: licenseId,
          tags: {
            'bill_number': bill.billNumber,
            'bill_type': bill.billType,
            'payment_mode': bill.paymentMode,
            'customer_name': bill.customerName,
          },
        );
      });
    } catch (_) {}

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
  Future<Bill> getBillById(int id) async {
    final db = await _dbHelper.database;
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

  @override
  Future<List<Bill>> getAllBills({DateTime? fromDate, DateTime? toDate}) async {
    final db = await _dbHelper.database;
    String? where;
    List<dynamic>? whereArgs;
    if (fromDate != null && toDate != null) {
      where = 'created_at BETWEEN ? AND ?';
      whereArgs = [fromDate.toIso8601String(), toDate.toIso8601String()];
    } else if (fromDate != null) {
      where = 'created_at >= ?';
      whereArgs = [fromDate.toIso8601String()];
    } else if (toDate != null) {
      where = 'created_at <= ?';
      whereArgs = [toDate.toIso8601String()];
    }
    final rows = await db.query(
      'bills',
      where: where,
      whereArgs: whereArgs,
      orderBy: 'created_at DESC',
    );
    return rows.map((r) => Bill(
      id: r['id'] as int,
      billNumber: r['bill_number'] as String,
      billType: r['bill_type'] as String? ?? 'retail',
      items: [],
      totalAmount: (r['total_amount'] as num).toDouble(),
      totalProfit: (r['total_profit'] as num?)?.toDouble() ?? 0.0,
      discountAmount: (r['discount_amount'] as num?)?.toDouble() ?? 0.0,
      gstTotal: (r['gst_total'] as num?)?.toDouble() ?? 0.0,
      paymentMode: r['payment_mode'] as String? ?? 'cash',
      splitPaymentSummary: r['split_payment_summary'] as String?,
      customerName: r['customer_name'] as String?,
      customerAddress: r['customer_address'] as String?,
      customerGstin: r['customer_gstin'] as String?,
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