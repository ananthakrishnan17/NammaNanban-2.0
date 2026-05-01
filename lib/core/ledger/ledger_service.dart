import 'dart:convert';
import 'package:sqflite/sqflite.dart';

/// Double-entry ledger writer.
///
/// Every business event (sale, purchase, expense, return) creates one row in
/// [erp_transactions] plus ≥ 2 balanced rows in [ledger_entries].
///
/// Debit increases asset / expense / cogs / waste accounts.
/// Credit increases income / liability accounts.
///
/// The service is stateless and relies on a passed-in [DatabaseExecutor] so it
/// can participate in an existing SQLite transaction started by the caller.
class LedgerService {
  static final LedgerService instance = LedgerService._();
  LedgerService._();

  // ── Record a Sale ────────────────────────────────────────────────────────
  /// Creates an erp_transaction of type 'sale' and the corresponding
  /// double-entry ledger entries:
  ///   DR  asset (cash/receivable)   = totalAmount
  ///   CR  income                    = totalAmount
  ///   DR  cogs                      = totalCost
  ///   CR  inventory                 = totalCost
  Future<int> recordSale({
    required DatabaseExecutor txn,
    required double totalAmount,
    required double totalCost,
    required String licenseId,
    Map<String, dynamic> tags = const {},
  }) async {
    final now = DateTime.now().toIso8601String();
    final txId = await txn.insert('erp_transactions', {
      'license_id': licenseId,
      'type': 'sale',
      'total_amount': totalAmount,
      'tags': jsonEncode(tags),
      'created_at': now,
      'updated_at': now,
    });

    await _insertEntry(txn, txId, 'asset',     'debit',  totalAmount, now);
    await _insertEntry(txn, txId, 'income',    'credit', totalAmount, now);
    if (totalCost > 0) {
      await _insertEntry(txn, txId, 'cogs',      'debit',  totalCost,   now);
      await _insertEntry(txn, txId, 'inventory', 'credit', totalCost,   now);
    }
    return txId;
  }

  // ── Record a Purchase ────────────────────────────────────────────────────
  /// DR  inventory   = totalAmount
  /// CR  asset/liability (cash paid or payable) = totalAmount
  Future<int> recordPurchase({
    required DatabaseExecutor txn,
    required double totalAmount,
    required String licenseId,
    Map<String, dynamic> tags = const {},
  }) async {
    final now = DateTime.now().toIso8601String();
    final txId = await txn.insert('erp_transactions', {
      'license_id': licenseId,
      'type': 'purchase',
      'total_amount': totalAmount,
      'tags': jsonEncode(tags),
      'created_at': now,
      'updated_at': now,
    });

    await _insertEntry(txn, txId, 'inventory', 'debit',  totalAmount, now);
    await _insertEntry(txn, txId, 'asset',     'credit', totalAmount, now);
    return txId;
  }

  // ── Record an Expense ────────────────────────────────────────────────────
  /// DR  expense  = amount
  /// CR  asset    = amount
  Future<int> recordExpense({
    required DatabaseExecutor txn,
    required double amount,
    required String licenseId,
    Map<String, dynamic> tags = const {},
  }) async {
    final now = DateTime.now().toIso8601String();
    final txId = await txn.insert('erp_transactions', {
      'license_id': licenseId,
      'type': 'expense',
      'total_amount': amount,
      'tags': jsonEncode(tags),
      'created_at': now,
      'updated_at': now,
    });

    await _insertEntry(txn, txId, 'expense', 'debit',  amount, now);
    await _insertEntry(txn, txId, 'asset',   'credit', amount, now);
    return txId;
  }

  // ── Record a Sale Return ─────────────────────────────────────────────────
  /// Reverses a sale:
  ///   DR  income    = returnAmount  (revenue reversal)
  ///   CR  asset     = returnAmount
  ///   DR  inventory = returnCost    (stock restored)
  ///   CR  cogs      = returnCost
  Future<int> recordSaleReturn({
    required DatabaseExecutor txn,
    required double returnAmount,
    required double returnCost,
    required String licenseId,
    Map<String, dynamic> tags = const {},
  }) async {
    final now = DateTime.now().toIso8601String();
    final txId = await txn.insert('erp_transactions', {
      'license_id': licenseId,
      'type': 'sale_return',
      'total_amount': returnAmount,
      'tags': jsonEncode(tags),
      'created_at': now,
      'updated_at': now,
    });

    await _insertEntry(txn, txId, 'income',    'debit',  returnAmount, now);
    await _insertEntry(txn, txId, 'asset',     'credit', returnAmount, now);
    if (returnCost > 0) {
      await _insertEntry(txn, txId, 'inventory', 'debit',  returnCost, now);
      await _insertEntry(txn, txId, 'cogs',      'credit', returnCost, now);
    }
    return txId;
  }

  // ── Record a Purchase Return ─────────────────────────────────────────────
  /// DR  asset     = returnAmount
  /// CR  inventory = returnAmount
  Future<int> recordPurchaseReturn({
    required DatabaseExecutor txn,
    required double returnAmount,
    required String licenseId,
    Map<String, dynamic> tags = const {},
  }) async {
    final now = DateTime.now().toIso8601String();
    final txId = await txn.insert('erp_transactions', {
      'license_id': licenseId,
      'type': 'purchase_return',
      'total_amount': returnAmount,
      'tags': jsonEncode(tags),
      'created_at': now,
      'updated_at': now,
    });

    await _insertEntry(txn, txId, 'asset',     'debit',  returnAmount, now);
    await _insertEntry(txn, txId, 'inventory', 'credit', returnAmount, now);
    return txId;
  }

  // ── Internal helpers ──────────────────────────────────────────────────────
  Future<void> _insertEntry(
    DatabaseExecutor txn,
    int transactionId,
    String accountType,
    String direction,
    double amount,
    String now,
  ) async {
    await txn.insert('ledger_entries', {
      'transaction_id': transactionId,
      'account_type': accountType,
      'direction': direction,
      'amount': amount,
      'created_at': now,
    });
  }

  // ── Helpers for callers without a cached license ID ───────────────────────
  /// Returns the cached license ID, or 'local' as fallback.
  static Future<String> resolveLicenseId(dynamic dbHelper) async {
    try {
      final db = await dbHelper.database as dynamic;
      final rows = await db.query('license_cache', limit: 1) as List;
      if (rows.isNotEmpty) return rows.first['id'] as String? ?? 'local';
    } catch (_) {}
    return 'local';
  }
}
