import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

// ─── Input model ──────────────────────────────────────────────────────────────

/// One side of a double-entry bookkeeping line.
class LedgerEntryInput {
  /// One of: income, cogs, expense, inventory, asset, liability, waste
  final String accountType;

  /// 'debit' or 'credit'
  final String direction;

  /// Always positive. Direction is stored separately.
  final double amount;

  /// Optional: links the entry to a product/catalog item.
  final int? linkedItemId;

  /// Signed quantity change in base units.
  ///   positive = stock in  (purchase / return / opening stock)
  ///   negative = stock out (sale / waste)
  final double? quantityChange;

  const LedgerEntryInput({
    required this.accountType,
    required this.direction,
    required this.amount,
    this.linkedItemId,
    this.quantityChange,
  });
}

// ─── Service ──────────────────────────────────────────────────────────────────

/// LedgerService — writes erp_transactions + balanced ledger_entries.
///
/// Every business event creates exactly one erp_transaction and ≥2
/// ledger_entries where SUM(debit amounts) == SUM(credit amounts).
///
/// Use [recordTransaction] inside an existing sqflite [DatabaseExecutor]
/// (Database or Transaction) so it participates in the same atomic unit.
class LedgerService {
  static final LedgerService instance = LedgerService._();
  LedgerService._();

  /// Reads the persisted license_id. Falls back to 'local' when offline.
  Future<String> getLicenseId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('sb_license_id') ?? 'local';
  }

  /// Inserts one erp_transaction row and the provided [entries] into
  /// [executor]. Throws [ArgumentError] if the entries do not balance.
  ///
  /// Returns the new erp_transaction.id.
  Future<int> recordTransaction({
    required DatabaseExecutor executor,
    required String type,
    required double totalAmount,
    required Map<String, dynamic> tags,
    required String licenseId,
    required String createdAt,
    required List<LedgerEntryInput> entries,
  }) async {
    _assertBalanced(entries);

    final txnId = await executor.insert('erp_transactions', {
      'license_id': licenseId,
      'type': type,
      'total_amount': totalAmount,
      'tags': jsonEncode(tags),
      'created_at': createdAt,
      'updated_at': createdAt,
    });

    for (final e in entries) {
      await executor.insert('ledger_entries', {
        'transaction_id': txnId,
        'account_type': e.accountType,
        'direction': e.direction,
        'amount': e.amount,
        'linked_catalog_item_id': e.linkedItemId,
        'quantity_change': e.quantityChange,
        'created_at': createdAt,
      });
    }

    return txnId;
  }

  // ── Balance validation ─────────────────────────────────────────────────────

  void _assertBalanced(List<LedgerEntryInput> entries) {
    double debits = 0, credits = 0;
    for (final e in entries) {
      if (e.direction == 'debit') {
        debits += e.amount;
      } else {
        credits += e.amount;
      }
    }
    if ((debits - credits).abs() > 0.005) {
      throw ArgumentError(
          'Unbalanced ledger: debits=${debits.toStringAsFixed(3)}, '
          'credits=${credits.toStringAsFixed(3)}');
    }
  }
}
