import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../../core/database/database_helper.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/utils/currency_formatter.dart';
import '../../../data/repositories/report_repository.dart';
import '../../../utils/pdf_export_helper.dart';
import '../../widgets/date_range_filter.dart';

class CashierSalesReportPage extends StatefulWidget {
  const CashierSalesReportPage({super.key});

  @override
  State<CashierSalesReportPage> createState() => _CashierSalesReportPageState();
}

class _CashierSalesReportPageState extends State<CashierSalesReportPage> {
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
      final data = await _repo.getCashierWiseSales(from: _from, to: _to);
      setState(() => _data = data);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _export() async {
    await PdfExportHelper.exportAndShare(
      title: 'Cashier-wise Sales Report',
      headers: ['Cashier', 'Bills', 'Total Sales', 'Total Profit'],
      rows: _data.map((d) => [
        d['cashier_name'].toString(),
        d['bill_count'].toString(),
        CurrencyFormatter.format((d['total_sales'] as num).toDouble()),
        CurrencyFormatter.format((d['total_profit'] as num? ?? 0).toDouble()),
      ]).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalSales = _data.fold(0.0, (s, d) => s + (d['total_sales'] as num).toDouble());

    final colors = [AppTheme.primary, AppTheme.accent, AppTheme.secondary, AppTheme.warning, AppTheme.danger];
    final sections = _data.asMap().entries.map((e) => PieChartSectionData(
      value: (e.value['total_sales'] as num).toDouble(),
      color: colors[e.key % colors.length],
      title: totalSales > 0
          ? '${((e.value['total_sales'] as num).toDouble() / totalSales * 100).toStringAsFixed(0)}%'
          : '',
      radius: 60.r,
      titleStyle: TextStyle(fontSize: 10.sp, fontWeight: FontWeight.w700, color: Colors.white, fontFamily: 'Poppins'),
    )).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cashier-wise Sales'),
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
                            Text('👨‍💼', style: TextStyle(fontSize: 48.sp)),
                            SizedBox(height: 12.h),
                            Text('No cashier data found', style: AppTheme.heading3),
                          ]))
                      : SingleChildScrollView(
                          child: Column(children: [
                            if (sections.isNotEmpty)
                              Container(
                                height: 200.h,
                                margin: EdgeInsets.all(16.w),
                                child: PieChart(PieChartData(
                                  sections: sections,
                                  centerSpaceRadius: 40.r,
                                  sectionsSpace: 2,
                                )),
                              ),
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: 16.w),
                              child: Column(
                                children: _data.asMap().entries.map((e) {
                                  final d = e.value;
                                  final color = colors[e.key % colors.length];
                                  return Container(
                                    margin: EdgeInsets.only(bottom: 8.h),
                                    padding: EdgeInsets.all(14.w),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(12.r),
                                      border: Border.all(color: color.withOpacity(0.3)),
                                    ),
                                    child: Row(children: [
                                      Container(
                                        width: 12.w, height: 12.h,
                                        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                                      ),
                                      SizedBox(width: 10.w),
                                      Expanded(child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(d['cashier_name'].toString(),
                                              style: AppTheme.body.copyWith(fontWeight: FontWeight.w600)),
                                          Text('${d['bill_count']} bills',
                                              style: AppTheme.caption),
                                        ],
                                      )),
                                      Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                                        Text(CurrencyFormatter.format((d['total_sales'] as num).toDouble()),
                                            style: AppTheme.body.copyWith(fontWeight: FontWeight.w700, color: color)),
                                        Text('Profit: ${CurrencyFormatter.format((d['total_profit'] as num? ?? 0).toDouble())}',
                                            style: AppTheme.caption.copyWith(color: AppTheme.accent)),
                                      ]),
                                    ]),
                                  );
                                }).toList(),
                              ),
                            ),
                            SizedBox(height: 16.h),
                          ]),
                        ),
        ),
      ]),
    );
  }
}
