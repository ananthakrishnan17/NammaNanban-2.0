import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import '../../../../core/database/database_helper.dart';
import '../../../../core/ledger/ledger_service.dart';

// ─── Entities ─────────────────────────────────────────────────────────────────
class PurchaseItem extends Equatable {
  final int? id;
  final int purchaseId;
  final int productId;
  final String productName;
  final double quantity;
  final String unit;
  final double unitCost;
  final double gstRate;
  final double gstAmount;
  final double totalCost;

  const PurchaseItem({this.id, required this.purchaseId, required this.productId,
    required this.productName, required this.quantity, required this.unit,
    required this.unitCost, this.gstRate = 0, this.gstAmount = 0, required this.totalCost});

  factory PurchaseItem.fromMap(Map<String, dynamic> m) => PurchaseItem(
      id: m['id'], purchaseId: m['purchase_id'], productId: m['product_id'],
      productName: m['product_name'], quantity: (m['quantity'] as num).toDouble(),
      unit: m['unit'], unitCost: (m['unit_cost'] as num).toDouble(),
      gstRate: (m['gst_rate'] as num?)?.toDouble() ?? 0,
      gstAmount: (m['gst_amount'] as num?)?.toDouble() ?? 0,
      totalCost: (m['total_cost'] as num).toDouble());

  Map<String, dynamic> toMap() => {'purchase_id': purchaseId, 'product_id': productId,
    'product_name': productName, 'quantity': quantity, 'unit': unit,
    'unit_cost': unitCost, 'gst_rate': gstRate, 'gst_amount': gstAmount, 'total_cost': totalCost};

  @override List<Object?> get props => [id, productId, quantity];
}

class Purchase extends Equatable {
  final int? id;
  final String purchaseNumber;
  final int? supplierId;
  final String? supplierName;
  final List<PurchaseItem> items;
  final double totalAmount;
  final double gstTotal;
  final double discountAmount;
  final String paymentMode;
  final String? notes;
  final DateTime purchaseDate;
  final DateTime createdAt;

  const Purchase({this.id, required this.purchaseNumber, this.supplierId,
    this.supplierName, required this.items, required this.totalAmount,
    this.gstTotal = 0, this.discountAmount = 0, this.paymentMode = 'cash',
    this.notes, required this.purchaseDate, required this.createdAt});

  factory Purchase.fromMap(Map<String, dynamic> m, List<PurchaseItem> items) => Purchase(
      id: m['id'], purchaseNumber: m['purchase_number'], supplierId: m['supplier_id'],
      supplierName: m['supplier_name'], items: items,
      totalAmount: (m['total_amount'] as num).toDouble(),
      gstTotal: (m['gst_total'] as num?)?.toDouble() ?? 0,
      discountAmount: (m['discount_amount'] as num?)?.toDouble() ?? 0,
      paymentMode: m['payment_mode'] ?? 'cash', notes: m['notes'],
      purchaseDate: DateTime.parse(m['purchase_date']),
      createdAt: DateTime.parse(m['created_at']));

  Map<String, dynamic> toMap() => {
    'purchase_number': purchaseNumber, 'supplier_id': supplierId, 'supplier_name': supplierName,
    'total_amount': totalAmount, 'gst_total': gstTotal, 'discount_amount': discountAmount,
    'payment_mode': paymentMode, 'notes': notes,
    'purchase_date': purchaseDate.toIso8601String(), 'created_at': createdAt.toIso8601String()};

  @override List<Object?> get props => [id, purchaseNumber];
}

// ─── Cart item for purchase entry ─────────────────────────────────────────────
class PurchaseCartItem {
  final int productId;
  final String productName;
  final String unit;
  double quantity;
  double unitCost;
  double gstRate;
  // Batch tracking fields — used to create a batches row on save so that
  // billing can apply FEFO (First Expiry First Out) during stock deduction.
  final String? batchNumber;
  final DateTime? expiryDate;

  PurchaseCartItem({required this.productId, required this.productName,
    required this.unit, this.quantity = 1, required this.unitCost, this.gstRate = 0,
    this.batchNumber, this.expiryDate});

  double get gstAmount => unitCost * quantity * gstRate / 100;
  double get totalCost => unitCost * quantity + gstAmount;
}

// ─── Repository ────────────────────────────────────────────────────────────────
class PurchaseRepository {
  final DatabaseHelper _db;
  PurchaseRepository(this._db);
  int _counter = 0;

  String _genNumber() {
    final now = DateTime.now();
    _counter++;
    return 'PUR-${now.year}${now.month.toString().padLeft(2,'0')}${now.day.toString().padLeft(2,'0')}-${_counter.toString().padLeft(3,'0')}';
  }

  Future<Purchase> savePurchase({
    required List<PurchaseCartItem> items,
    int? supplierId, String? supplierName,
    String paymentMode = 'cash', String? notes,
    DateTime? purchaseDate,
  }) async {
    final db = await _db.database;
    final now = DateTime.now();
    final nowStr = now.toIso8601String();
    final date = purchaseDate ?? now;

    double total = items.fold(0.0, (s, i) => s + i.totalCost);
    double gstTotal = items.fold(0.0, (s, i) => s + i.gstAmount);

    // IMPORTANT: resolve licenseId BEFORE the transaction to prevent sqflite
    // deadlock — resolveLicenseId opens the main DB connection, which conflicts
    // with the exclusive lock held by db.transaction().
    final licenseId = await LedgerService.resolveLicenseId(_db);

    return db.transaction((txn) async {
      final purchaseId = await txn.insert('purchases', {
        'purchase_number': _genNumber(), 'supplier_id': supplierId,
        'supplier_name': supplierName, 'total_amount': total, 'gst_total': gstTotal,
        'discount_amount': 0, 'payment_mode': paymentMode, 'notes': notes,
        'purchase_date': date.toIso8601String(), 'created_at': nowStr,
      });

      final purchaseItems = <PurchaseItem>[];
      // Tracks the stock increment (in base units) for each product.
      // Used twice: (1) directly in per-item ledger debit entries, and
      // (2) as the aggregate quantity if debit entries need consolidation
      // to eliminate GST-rounding drift against the credit total.
      final Map<int, double> productBaseQtyMap = {};

      for (final item in items) {
        final itemId = await txn.insert('purchase_items', {
          'purchase_id': purchaseId, 'product_id': item.productId,
          'product_name': item.productName, 'quantity': item.quantity,
          'unit': item.unit, 'unit_cost': item.unitCost, 'gst_rate': item.gstRate,
          'gst_amount': item.gstAmount, 'total_cost': item.totalCost,
        });
        // Update stock — convert wholesale units to retail units if configured
        final productRows = await txn.query('products',
            columns: ['wholesale_to_retail_qty'],
            where: 'id = ?', whereArgs: [item.productId]);
        final wholesaleToRetailQty = productRows.isNotEmpty
            ? (productRows.first['wholesale_to_retail_qty'] as num?)?.toDouble() ?? 1.0
            : 1.0;
        final stockIncrement = wholesaleToRetailQty > 1.0
            ? item.quantity * wholesaleToRetailQty
            : item.quantity;
        await txn.rawUpdate('UPDATE products SET stock_quantity = stock_quantity + ?, updated_at = ? WHERE id = ?',
            [stockIncrement, nowStr, item.productId]);
        // Update purchase price
        await txn.rawUpdate('UPDATE products SET purchase_price = ?, updated_at = ? WHERE id = ?',
            [item.unitCost, nowStr, item.productId]);

        // ── Batch entry for FEFO tracking ─────────────────────────────────
        // Each purchase line creates one batch row.  Billing will drain
        // qty_remaining from the batch with the earliest expiry_date first
        // (FEFO). Storing unit_cost here enables accurate COGS per batch.
        await txn.insert('batches', {
          'product_id': item.productId,
          'purchase_id': purchaseId,
          'batch_number': item.batchNumber,
          'expiry_date': item.expiryDate?.toIso8601String().substring(0, 10),
          'qty_in': stockIncrement,
          'qty_remaining': stockIncrement,
          'unit_cost': item.unitCost,
          'created_at': nowStr,
        });

        productBaseQtyMap[item.productId] = stockIncrement;
        purchaseItems.add(PurchaseItem(id: itemId, purchaseId: purchaseId,
            productId: item.productId, productName: item.productName,
            quantity: item.quantity, unit: item.unit, unitCost: item.unitCost,
            gstRate: item.gstRate, gstAmount: item.gstAmount, totalCost: item.totalCost));
      }

      // ── Double-entry ledger ─────────────────────────────────────────────
      // Purchase journal:
      //   DR Inventory   total (stock in — consolidated to match credit exactly)
      //   CR Asset/Liability   total (cash paid or credit payable)
      //
      // ATOMICITY: no try/catch — ledger failure rolls back the whole
      // transaction (purchase record + items + stock updates).
      final ledger = LedgerService.instance;
      final creditType = paymentMode == 'credit' ? 'liability' : 'asset';

      // Build per-item debit entries; if their sum mismatches total (GST
      // rounding), collapse into a single consolidated debit for balance.
      final ledgerEntries = <LedgerEntryInput>[];
      for (final pi in purchaseItems) {
        ledgerEntries.add(LedgerEntryInput(
          accountType: 'inventory', direction: 'debit',
          amount: pi.totalCost,
          quantityChange: productBaseQtyMap[pi.productId],
        ));
      }
      // CR asset/liability = full invoice total
      ledgerEntries.add(LedgerEntryInput(
        accountType: creditType, direction: 'credit', amount: total,
      ));

      // Collapse debit side if rounding drift > 0.5 paisa
      final debitSum = ledgerEntries
          .where((e) => e.direction == 'debit')
          .fold(0.0, (s, e) => s + e.amount);
      if ((debitSum - total).abs() > 0.005) {
        final totalBaseQty =
            productBaseQtyMap.values.fold(0.0, (s, q) => s + q);
        ledgerEntries.removeWhere((e) => e.direction == 'debit');
        ledgerEntries.add(LedgerEntryInput(
          accountType: 'inventory', direction: 'debit',
          amount: total, quantityChange: totalBaseQty,
        ));
      }

      await ledger.recordTransaction(
        executor: txn,
        type: 'purchase',
        totalAmount: total,
        tags: {
          'purchase_id': purchaseId,
          'supplier_name': supplierName,
          'payment_mode': paymentMode,
          'notes': notes,
        },
        licenseId: licenseId,
        createdAt: nowStr,
        entries: ledgerEntries,
      );

      return Purchase(id: purchaseId, purchaseNumber: 'PUR-$purchaseId',
          supplierId: supplierId, supplierName: supplierName, items: purchaseItems,
          totalAmount: total, gstTotal: gstTotal, paymentMode: paymentMode,
          notes: notes, purchaseDate: date, createdAt: now);
    });
  }

  Future<List<Purchase>> getRecentPurchases({int limit = 50}) async {
    final db = await _db.database;
    final rows = await db.query('purchases', orderBy: 'created_at DESC', limit: limit);
    final purchases = <Purchase>[];
    for (final row in rows) {
      final items = await db.query('purchase_items', where: 'purchase_id=?', whereArgs: [row['id']]);
      purchases.add(Purchase.fromMap(row, items.map((i) => PurchaseItem.fromMap(i)).toList()));
    }
    return purchases;
  }
}

// ─── Events + States + BLoC ────────────────────────────────────────────────────
abstract class PurchaseEvent extends Equatable { @override List<Object?> get props => []; }
class LoadPurchases extends PurchaseEvent {}
class SavePurchaseEvent extends PurchaseEvent {
  final List<PurchaseCartItem> items;
  final int? supplierId; final String? supplierName;
  final String paymentMode; final String? notes; final DateTime? purchaseDate;
  SavePurchaseEvent({required this.items, this.supplierId, this.supplierName,
    this.paymentMode = 'cash', this.notes, this.purchaseDate});
  @override List<Object?> get props => [items];
}

class PurchaseState extends Equatable {
  final List<Purchase> purchases;
  final bool isLoading; final bool isSaving; final String? error; final Purchase? lastSaved;
  const PurchaseState({this.purchases = const [], this.isLoading = false,
    this.isSaving = false, this.error, this.lastSaved});
  PurchaseState copyWith({List<Purchase>? purchases, bool? isLoading, bool? isSaving, String? error, Purchase? lastSaved}) =>
      PurchaseState(purchases: purchases ?? this.purchases, isLoading: isLoading ?? this.isLoading,
          isSaving: isSaving ?? this.isSaving, error: error, lastSaved: lastSaved ?? this.lastSaved);
  @override List<Object?> get props => [purchases, isLoading, isSaving, lastSaved];
}

class PurchaseBloc extends Bloc<PurchaseEvent, PurchaseState> {
  final PurchaseRepository _repo;
  PurchaseBloc(this._repo) : super(const PurchaseState()) {
    on<LoadPurchases>(_onLoad);
    on<SavePurchaseEvent>(_onSave);
  }

  Future<void> _onLoad(LoadPurchases e, Emitter<PurchaseState> emit) async {
    emit(state.copyWith(isLoading: true));
    try {
      final purchases = await _repo.getRecentPurchases();
      emit(state.copyWith(purchases: purchases, isLoading: false));
    } catch (err) { emit(state.copyWith(isLoading: false, error: err.toString())); }
  }

  Future<void> _onSave(SavePurchaseEvent e, Emitter<PurchaseState> emit) async {
    emit(state.copyWith(isSaving: true));
    try {
      final purchase = await _repo.savePurchase(items: e.items, supplierId: e.supplierId,
          supplierName: e.supplierName, paymentMode: e.paymentMode, notes: e.notes, purchaseDate: e.purchaseDate);
      emit(state.copyWith(isSaving: false, lastSaved: purchase));
      add(LoadPurchases());
    } catch (err) { emit(state.copyWith(isSaving: false, error: err.toString())); }
  }
}