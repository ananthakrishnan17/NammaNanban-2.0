import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../../core/database/database_helper.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/utils/currency_formatter.dart';
import '../../../data/repositories/report_repository.dart';
import '../../../utils/pdf_export_helper.dart';
import '../../widgets/date_range_filter.dart';

class ProfitLossReportPage extends StatefulWidget {
  const ProfitLossReportPage({super.key});

  @override
  State<ProfitLossReportPage> createState() => _ProfitLossReportPageState();
}

class _ProfitLossReportPageState extends State<ProfitLossReportPage> {
  late final ReportRepository _repo;
  late DateTime _from, _to;
  Map<String, dynamic>? _pl;
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
    setState(() { _isLoading = true; _error = null; _pl = null; });
    try {
      // Phase 4: Try ledger-based P&L first; falls back to legacy if no entries
      final data = await _repo.getProfitAndLossFromLedger(from: _from, to: _to);
      setState(() => _pl = data);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _setThisMonth() {
    final now = DateTime.now();
    setState(() {
      _from = DateTime(now.year, now.month, 1);
      _to = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
    });
    _load();
  }

  void _setLastMonth() {
    final now = DateTime.now();
    final lastMonth = DateTime(now.year, now.month - 1);
    setState(() {
      _from = DateTime(lastMonth.year, lastMonth.month, 1);
      _to = DateTime(lastMonth.year, lastMonth.month + 1, 0, 23, 59, 59);
    });
    _load();
  }

  void _setThisYear() {
    final now = DateTime.now();
    setState(() {
      _from = DateTime(now.year, 1, 1);
      _to = DateTime(now.year, 12, 31, 23, 59, 59);
    });
    _load();
  }

  Future<void> _export() async {
    if (_pl == null) return;
    final waste = (_pl!['waste'] as num?)?.toDouble() ?? 0.0;
    final rows = [
      ['Total Sales (Income)', CurrencyFormatter.format((_pl!['income'] as num?)?.toDouble() ?? 0.0)],
      ['Less: Returns', CurrencyFormatter.format((_pl!['return_deductions'] as num?)?.toDouble() ?? 0.0)],
      ['Net Sales', CurrencyFormatter.format((_pl!['net_sales'] as num?)?.toDouble() ?? 0.0)],
      ['Cost of Goods Sold', CurrencyFormatter.format((_pl!['cogs'] as num?)?.toDouble() ?? 0.0)],
      ['Gross Profit', CurrencyFormatter.format((_pl!['gross_profit'] as num?)?.toDouble() ?? 0.0)],
      ['Operating Expenses', CurrencyFormatter.format((_pl!['expenses'] as num?)?.toDouble() ?? 0.0)],
      if (waste > 0) ['Waste / Spoilage', CurrencyFormatter.format(waste)],
      ['Net Profit / Loss', CurrencyFormatter.format((_pl!['net_profit'] as num?)?.toDouble() ?? 0.0)],
      ['Profit Margin', '${((_pl!['profit_margin'] as num?)?.toDouble() ?? 0.0).toStringAsFixed(1)}%'],
    ];
    await PdfExportHelper.exportAndShare(
      title: 'Profit & Loss Statement',
      headers: ['Item', 'Amount'],
      rows: rows,
    );
  }

  bool get _isLedgerSource => _pl?['source'] == 'ledger';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profit & Loss'),
        actions: [
          if (_pl != null)
            IconButton(icon: const Icon(Icons.picture_as_pdf), onPressed: _export)
        ],
      ),
      body: Column(children: [
        Container(
          color: Colors.white,
          padding: EdgeInsets.all(16.w),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              _qBtn('This Month', _setThisMonth),
              SizedBox(width: 8.w),
              _qBtn('Last Month', _setLastMonth),
              SizedBox(width: 8.w),
              _qBtn('This Year', _setThisYear),
            ]),
            SizedBox(height: 10.h),
            DateRangeFilter(from: _from, to: _to,
                onChanged: (f, t) { setState(() { _from = f; _to = t; }); _load(); }),
          ]),
        ),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? Center(child: Text('Error: $_error'))
                  : _pl == null
                      ? Center(child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('📊', style: TextStyle(fontSize: 48.sp)),
                            SizedBox(height: 12.h),
                            Text('No data found', style: AppTheme.heading3),
                          ]))
                      : SingleChildScrollView(
                          padding: EdgeInsets.all(16.w),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            // Data source badge
                            if (_isLedgerSource) ...[
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
                                margin: EdgeInsets.only(bottom: 16.h),
                                decoration: BoxDecoration(
                                  color: AppTheme.primary.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(8.r),
                                ),
                                child: Row(mainAxisSize: MainAxisSize.min, children: [
                                  Icon(Icons.account_balance_outlined, size: 13.sp, color: AppTheme.primary),
                                  SizedBox(width: 5.w),
                                  Text('Sourced from ledger entries', style: AppTheme.caption.copyWith(color: AppTheme.primary, fontWeight: FontWeight.w500)),
                                ]),
                              ),
                            ],

                            _sectionHeader('INCOME'),
                            _plRow('Total Sales', (_pl!['income'] as num?)?.toDouble() ?? 0.0, color: AppTheme.accent),
                            _plRow('Less: Returns', (_pl!['return_deductions'] as num?)?.toDouble() ?? 0.0, deduct: true),
                            _totalRow('Net Sales', (_pl!['net_sales'] as num?)?.toDouble() ?? 0.0),
                            SizedBox(height: 16.h),

                            _sectionHeader('COST OF GOODS SOLD'),
                            _plRow('Purchase Cost (COGS)', (_pl!['cogs'] as num?)?.toDouble() ?? 0.0, deduct: true),
                            _totalRow('Gross Profit', (_pl!['gross_profit'] as num?)?.toDouble() ?? 0.0),
                            SizedBox(height: 16.h),

                            _sectionHeader('OPERATING EXPENSES'),
                            _plRow('Total Expenses', (_pl!['expenses'] as num?)?.toDouble() ?? 0.0, deduct: true),
                            SizedBox(height: 16.h),

                            // Waste / Spoilage section — only shown when > 0
                            if (((_pl!['waste'] as num?)?.toDouble() ?? 0) > 0) ...[
                              _sectionHeader('WASTE / SPOILAGE'),
                              _plRow(
                                'Stock Write-offs',
                                (_pl!['waste'] as num?)?.toDouble() ?? 0.0,
                                deduct: true,
                                color: AppTheme.warning,
                              ),
                              Container(
                                margin: EdgeInsets.symmetric(vertical: 4.h),
                                padding: EdgeInsets.symmetric(vertical: 6.h, horizontal: 12.w),
                                decoration: BoxDecoration(
                                  color: AppTheme.warning.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(8.r),
                                ),
                                child: Row(children: [
                                  Icon(Icons.warning_amber_rounded, size: 14.sp, color: AppTheme.warning),
                                  SizedBox(width: 6.w),
                                  Expanded(child: Text(
                                    'Waste reduces your gross margin',
                                    style: AppTheme.caption.copyWith(color: AppTheme.warning),
                                  )),
                                ]),
                              ),
                              SizedBox(height: 16.h),
                            ],

                            // Net Profit highlight
                            Container(
                              width: double.infinity,
                              padding: EdgeInsets.all(16.w),
                              decoration: BoxDecoration(
                                color: ((_pl!['net_profit'] as num?)?.toDouble() ?? 0.0) >= 0
                                    ? AppTheme.accent.withOpacity(0.1)
                                    : AppTheme.danger.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(14.r),
                                border: Border.all(
                                  color: ((_pl!['net_profit'] as num?)?.toDouble() ?? 0.0) >= 0
                                      ? AppTheme.accent
                                      : AppTheme.danger,
                                ),
                              ),
                              child: Column(children: [
                                Text(
                                  ((_pl!['net_profit'] as num?)?.toDouble() ?? 0.0) >= 0
                                      ? '🎯 NET PROFIT'
                                      : '⚠️ NET LOSS',
                                  style: TextStyle(
                                      fontSize: 12.sp, fontWeight: FontWeight.w700,
                                      color: ((_pl!['net_profit'] as num?)?.toDouble() ?? 0.0) >= 0
                                          ? AppTheme.accent : AppTheme.danger,
                                      fontFamily: 'Poppins'),
                                ),
                                SizedBox(height: 4.h),
                                Text(
                                  CurrencyFormatter.format(((_pl!['net_profit'] as num?)?.toDouble() ?? 0.0).abs()),
                                  style: TextStyle(
                                      fontSize: 24.sp, fontWeight: FontWeight.w700,
                                      color: ((_pl!['net_profit'] as num?)?.toDouble() ?? 0.0) >= 0
                                          ? AppTheme.accent : AppTheme.danger,
                                      fontFamily: 'Poppins'),
                                ),
                                SizedBox(height: 4.h),
                                Text(
                                  'Margin: ${((_pl!['profit_margin'] as num?)?.toDouble() ?? 0.0).toStringAsFixed(1)}%',
                                  style: AppTheme.caption.copyWith(
                                      color: ((_pl!['net_profit'] as num?)?.toDouble() ?? 0.0) >= 0
                                          ? AppTheme.accent : AppTheme.danger),
                                ),
                              ]),
                            ),
                          ]),
                        ),
        ),
      ]),
    );
  }

  Widget _qBtn(String label, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: AppTheme.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: AppTheme.primary.withOpacity(0.3)),
      ),
      child: Text(label,
          style: TextStyle(fontSize: 11.sp, fontFamily: 'Poppins',
              color: AppTheme.primary, fontWeight: FontWeight.w500)),
    ),
  );

  Widget _sectionHeader(String title) => Padding(
    padding: EdgeInsets.only(bottom: 8.h),
    child: Text(title,
        style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.w700,
            color: AppTheme.textSecondary, fontFamily: 'Poppins',
            letterSpacing: 1)),
  );

  Widget _plRow(String label, double amount, {bool deduct = false, Color? color}) =>
      Padding(
        padding: EdgeInsets.symmetric(vertical: 4.h),
        child: Row(children: [
          Expanded(child: Text(label, style: AppTheme.body)),
          Text(
            '${deduct ? '- ' : ''}${CurrencyFormatter.format(amount)}',
            style: AppTheme.body.copyWith(
                color: color ?? (deduct ? AppTheme.danger : AppTheme.accent),
                fontWeight: FontWeight.w600),
          ),
        ]),
      );

  Widget _totalRow(String label, double amount) => Container(
    margin: EdgeInsets.symmetric(vertical: 4.h),
    padding: EdgeInsets.symmetric(vertical: 8.h, horizontal: 12.w),
    decoration: BoxDecoration(
      color: AppTheme.divider.withOpacity(0.5),
      borderRadius: BorderRadius.circular(8.r),
    ),
    child: Row(children: [
      Expanded(child: Text(label,
          style: AppTheme.body.copyWith(fontWeight: FontWeight.w700))),
      Text(CurrencyFormatter.format(amount),
          style: AppTheme.body.copyWith(
              fontWeight: FontWeight.w700,
              color: amount >= 0 ? AppTheme.accent : AppTheme.danger)),
    ]),
  );
}
