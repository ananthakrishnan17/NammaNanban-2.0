import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';

import '../../../../../core/database/database_helper.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/utils/currency_formatter.dart';
import '../../../data/repositories/report_repository.dart';
import '../../../utils/pdf_export_helper.dart';
import '../../widgets/date_range_filter.dart';

class DaywiseProfitReportPage extends StatefulWidget {
  const DaywiseProfitReportPage({super.key});

  @override
  State<DaywiseProfitReportPage> createState() =>
      _DaywiseProfitReportPageState();
}

class _DaywiseProfitReportPageState extends State<DaywiseProfitReportPage> {
  late final ReportRepository _repo;
  late DateTime _from, _to;
  List<Map<String, dynamic>> _data = [];
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
      final data = await _repo.getDaywiseProfitReport(from: _from, to: _to);
      setState(() => _data = data);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _export() async {
    final totalSales = _data.fold(0.0, (s, d) => s + (d['total_sales'] as num).toDouble());
    final totalProfit = _data.fold(0.0, (s, d) => s + (d['total_profit'] as num).toDouble());
    final totalExpenses = _data.fold(0.0, (s, d) => s + (d['total_expenses'] as num? ?? 0).toDouble());
    final netProfit = _data.fold(0.0, (s, d) => s + (d['net_profit'] as num? ?? 0).toDouble());
    await PdfExportHelper.exportAndShare(
      title: 'Day-wise Profit Report',
      headers: ['Date', 'Bills', 'Sales', 'Profit', 'Expenses', 'Net Profit'],
      rows: _data.map((d) => [
        d['day'].toString(),
        d['bill_count'].toString(),
        CurrencyFormatter.format((d['total_sales'] as num).toDouble()),
        CurrencyFormatter.format((d['total_profit'] as num).toDouble()),
        CurrencyFormatter.format((d['total_expenses'] as num? ?? 0).toDouble()),
        CurrencyFormatter.format((d['net_profit'] as num? ?? 0).toDouble()),
      ]).toList(),
      summary: {
        'Total Sales': CurrencyFormatter.format(totalSales),
        'Total Profit': CurrencyFormatter.format(totalProfit),
        'Total Expenses': CurrencyFormatter.format(totalExpenses),
        'Net Profit': CurrencyFormatter.format(netProfit),
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalSales = _data.fold(0.0, (s, d) => s + (d['total_sales'] as num).toDouble());
    final totalProfit = _data.fold(0.0, (s, d) => s + (d['total_profit'] as num).toDouble());

    // Line chart data
    final spots = _data.asMap().entries.map((e) => FlSpot(
      e.key.toDouble(),
      (e.value['net_profit'] as num? ?? 0).toDouble(),
    )).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Day-wise Profit Report'),
        actions: [
          if (_data.isNotEmpty)
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
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? Center(child: Text('Error: $_error'))
                  : _data.isEmpty
                      ? Center(child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('📅', style: TextStyle(fontSize: 48.sp)),
                            SizedBox(height: 12.h),
                            Text('No data in this period', style: AppTheme.heading3),
                          ]))
                      : SingleChildScrollView(
                          child: Column(children: [
                            // Summary
                            Padding(
                              padding: EdgeInsets.all(16.w),
                              child: Row(children: [
                                Expanded(child: _sCard('Total Sales', CurrencyFormatter.format(totalSales), AppTheme.primary, '💰')),
                                SizedBox(width: 10.w),
                                Expanded(child: _sCard('Total Profit', CurrencyFormatter.format(totalProfit), AppTheme.accent, '📈')),
                              ]),
                            ),
                            // Chart
                            if (spots.length > 1)
                              Container(
                                margin: EdgeInsets.symmetric(horizontal: 16.w),
                                height: 160.h,
                                child: LineChart(LineChartData(
                                  lineBarsData: [
                                    LineChartBarData(
                                      spots: spots,
                                      isCurved: true,
                                      color: AppTheme.primary,
                                      barWidth: 2,
                                      dotData: const FlDotData(show: false),
                                      belowBarData: BarAreaData(
                                          show: true,
                                          color: AppTheme.primary.withOpacity(0.1)),
                                    )
                                  ],
                                  titlesData: const FlTitlesData(
                                    leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                    topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                    rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                    bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                  ),
                                  gridData: const FlGridData(show: false),
                                  borderData: FlBorderData(show: false),
                                )),
                              ),
                            SizedBox(height: 16.h),
                            // Table header
                            Container(
                              margin: EdgeInsets.symmetric(horizontal: 16.w),
                              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                              decoration: BoxDecoration(
                                color: AppTheme.primary.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(8.r),
                              ),
                              child: Row(children: [
                                Expanded(child: Text('Date', style: AppTheme.caption.copyWith(fontWeight: FontWeight.w600))),
                                Text('Bills', style: AppTheme.caption.copyWith(fontWeight: FontWeight.w600)),
                                SizedBox(width: 16.w),
                                SizedBox(width: 80.w, child: Text('Profit', style: AppTheme.caption.copyWith(fontWeight: FontWeight.w600), textAlign: TextAlign.right)),
                              ]),
                            ),
                            ..._data.map((d) => Container(
                              margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 4.h),
                              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8.r),
                                border: Border.all(color: AppTheme.divider),
                              ),
                              child: Row(children: [
                                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Text(d['day'].toString(), style: AppTheme.body.copyWith(fontWeight: FontWeight.w600)),
                                  Text(CurrencyFormatter.format((d['total_sales'] as num).toDouble()),
                                      style: AppTheme.caption),
                                ])),
                                Text('${d['bill_count']}', style: AppTheme.caption),
                                SizedBox(width: 16.w),
                                SizedBox(
                                  width: 80.w,
                                  child: Text(
                                    CurrencyFormatter.format((d['net_profit'] as num? ?? 0).toDouble()),
                                    style: AppTheme.body.copyWith(
                                        fontWeight: FontWeight.w700,
                                        color: (d['net_profit'] as num? ?? 0).toDouble() >= 0
                                            ? AppTheme.accent
                                            : AppTheme.danger),
                                    textAlign: TextAlign.right,
                                  ),
                                ),
                              ]),
                            )),
                            SizedBox(height: 16.h),
                          ]),
                        ),
        ),
      ]),
    );
  }

  Widget _sCard(String label, String value, Color color, String emoji) =>
      Container(
        padding: EdgeInsets.all(12.w),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: AppTheme.divider),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text(emoji, style: TextStyle(fontSize: 16.sp)),
            const Spacer(),
            Container(width: 8.w, height: 8.h, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          ]),
          SizedBox(height: 4.h),
          Text(label, style: AppTheme.caption),
          Text(value, style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w700, color: color, fontFamily: 'Poppins')),
        ]),
      );
}

