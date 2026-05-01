import 'dart:convert';
import 'package:sqflite/sqflite.dart';

import '../database/database_helper.dart';

/// Input descriptor for a single ledger line inside [LedgerService.recordTransaction].
class LedgerEntryInput {
  final String accountType;
  final String direction; // 'debit' or 'credit'
  final double amount;
  final int? linkedCatalogItemId;
  final double? quantityChange;

  const LedgerEntryInput({
    required this.accountType,
    required this.direction,
    required this.amount,
    this.linkedCatalogItemId,
    this.quantityChange,
  });
}

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

  /// Floating-point tolerance for debit/credit balance validation.
  static const double _balanceTolerance = 0.01;

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

  // ── Generic transaction recorder ─────────────────────────────────────────
  /// Inserts one row into [erp_transactions] and one row per [LedgerEntryInput]
  /// into [ledger_entries].
  ///
  /// Throws [StateError] if the entries are not balanced
  /// (total debit amount ≠ total credit amount, tolerance 0.01).
  ///
  /// [executor] may be a raw [Database] or an active sqflite [Transaction] so
  /// the caller can compose this write inside a larger transaction.
  Future<int> recordTransaction({
    required DatabaseExecutor executor,
    required String type,
    required double totalAmount,
    required String licenseId,
    required List<LedgerEntryInput> entries,
    Map<String, dynamic> tags = const {},
    String? createdAt,
  }) async {
    for (final entry in entries) {
      if (entry.direction != 'debit' && entry.direction != 'credit') {
        throw ArgumentError(
            "LedgerEntryInput.direction must be 'debit' or 'credit', "
            "got '${entry.direction}'");
      }
    }
    final totalDebit = entries
        .where((e) => e.direction == 'debit')
        .fold(0.0, (s, e) => s + e.amount);
    final totalCredit = entries
        .where((e) => e.direction == 'credit')
        .fold(0.0, (s, e) => s + e.amount);
    if ((totalDebit - totalCredit).abs() > _balanceTolerance) {
      throw StateError(
          'Ledger imbalance: debit=$totalDebit credit=$totalCredit');
    }

    final now = createdAt ?? DateTime.now().toIso8601String();
    final txId = await executor.insert('erp_transactions', {
      'license_id': licenseId,
      'type': type,
      'total_amount': totalAmount,
      'tags': jsonEncode(tags),
      'created_at': now,
      'updated_at': now,
    });

    for (final entry in entries) {
      await executor.insert('ledger_entries', {
        'transaction_id': txId,
        'account_type': entry.accountType,
        'direction': entry.direction,
        'amount': entry.amount,
        if (entry.linkedCatalogItemId != null)
          'linked_catalog_item_id': entry.linkedCatalogItemId,
        if (entry.quantityChange != null)
          'quantity_change': entry.quantityChange,
        'created_at': now,
      });
    }
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
  static Future<String> resolveLicenseId(DatabaseHelper dbHelper) async {
    try {
      final db = await dbHelper.database;
      final rows = await db.query('license_cache', limit: 1);
      if (rows.isNotEmpty) return rows.first['id'] as String? ?? 'local';
    } catch (_) {}
    return 'local';
  }
}
