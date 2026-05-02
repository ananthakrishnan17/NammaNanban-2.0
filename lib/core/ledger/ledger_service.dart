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

  // ── Validation ───────────────────────────────────────────────────────────
  /// Validates [entries] for double-entry accounting correctness.
  ///
  /// Rules enforced:
  ///   1. Every entry direction must be 'debit' or 'credit'.
  ///   2. At least one debit entry must be present.
  ///   3. At least one credit entry must be present.
  ///   4. Total debits must equal total credits (within [_balanceTolerance]).
  ///
  /// Throws [ArgumentError] for an invalid direction value.
  /// Throws [StateError] if any of rules 2-4 are violated.
  static void _validateEntries(List<LedgerEntryInput> entries) {
    for (final entry in entries) {
      if (entry.direction != 'debit' && entry.direction != 'credit') {
        throw ArgumentError(
            "LedgerEntryInput.direction must be 'debit' or 'credit', "
            "got '${entry.direction}'");
      }
    }
    bool hasDebit = false;
    bool hasCredit = false;
    double totalDebit = 0.0;
    double totalCredit = 0.0;
    for (final entry in entries) {
      if (entry.direction == 'debit') {
        hasDebit = true;
        totalDebit += entry.amount;
      } else {
        hasCredit = true;
        totalCredit += entry.amount;
      }
    }
    if (!hasDebit)  throw StateError('Ledger imbalance: no debit entry');
    if (!hasCredit) throw StateError('Ledger imbalance: no credit entry');
    if ((totalDebit - totalCredit).abs() > _balanceTolerance) {
      throw StateError(
          'Ledger imbalance: debit=$totalDebit credit=$totalCredit');
    }
  }

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
  }) {
    return recordTransaction(
      executor: txn,
      type: 'sale',
      totalAmount: totalAmount,
      licenseId: licenseId,
      entries: [
        LedgerEntryInput(accountType: 'asset',     direction: 'debit',  amount: totalAmount),
        LedgerEntryInput(accountType: 'income',    direction: 'credit', amount: totalAmount),
        if (totalCost > 0) ...[
          LedgerEntryInput(accountType: 'cogs',      direction: 'debit',  amount: totalCost),
          LedgerEntryInput(accountType: 'inventory', direction: 'credit', amount: totalCost),
        ],
      ],
      tags: tags,
    );
  }

  // ── Record a Purchase ────────────────────────────────────────────────────
  /// DR  inventory   = totalAmount
  /// CR  asset/liability (cash paid or payable) = totalAmount
  Future<int> recordPurchase({
    required DatabaseExecutor txn,
    required double totalAmount,
    required String licenseId,
    Map<String, dynamic> tags = const {},
  }) {
    return recordTransaction(
      executor: txn,
      type: 'purchase',
      totalAmount: totalAmount,
      licenseId: licenseId,
      entries: [
        LedgerEntryInput(accountType: 'inventory', direction: 'debit',  amount: totalAmount),
        LedgerEntryInput(accountType: 'asset',     direction: 'credit', amount: totalAmount),
      ],
      tags: tags,
    );
  }

  // ── Record an Expense ────────────────────────────────────────────────────
  /// DR  expense  = amount
  /// CR  asset    = amount
  Future<int> recordExpense({
    required DatabaseExecutor txn,
    required double amount,
    required String licenseId,
    Map<String, dynamic> tags = const {},
  }) {
    return recordTransaction(
      executor: txn,
      type: 'expense',
      totalAmount: amount,
      licenseId: licenseId,
      entries: [
        LedgerEntryInput(accountType: 'expense', direction: 'debit',  amount: amount),
        LedgerEntryInput(accountType: 'asset',   direction: 'credit', amount: amount),
      ],
      tags: tags,
    );
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
  }) {
    return recordTransaction(
      executor: txn,
      type: 'sale_return',
      totalAmount: returnAmount,
      licenseId: licenseId,
      entries: [
        LedgerEntryInput(accountType: 'income',    direction: 'debit',  amount: returnAmount),
        LedgerEntryInput(accountType: 'asset',     direction: 'credit', amount: returnAmount),
        if (returnCost > 0) ...[
          LedgerEntryInput(accountType: 'inventory', direction: 'debit',  amount: returnCost),
          LedgerEntryInput(accountType: 'cogs',      direction: 'credit', amount: returnCost),
        ],
      ],
      tags: tags,
    );
  }

  // ── Record a Purchase Return ─────────────────────────────────────────────
  /// DR  asset     = returnAmount
  /// CR  inventory = returnAmount
  Future<int> recordPurchaseReturn({
    required DatabaseExecutor txn,
    required double returnAmount,
    required String licenseId,
    Map<String, dynamic> tags = const {},
  }) {
    return recordTransaction(
      executor: txn,
      type: 'purchase_return',
      totalAmount: returnAmount,
      licenseId: licenseId,
      entries: [
        LedgerEntryInput(accountType: 'asset',     direction: 'debit',  amount: returnAmount),
        LedgerEntryInput(accountType: 'inventory', direction: 'credit', amount: returnAmount),
      ],
      tags: tags,
    );
  }

  // ── Generic transaction recorder ─────────────────────────────────────────
  /// Inserts one row into [erp_transactions] and one row per [LedgerEntryInput]
  /// into [ledger_entries].
  ///
  /// Throws [ArgumentError] for an invalid direction value.
  /// Throws [StateError] if entries lack a debit, lack a credit, or are
  /// unbalanced (total debit ≠ total credit, tolerance 0.01).
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
    _validateEntries(entries);

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
