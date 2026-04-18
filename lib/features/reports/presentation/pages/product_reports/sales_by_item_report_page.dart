import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../../core/database/database_helper.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/utils/currency_formatter.dart';
import '../../../data/repositories/report_repository.dart';
import '../../../utils/pdf_export_helper.dart';
import '../../widgets/date_range_filter.dart';
import '../../widgets/report_summary_card.dart';

class SalesByItemReportPage extends StatefulWidget {
  const SalesByItemReportPage({super.key});

  @override
  State<SalesByItemReportPage> createState() => _SalesByItemReportPageState();
}

class _SalesByItemReportPageState extends State<SalesByItemReportPage> {
  late final ReportRepository _repo;
  late DateTime _from, _to;
  List<Map<String, dynamic>> _items = [];
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
      final data = await _repo.getSalesByItem(from: _from, to: _to);
      setState(() => _items = data);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _export() async {
    final totalRev = _items.fold(0.0, (s, i) => s + (i['total_revenue'] as num).toDouble());
    final totalProfit = _items.fold(0.0, (s, i) => s + (i['total_profit'] as num? ?? 0).toDouble());
    await PdfExportHelper.exportAndShare(
      title: 'Sales by Item Report',
      headers: ['Product', 'Total Qty', 'Revenue', 'Profit', 'Bills'],
      rows: _items.map((it) => [
        it['product_name'].toString(),
        (it['total_qty'] as num).toStringAsFixed(1),
        CurrencyFormatter.format((it['total_revenue'] as num).toDouble()),
        CurrencyFormatter.format((it['total_profit'] as num? ?? 0).toDouble()),
        it['bill_count'].toString(),
      ]).toList(),
      summary: {
        'Total Items': _items.length.toString(),
        'Total Revenue': CurrencyFormatter.format(totalRev),
        'Total Profit': CurrencyFormatter.format(totalProfit),
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalRev = _items.fold(0.0, (s, i) => s + (i['total_revenue'] as num).toDouble());
    final totalProfit = _items.fold(0.0, (s, i) => s + (i['total_profit'] as num? ?? 0).toDouble());

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sales by Item'),
        actions: [
          if (_items.isNotEmpty)
            IconButton(icon: const Icon(Icons.picture_as_pdf), onPressed: _export)
        ],
      ),
      body: Column(children: [
        Container(
          color: Colors.white,
          padding: EdgeInsets.all(16.w),
          child: DateRangeFilter(
              from: _from, to: _to,
              onChanged: (f, t) { setState(() { _from = f; _to = t; }); _load(); }),
        ),
        if (_items.isNotEmpty)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
            child: Row(children: [
              ReportSummaryCard(label: 'Total Items',
                  value: _items.length.toString(), color: AppTheme.primary, emoji: '🛒'),
              SizedBox(width: 10.w),
              ReportSummaryCard(label: 'Total Revenue',
                  value: CurrencyFormatter.format(totalRev), color: AppTheme.accent, emoji: '💰'),
              SizedBox(width: 10.w),
              ReportSummaryCard(label: 'Total Profit',
                  value: CurrencyFormatter.format(totalProfit), color: AppTheme.secondary, emoji: '📈'),
            ]),
          ),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? Center(child: Text('Error: $_error'))
                  : _items.isEmpty
                      ? Center(child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('🛒', style: TextStyle(fontSize: 48.sp)),
                            SizedBox(height: 12.h),
                            Text('No sales data found', style: AppTheme.heading3),
                          ]))
                      : ListView.separated(
                          padding: EdgeInsets.all(16.w),
                          itemCount: _items.length,
                          separatorBuilder: (_, __) => SizedBox(height: 8.h),
                          itemBuilder: (_, i) {
                            final it = _items[i];
                            return Container(
                              padding: EdgeInsets.all(14.w),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12.r),
                                border: Border.all(color: AppTheme.divider),
                              ),
                              child: Row(children: [
                                Container(
                                  width: 36.w, height: 36.h,
                                  decoration: BoxDecoration(
                                    color: AppTheme.accent.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8.r),
                                  ),
                                  child: Center(child: Text('${i + 1}',
                                      style: TextStyle(color: AppTheme.accent,
                                          fontWeight: FontWeight.w700, fontSize: 13.sp, fontFamily: 'Poppins'))),
                                ),
                                SizedBox(width: 12.w),
                                Expanded(child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(it['product_name'].toString(),
                                        style: AppTheme.body.copyWith(fontWeight: FontWeight.w600)),
                                    Text('Qty: ${(it['total_qty'] as num).toStringAsFixed(1)}  •  Bills: ${it['bill_count']}',
                                        style: AppTheme.caption),
                                  ],
                                )),
                                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                                  Text(CurrencyFormatter.format((it['total_revenue'] as num).toDouble()),
                                      style: AppTheme.body.copyWith(fontWeight: FontWeight.w700, color: AppTheme.primary)),
                                  Text('Profit: ${CurrencyFormatter.format((it['total_profit'] as num? ?? 0).toDouble())}',
                                      style: AppTheme.caption.copyWith(color: AppTheme.accent)),
                                ]),
                              ]),
                            );
                          }),
        ),
      ]),
    );
  }
}

