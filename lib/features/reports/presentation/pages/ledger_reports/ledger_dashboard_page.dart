import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';

import '../../../../../core/database/database_helper.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/utils/currency_formatter.dart';
import '../../data/repositories/ledger_dashboard_repository.dart';

// ─── Page ─────────────────────────────────────────────────────────────────────

class LedgerDashboardPage extends StatefulWidget {
  const LedgerDashboardPage({super.key});

  @override
  State<LedgerDashboardPage> createState() => _LedgerDashboardPageState();
}

class _LedgerDashboardPageState extends State<LedgerDashboardPage> {
  late final LedgerDashboardRepository _repo;

  // ── Filter state ──────────────────────────────────────────────────────
  _DateFilter _dateFilter = _DateFilter.today;
  DateTime _customFrom = DateTime.now();
  DateTime _customTo = DateTime.now();
  String? _typeFilter; // null = all

  // ── Loaded data ───────────────────────────────────────────────────────
  LedgerSummary? _summary;
  List<LedgerTransaction> _transactions = [];
  bool _loading = false;
  String? _error;

  static const List<(String, String?)> _typeOptions = [
    ('All', null),
    ('Sales', 'sale'),
    ('Purchases', 'purchase'),
    ('Expenses', 'expense'),
    ('Returns', 'sale_return'),
    ('Purchase Returns', 'purchase_return'),
    ('Stock Adj', 'stock_adjustment'),
    ('Waste', 'waste'),
  ];

  @override
  void initState() {
    super.initState();
    _repo = LedgerDashboardRepository(DatabaseHelper.instance);
    _load();
  }

  (DateTime, DateTime) _dateRange() {
    final now = DateTime.now();
    switch (_dateFilter) {
      case _DateFilter.today:
        return (
          DateTime(now.year, now.month, now.day),
          DateTime(now.year, now.month, now.day, 23, 59, 59),
        );
      case _DateFilter.week:
        final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
        return (
          DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day),
          DateTime(now.year, now.month, now.day, 23, 59, 59),
        );
      case _DateFilter.month:
        return (
          DateTime(now.year, now.month, 1),
          DateTime(now.year, now.month + 1, 0, 23, 59, 59),
        );
      case _DateFilter.custom:
        return (
          DateTime(_customFrom.year, _customFrom.month, _customFrom.day),
          DateTime(_customTo.year, _customTo.month, _customTo.day, 23, 59, 59),
        );
    }
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final (from, to) = _dateRange();
      final summary = await _repo.getSummary(from: from, to: to);
      final txns = await _repo.getTransactions(from: from, to: to, type: _typeFilter);
      setState(() {
        _summary = summary;
        _transactions = txns;
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _pickCustomDate() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      initialDateRange: DateTimeRange(start: _customFrom, end: _customTo),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: ColorScheme.fromSeed(seedColor: AppTheme.primary),
        ),
        child: child!,
      ),
    );
    if (range != null) {
      setState(() {
        _customFrom = range.start;
        _customTo = range.end;
        _dateFilter = _DateFilter.custom;
      });
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        title: const Text('Ledger Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _load,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _ErrorView(error: _error!, onRetry: _load)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: EdgeInsets.all(16.w),
                    children: [
                      _DateFilterBar(
                        selected: _dateFilter,
                        customFrom: _customFrom,
                        customTo: _customTo,
                        onFilter: (f) {
                          setState(() => _dateFilter = f);
                          if (f == _DateFilter.custom) {
                            _pickCustomDate();
                          } else {
                            _load();
                          }
                        },
                        onCustomTap: _pickCustomDate,
                      ),
                      SizedBox(height: 12.h),
                      if (_summary != null) ...[
                        _SummaryGrid(summary: _summary!),
                        SizedBox(height: 16.h),
                      ],
                      _TypeFilterChips(
                        options: _typeOptions,
                        selected: _typeFilter,
                        onSelected: (t) {
                          setState(() => _typeFilter = t);
                          _load();
                        },
                      ),
                      SizedBox(height: 12.h),
                      if (_transactions.isEmpty)
                        _EmptyState()
                      else
                        ..._transactions.map((t) => _TransactionCard(
                              txn: t,
                              onTap: () => _showDetail(t),
                            )),
                    ],
                  ),
                ),
    );
  }

  void _showDetail(LedgerTransaction txn) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => _TransactionDetailPage(txn: txn)),
    );
  }
}

// ─── Helpers ──────────────────────────────────────────────────────────────────

enum _DateFilter { today, week, month, custom }

// ─── Date filter bar ──────────────────────────────────────────────────────────

class _DateFilterBar extends StatelessWidget {
  final _DateFilter selected;
  final DateTime customFrom, customTo;
  final ValueChanged<_DateFilter> onFilter;
  final VoidCallback onCustomTap;

  const _DateFilterBar({
    required this.selected,
    required this.customFrom,
    required this.customTo,
    required this.onFilter,
    required this.onCustomTap,
  });

  @override
  Widget build(BuildContext context) {
    final items = [
      (_DateFilter.today, 'Today'),
      (_DateFilter.week, 'This Week'),
      (_DateFilter.month, 'This Month'),
      (_DateFilter.custom, selected == _DateFilter.custom
          ? '${DateFormat('dd MMM').format(customFrom)}–${DateFormat('dd MMM').format(customTo)}'
          : 'Custom'),
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: items.map((item) {
          final isSelected = selected == item.$1;
          return GestureDetector(
            onTap: () => item.$1 == _DateFilter.custom
                ? onCustomTap()
                : onFilter(item.$1),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: EdgeInsets.only(right: 8.w),
              padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
              decoration: BoxDecoration(
                color: isSelected ? AppTheme.primary : Colors.white,
                borderRadius: BorderRadius.circular(20.r),
                border: Border.all(
                  color: isSelected ? AppTheme.primary : AppTheme.divider,
                ),
              ),
              child: Text(
                item.$2,
                style: TextStyle(
                  color: isSelected ? Colors.white : AppTheme.textSecondary,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  fontSize: 12.sp,
                  fontFamily: 'Poppins',
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ─── Summary grid ─────────────────────────────────────────────────────────────

class _SummaryGrid extends StatelessWidget {
  final LedgerSummary summary;
  const _SummaryGrid({required this.summary});

  @override
  Widget build(BuildContext context) {
    final items = [
      ('💰', 'Sales Income', summary.totalSales, AppTheme.accent),
      ('📦', 'Purchases', summary.totalPurchases, AppTheme.secondary),
      ('💸', 'Expenses', summary.totalExpenses, AppTheme.warning),
      ('🗑️', 'Waste', summary.totalWaste, AppTheme.danger),
      ('📈', 'Gross Profit', summary.grossProfit,
          summary.grossProfit >= 0 ? AppTheme.accent : AppTheme.danger),
      ('🏆', 'Net Profit', summary.netProfit,
          summary.netProfit >= 0 ? AppTheme.accent : AppTheme.danger),
      ('🏭', 'Inventory Value', summary.inventoryValue, AppTheme.primary),
      ('🏦', 'Cash / Bank', summary.cashBalance,
          summary.cashBalance >= 0 ? AppTheme.accent : AppTheme.danger),
    ];

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 12.h,
      crossAxisSpacing: 12.w,
      childAspectRatio: 1.5,
      children: items.map((item) {
        return Container(
          padding: EdgeInsets.all(14.w),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16.r),
            border: Border.all(color: item.$4.withOpacity(0.25)),
            boxShadow: [
              BoxShadow(
                color: item.$4.withOpacity(0.06),
                blurRadius: 8,
                offset: const Offset(0, 2),
              )
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(children: [
                Text(item.$1, style: TextStyle(fontSize: 18.sp)),
                SizedBox(width: 6.w),
                Expanded(
                  child: Text(item.$2,
                      style: TextStyle(
                          fontSize: 10.sp,
                          color: AppTheme.textSecondary,
                          fontFamily: 'Poppins'),
                      overflow: TextOverflow.ellipsis),
                ),
              ]),
              Text(
                CurrencyFormatter.format(item.$3.abs()),
                style: TextStyle(
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w700,
                  color: item.$4,
                  fontFamily: 'Poppins',
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

// ─── Type filter chips ────────────────────────────────────────────────────────

class _TypeFilterChips extends StatelessWidget {
  final List<(String, String?)> options;
  final String? selected;
  final ValueChanged<String?> onSelected;

  const _TypeFilterChips({
    required this.options,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Recent Transactions', style: AppTheme.heading3),
        SizedBox(height: 8.h),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: options.map((opt) {
              final isSelected = selected == opt.$2;
              return GestureDetector(
                onTap: () => onSelected(opt.$2),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  margin: EdgeInsets.only(right: 8.w),
                  padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppTheme.secondary
                        : AppTheme.surface,
                    borderRadius: BorderRadius.circular(16.r),
                    border: Border.all(
                      color:
                          isSelected ? AppTheme.secondary : AppTheme.divider,
                    ),
                  ),
                  child: Text(
                    opt.$1,
                    style: TextStyle(
                      fontSize: 11.sp,
                      color: isSelected ? Colors.white : AppTheme.textSecondary,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.w400,
                      fontFamily: 'Poppins',
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

// ─── Transaction card ─────────────────────────────────────────────────────────

class _TransactionCard extends StatelessWidget {
  final LedgerTransaction txn;
  final VoidCallback onTap;

  const _TransactionCard({required this.txn, required this.onTap});

  static const Map<String, (IconData, Color, String)> _typeInfo = {
    'sale': (Icons.point_of_sale_rounded, AppTheme.accent, 'Sale'),
    'purchase': (Icons.local_shipping_rounded, AppTheme.secondary, 'Purchase'),
    'expense': (Icons.receipt_long_rounded, AppTheme.warning, 'Expense'),
    'waste': (Icons.delete_outline_rounded, AppTheme.danger, 'Waste'),
    'stock_adjustment':
        (Icons.tune_rounded, AppTheme.primary, 'Stock Adj.'),
    'sale_return':
        (Icons.assignment_return_rounded, AppTheme.danger, 'Sale Return'),
    'purchase_return':
        (Icons.keyboard_return_rounded, AppTheme.warning, 'Purchase Return'),
    'internal_transfer':
        (Icons.swap_horiz_rounded, AppTheme.textSecondary, 'Transfer'),
  };

  @override
  Widget build(BuildContext context) {
    final info = _typeInfo[txn.type] ??
        (Icons.receipt_outlined, AppTheme.textSecondary, txn.type);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: EdgeInsets.only(bottom: 10.h),
        padding: EdgeInsets.all(14.w),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14.r),
          border: Border.all(
            color: txn.isBalanced ? AppTheme.divider : AppTheme.danger.withOpacity(0.5),
          ),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 6,
                offset: const Offset(0, 2))
          ],
        ),
        child: Column(
          children: [
            Row(children: [
              Container(
                width: 40.w,
                height: 40.h,
                decoration: BoxDecoration(
                  color: info.$2.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10.r),
                ),
                child: Icon(info.$1, color: info.$2, size: 20.sp),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(info.$3,
                        style: TextStyle(
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'Poppins',
                          color: AppTheme.textPrimary,
                        )),
                    Text(
                      DateFormat('dd MMM yyyy  hh:mm a').format(txn.createdAt),
                      style: TextStyle(
                          fontSize: 10.sp,
                          color: AppTheme.textSecondary,
                          fontFamily: 'Poppins'),
                    ),
                  ],
                ),
              ),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text(
                  CurrencyFormatter.format(txn.totalAmount),
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w700,
                    color: info.$2,
                    fontFamily: 'Poppins',
                  ),
                ),
                Container(
                  margin: EdgeInsets.only(top: 3.h),
                  padding:
                      EdgeInsets.symmetric(horizontal: 7.w, vertical: 2.h),
                  decoration: BoxDecoration(
                    color: txn.isBalanced
                        ? AppTheme.accent.withOpacity(0.1)
                        : AppTheme.danger.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6.r),
                  ),
                  child: Text(
                    txn.isBalanced ? '✓ Balanced' : '⚠ Mismatch',
                    style: TextStyle(
                      fontSize: 9.sp,
                      fontWeight: FontWeight.w600,
                      color: txn.isBalanced ? AppTheme.accent : AppTheme.danger,
                      fontFamily: 'Poppins',
                    ),
                  ),
                ),
              ]),
            ]),
            if (!txn.isBalanced) ...[
              SizedBox(height: 8.h),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
                decoration: BoxDecoration(
                  color: AppTheme.danger.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Row(children: [
                  Icon(Icons.warning_amber_rounded,
                      color: AppTheme.danger, size: 14.sp),
                  SizedBox(width: 6.w),
                  Text(
                    'Ledger mismatch found — '
                    'Debit: ${CurrencyFormatter.format(txn.debitTotal)}  '
                    'Credit: ${CurrencyFormatter.format(txn.creditTotal)}',
                    style: TextStyle(
                        fontSize: 10.sp,
                        color: AppTheme.danger,
                        fontFamily: 'Poppins'),
                  ),
                ]),
              ),
            ],
            if (txn.entries.isNotEmpty) ...[
              SizedBox(height: 8.h),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _pill('DR ${CurrencyFormatter.format(txn.debitTotal)}',
                      AppTheme.primary),
                  _pill('CR ${CurrencyFormatter.format(txn.creditTotal)}',
                      AppTheme.secondary),
                  Text('${txn.entries.length} entries',
                      style: TextStyle(
                          fontSize: 10.sp,
                          color: AppTheme.textSecondary,
                          fontFamily: 'Poppins')),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _pill(String text, Color color) => Container(
        padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(6.r),
        ),
        child: Text(text,
            style: TextStyle(
                fontSize: 10.sp,
                color: color,
                fontWeight: FontWeight.w600,
                fontFamily: 'Poppins')),
      );
}

// ─── Empty state ──────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(32.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('📒', style: TextStyle(fontSize: 48.sp)),
            SizedBox(height: 12.h),
            Text('No ledger entries yet',
                style: AppTheme.heading3.copyWith(color: AppTheme.textSecondary)),
            SizedBox(height: 6.h),
            Text(
              'Start billing, adding purchases, or expenses.\n'
              'Every transaction will appear here.',
              textAlign: TextAlign.center,
              style: AppTheme.caption,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Error view ───────────────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;
  const _ErrorView({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(24.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, color: AppTheme.danger, size: 40.sp),
            SizedBox(height: 12.h),
            Text(error,
                textAlign: TextAlign.center, style: AppTheme.caption),
            SizedBox(height: 16.h),
            ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

// ─── Transaction Detail Page ──────────────────────────────────────────────────

class _TransactionDetailPage extends StatelessWidget {
  final LedgerTransaction txn;
  const _TransactionDetailPage({required this.txn});

  static const Map<String, String> _accountLabels = {
    'income': 'Sales Income',
    'cogs': 'Cost of Goods Sold',
    'expense': 'Expense',
    'inventory': 'Inventory Asset',
    'asset': 'Cash / Bank',
    'liability': 'Supplier Payable / Opening Adj.',
    'waste': 'Waste / Spoilage',
  };

  @override
  Widget build(BuildContext context) {
    final info = _TransactionCard._typeInfo[txn.type] ??
        (Icons.receipt_outlined, AppTheme.textSecondary, txn.type);

    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        title: Text('${info.$3} Details'),
      ),
      body: ListView(
        padding: EdgeInsets.all(16.w),
        children: [
          // Header card
          Container(
            padding: EdgeInsets.all(16.w),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16.r),
              border: Border.all(color: AppTheme.divider),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Container(
                    width: 44.w, height: 44.h,
                    decoration: BoxDecoration(
                      color: info.$2.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    child: Icon(info.$1, color: info.$2, size: 22.sp),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(info.$3,
                          style: TextStyle(
                              fontSize: 16.sp, fontWeight: FontWeight.w700,
                              fontFamily: 'Poppins', color: AppTheme.textPrimary)),
                      Text('ID: #${txn.id}',
                          style: TextStyle(fontSize: 11.sp,
                              color: AppTheme.textSecondary, fontFamily: 'Poppins')),
                    ],
                  )),
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text(CurrencyFormatter.format(txn.totalAmount),
                        style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w800,
                            color: info.$2, fontFamily: 'Poppins')),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                      decoration: BoxDecoration(
                        color: txn.isBalanced
                            ? AppTheme.accent.withOpacity(0.1)
                            : AppTheme.danger.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                      child: Text(
                        txn.isBalanced ? '✓ Balanced' : '⚠ Ledger Mismatch',
                        style: TextStyle(
                            fontSize: 10.sp, fontWeight: FontWeight.w600,
                            color: txn.isBalanced ? AppTheme.accent : AppTheme.danger,
                            fontFamily: 'Poppins'),
                      ),
                    ),
                  ]),
                ]),
                Divider(height: 20.h, color: AppTheme.divider),
                Text(DateFormat('EEEE, dd MMM yyyy  hh:mm a').format(txn.createdAt),
                    style: TextStyle(fontSize: 12.sp, color: AppTheme.textSecondary,
                        fontFamily: 'Poppins')),
                if (txn.tags.isNotEmpty) ...[
                  SizedBox(height: 8.h),
                  Wrap(
                    spacing: 6.w, runSpacing: 6.h,
                    children: txn.tags.entries
                        .where((e) => e.value != null && e.value.toString().isNotEmpty)
                        .map((e) => Container(
                              padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                              decoration: BoxDecoration(
                                color: AppTheme.surface,
                                borderRadius: BorderRadius.circular(6.r),
                                border: Border.all(color: AppTheme.divider),
                              ),
                              child: Text('${e.key}: ${e.value}',
                                  style: TextStyle(fontSize: 10.sp,
                                      color: AppTheme.textSecondary, fontFamily: 'Poppins')),
                            ))
                        .toList(),
                  ),
                ],
              ],
            ),
          ),

          SizedBox(height: 16.h),

          // Balance row
          Row(children: [
            Expanded(child: _balanceTile('Debit Total', txn.debitTotal, AppTheme.primary)),
            SizedBox(width: 10.w),
            Expanded(child: _balanceTile('Credit Total', txn.creditTotal, AppTheme.secondary)),
          ]),

          SizedBox(height: 16.h),

          Text('Ledger Entries (${txn.entries.length})',
              style: AppTheme.heading3),
          SizedBox(height: 8.h),

          // Ledger entry rows
          ...txn.entries.map((e) => _LedgerEntryRow(
                entry: e,
                accountLabel: _accountLabels[e.accountType] ?? e.accountType,
              )),
        ],
      ),
    );
  }

  Widget _balanceTile(String label, double amount, Color color) => Container(
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
        decoration: BoxDecoration(
          color: color.withOpacity(0.07),
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: TextStyle(fontSize: 10.sp,
                  color: AppTheme.textSecondary, fontFamily: 'Poppins')),
          SizedBox(height: 4.h),
          Text(CurrencyFormatter.format(amount),
              style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w700,
                  color: color, fontFamily: 'Poppins')),
        ]),
      );
}

// ─── Ledger entry row ─────────────────────────────────────────────────────────

class _LedgerEntryRow extends StatelessWidget {
  final LedgerEntry entry;
  final String accountLabel;

  const _LedgerEntryRow({required this.entry, required this.accountLabel});

  @override
  Widget build(BuildContext context) {
    final isDebit = entry.direction == 'debit';
    final color = isDebit ? AppTheme.primary : AppTheme.secondary;

    return Container(
      margin: EdgeInsets.only(bottom: 8.h),
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Row(children: [
        Container(
          width: 36.w, height: 36.h,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8.r),
          ),
          child: Icon(
            isDebit ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
            color: color, size: 18.sp,
          ),
        ),
        SizedBox(width: 10.w),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(accountLabel,
                style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w600,
                    fontFamily: 'Poppins', color: AppTheme.textPrimary)),
            Row(children: [
              Container(
                padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 1.h),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4.r),
                ),
                child: Text(isDebit ? 'DEBIT' : 'CREDIT',
                    style: TextStyle(fontSize: 9.sp, fontWeight: FontWeight.w700,
                        color: color, fontFamily: 'Poppins')),
              ),
              if (entry.quantityChange != null && entry.quantityChange != 0) ...[
                SizedBox(width: 6.w),
                Text(
                  entry.quantityChange! > 0
                      ? '+${entry.quantityChange!.toStringAsFixed(2)} units'
                      : '${entry.quantityChange!.toStringAsFixed(2)} units',
                  style: TextStyle(fontSize: 9.sp, color: AppTheme.textSecondary,
                      fontFamily: 'Poppins'),
                ),
              ],
            ]),
          ],
        )),
        Text(
          CurrencyFormatter.format(entry.amount),
          style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w700,
              color: color, fontFamily: 'Poppins'),
        ),
      ]),
    );
  }
}
