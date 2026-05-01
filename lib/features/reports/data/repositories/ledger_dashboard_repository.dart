import 'dart:convert';
import '../../../../core/database/database_helper.dart';

// ─── Data models ──────────────────────────────────────────────────────────────

class LedgerTransaction {
  final int id;
  final String type;
  final double totalAmount;
  final Map<String, dynamic> tags;
  final DateTime createdAt;
  final List<LedgerEntry> entries;

  const LedgerTransaction({
    required this.id,
    required this.type,
    required this.totalAmount,
    required this.tags,
    required this.createdAt,
    required this.entries,
  });

  /// Total debit amount across all entries.
  double get debitTotal =>
      entries.where((e) => e.direction == 'debit').fold(0.0, (s, e) => s + e.amount);

  /// Total credit amount across all entries.
  double get creditTotal =>
      entries.where((e) => e.direction == 'credit').fold(0.0, (s, e) => s + e.amount);

  /// True when debit == credit (within rounding tolerance).
  bool get isBalanced => (debitTotal - creditTotal).abs() < 0.01;
}

class LedgerEntry {
  final int id;
  final int transactionId;
  final String accountType;
  final String direction;
  final double amount;
  final double? quantityChange;
  final DateTime createdAt;

  const LedgerEntry({
    required this.id,
    required this.transactionId,
    required this.accountType,
    required this.direction,
    required this.amount,
    this.quantityChange,
    required this.createdAt,
  });

  factory LedgerEntry.fromMap(Map<String, dynamic> m) => LedgerEntry(
        id: m['id'] as int,
        transactionId: m['transaction_id'] as int,
        accountType: m['account_type'] as String,
        direction: m['direction'] as String? ?? 'debit',
        amount: (m['amount'] as num).toDouble(),
        quantityChange: (m['quantity_change'] as num?)?.toDouble(),
        createdAt: DateTime.parse(m['created_at'] as String),
      );
}

class LedgerSummary {
  final double totalSales;
  final double totalPurchases;
  final double totalExpenses;
  final double totalWaste;
  final double grossProfit;
  final double netProfit;
  final double inventoryValue;
  final double cashBalance;

  const LedgerSummary({
    required this.totalSales,
    required this.totalPurchases,
    required this.totalExpenses,
    required this.totalWaste,
    required this.grossProfit,
    required this.netProfit,
    required this.inventoryValue,
    required this.cashBalance,
  });
}

// ─── Repository ───────────────────────────────────────────────────────────────

class LedgerDashboardRepository {
  final DatabaseHelper _db;
  LedgerDashboardRepository(this._db);

  /// Returns summary figures aggregated from ledger_entries for the given date
  /// range. Figures are meaningful only after flows have been connected.
  Future<LedgerSummary> getSummary({
    required DateTime from,
    required DateTime to,
  }) async {
    final db = await _db.database;
    final fromStr = from.toIso8601String();
    final toStr = to.toIso8601String();

    // Aggregate all ledger_entries in range by (account_type, direction)
    final rows = await db.rawQuery('''
      SELECT le.account_type, le.direction, COALESCE(SUM(le.amount), 0) AS total
      FROM ledger_entries le
      JOIN erp_transactions et ON et.id = le.transaction_id
      WHERE le.created_at BETWEEN ? AND ?
      GROUP BY le.account_type, le.direction
    ''', [fromStr, toStr]);

    // Build a map: (account_type, direction) → total
    final agg = <String, double>{};
    for (final r in rows) {
      final key = '${r['account_type']}_${r['direction']}';
      agg[key] = (r['total'] as num).toDouble();
    }

    // Sales income = credit entries on 'income' account
    final salesIncome = agg['income_credit'] ?? 0;
    // Sales return deductions = debit entries on 'income' account (reversal)
    final salesReturnDeductions = agg['income_debit'] ?? 0;
    final netSales = salesIncome - salesReturnDeductions;

    // COGS = debit entries on 'cogs' account (minus credit reversals from returns)
    final cogsDebit = agg['cogs_debit'] ?? 0;
    final cogsCredit = agg['cogs_credit'] ?? 0;
    final netCOGS = cogsDebit - cogsCredit;

    // Expenses = debit entries on 'expense' account
    final expenses = agg['expense_debit'] ?? 0;

    // Waste = debit entries on 'waste' account
    final waste = agg['waste_debit'] ?? 0;

    final grossProfit = netSales - netCOGS;
    final netProfit = grossProfit - expenses - waste;

    // Total purchases = credit on asset/liability from purchase transactions
    final rows2 = await db.rawQuery('''
      SELECT COALESCE(SUM(et.total_amount), 0) AS total
      FROM erp_transactions et
      WHERE et.type = 'purchase' AND et.created_at BETWEEN ? AND ?
    ''', [fromStr, toStr]);
    final totalPurchases = (rows2.first['total'] as num).toDouble();

    // Inventory value = net inventory debit
    final inventoryDebit = agg['inventory_debit'] ?? 0;
    final inventoryCredit = agg['inventory_credit'] ?? 0;
    final inventoryValue = inventoryDebit - inventoryCredit;

    // Cash/bank balance = net asset debit (cash in) minus asset credit (cash out)
    final assetDebit = agg['asset_debit'] ?? 0;
    final assetCredit = agg['asset_credit'] ?? 0;
    final cashBalance = assetDebit - assetCredit;

    return LedgerSummary(
      totalSales: netSales,
      totalPurchases: totalPurchases,
      totalExpenses: expenses,
      totalWaste: waste,
      grossProfit: grossProfit,
      netProfit: netProfit,
      inventoryValue: inventoryValue > 0 ? inventoryValue : 0,
      cashBalance: cashBalance,
    );
  }

  /// Returns paginated list of transactions, optionally filtered by type.
  Future<List<LedgerTransaction>> getTransactions({
    required DateTime from,
    required DateTime to,
    String? type,
    int limit = 50,
    int offset = 0,
  }) async {
    final db = await _db.database;
    final fromStr = from.toIso8601String();
    final toStr = to.toIso8601String();

    String where = 'created_at BETWEEN ? AND ?';
    final args = <dynamic>[fromStr, toStr];
    if (type != null && type.isNotEmpty) {
      where += ' AND type = ?';
      args.add(type);
    }

    final txnRows = await db.query(
      'erp_transactions',
      where: where,
      whereArgs: args,
      orderBy: 'created_at DESC',
      limit: limit,
      offset: offset,
    );

    final result = <LedgerTransaction>[];
    for (final row in txnRows) {
      final txnId = row['id'] as int;
      final entryRows = await db.query(
        'ledger_entries',
        where: 'transaction_id = ?',
        whereArgs: [txnId],
      );
      final entries = entryRows.map(LedgerEntry.fromMap).toList();

      Map<String, dynamic> tags = {};
      try {
        tags = jsonDecode(row['tags'] as String? ?? '{}') as Map<String, dynamic>;
      } catch (_) {}

      result.add(LedgerTransaction(
        id: txnId,
        type: row['type'] as String,
        totalAmount: (row['total_amount'] as num).toDouble(),
        tags: tags,
        createdAt: DateTime.parse(row['created_at'] as String),
        entries: entries,
      ));
    }
    return result;
  }

  /// Returns all ledger entries for a specific transaction.
  Future<LedgerTransaction?> getTransactionById(int id) async {
    final db = await _db.database;
    final rows = await db.query(
      'erp_transactions',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (rows.isEmpty) return null;
    final row = rows.first;

    final entryRows = await db.query(
      'ledger_entries',
      where: 'transaction_id = ?',
      whereArgs: [id],
    );
    final entries = entryRows.map(LedgerEntry.fromMap).toList();

    Map<String, dynamic> tags = {};
    try {
      tags = jsonDecode(row['tags'] as String? ?? '{}') as Map<String, dynamic>;
    } catch (_) {}

    return LedgerTransaction(
      id: id,
      type: row['type'] as String,
      totalAmount: (row['total_amount'] as num).toDouble(),
      tags: tags,
      createdAt: DateTime.parse(row['created_at'] as String),
      entries: entries,
    );
  }

  /// Counts how many transactions exist in the given date range (for empty
  /// state detection).
  Future<int> countTransactions({required DateTime from, required DateTime to}) async {
    final db = await _db.database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as cnt FROM erp_transactions WHERE created_at BETWEEN ? AND ?',
      [from.toIso8601String(), to.toIso8601String()],
    );
    return (result.first['cnt'] as int? ?? 0);
  }
}
