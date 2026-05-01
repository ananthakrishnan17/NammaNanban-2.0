import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';

import '../../../../../core/database/database_helper.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/utils/currency_formatter.dart';
import '../../../data/repositories/report_repository.dart';
import '../../widgets/date_range_filter.dart';

class LedgerDashboardPage extends StatefulWidget {
  const LedgerDashboardPage({super.key});

  @override
  State<LedgerDashboardPage> createState() => _LedgerDashboardPageState();
}

class _LedgerDashboardPageState extends State<LedgerDashboardPage> {
  late final ReportRepository _repo;
  late DateTime _from, _to;
  Map<String, double> _balances = {};
  Map<String, dynamic> _trial = {};
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _repo = ReportRepository(DatabaseHelper.instance);
    final now = DateTime.now();
    _from = DateTime(now.year, now.month, 1);
    _to = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
    _load();
  }

  Future<void> _load() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final balances = await _repo.getLedgerBalances(from: _from, to: _to);
      final trial = await _repo.getTrialBalance(from: _from, to: _to);
      setState(() { _balances = balances; _trial = trial; });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(title: const Text('Ledger Dashboard')),
      body: Column(
        children: [
          DateRangeFilter(
            from: _from,
            to: _to,
            onChanged: (f, t) { setState(() { _from = f; _to = t; }); _load(); },
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(child: Text(_error!, style: TextStyle(color: AppTheme.danger)))
                    : _buildDashboard(),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboard() {
    final income = _balances['income'] ?? 0;
    final cogs = _balances['cogs'] ?? 0;
    final expense = _balances['expense'] ?? 0;
    final inventory = _balances['inventory'] ?? 0;
    final asset = _balances['asset'] ?? 0;
    final waste = _balances['waste'] ?? 0;

    final grossProfit = income - cogs;
    final netProfit = grossProfit - expense - waste;
    final isBalanced = _trial['is_balanced'] as bool? ?? true;

    return SingleChildScrollView(
      padding: EdgeInsets.all(16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // P&L Summary
          _sectionHeader('📊 Profit & Loss', '${_fmtDate(_from)} — ${_fmtDate(_to)}'),
          SizedBox(height: 8.h),
          Row(children: [
            _card('💰 Revenue', income, AppTheme.accent, flex: 2),
            SizedBox(width: 10.w),
            _card('📦 COGS', cogs, AppTheme.warning, flex: 2),
          ]),
          SizedBox(height: 10.h),
          Row(children: [
            _card('💸 Expenses', expense, AppTheme.danger, flex: 2),
            SizedBox(width: 10.w),
            _card('🗑️ Waste', waste, Colors.grey, flex: 2),
          ]),
          SizedBox(height: 10.h),
          _bigCard(
            icon: netProfit >= 0 ? '🚀' : '📉',
            label: 'Net Profit',
            value: netProfit,
            color: netProfit >= 0 ? AppTheme.accent : AppTheme.danger,
          ),
          SizedBox(height: 20.h),

          // Balance Sheet snapshot
          _sectionHeader('🏦 Balance Sheet', 'Snapshot'),
          SizedBox(height: 8.h),
          Row(children: [
            _card('💵 Cash / Receivable', asset, AppTheme.primary, flex: 2),
            SizedBox(width: 10.w),
            _card('🏗️ Inventory', inventory, const Color(0xFF6B48FF), flex: 2),
          ]),
          SizedBox(height: 20.h),

          // Trial Balance status
          _sectionHeader('⚖️ Trial Balance', ''),
          SizedBox(height: 8.h),
          Container(
            padding: EdgeInsets.all(16.w),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(color: isBalanced ? AppTheme.accent : AppTheme.danger),
            ),
            child: Row(
              children: [
                Icon(
                  isBalanced ? Icons.check_circle : Icons.warning_amber_rounded,
                  color: isBalanced ? AppTheme.accent : AppTheme.danger,
                  size: 24.sp,
                ),
                SizedBox(width: 10.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isBalanced ? 'Books are Balanced' : 'Books are NOT Balanced',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14.sp,
                          fontFamily: 'Poppins',
                          color: isBalanced ? AppTheme.accent : AppTheme.danger,
                        ),
                      ),
                      SizedBox(height: 2.h),
                      Text(
                        'Debits: ${CurrencyFormatter.format(_trial['total_debits'] as double? ?? 0)}'
                        '  Credits: ${CurrencyFormatter.format(_trial['total_credits'] as double? ?? 0)}',
                        style: AppTheme.caption,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 20.h),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title, String sub) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: AppTheme.heading2),
        if (sub.isNotEmpty)
          Text(sub, style: AppTheme.caption),
      ],
    );
  }

  Widget _card(String label, double value, Color color, {int flex = 1}) {
    return Expanded(
      flex: flex,
      child: Container(
        padding: EdgeInsets.all(14.w),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: AppTheme.caption, maxLines: 1, overflow: TextOverflow.ellipsis),
            SizedBox(height: 4.h),
            Text(
              CurrencyFormatter.format(value),
              style: TextStyle(
                fontSize: 16.sp,
                fontWeight: FontWeight.w700,
                fontFamily: 'Poppins',
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bigCard({required String icon, required String label, required double value, required Color color}) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(18.w),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Row(children: [
        Text(icon, style: TextStyle(fontSize: 32.sp)),
        SizedBox(width: 12.w),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: AppTheme.caption),
            Text(
              CurrencyFormatter.format(value),
              style: TextStyle(
                fontSize: 22.sp,
                fontWeight: FontWeight.w700,
                fontFamily: 'Poppins',
                color: color,
              ),
            ),
          ],
        ),
      ]),
    );
  }

  String _fmtDate(DateTime d) => DateFormat('dd MMM yyyy').format(d);
}
