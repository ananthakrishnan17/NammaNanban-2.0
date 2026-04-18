import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../../core/database/database_helper.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/utils/currency_formatter.dart';
import '../../../data/repositories/report_repository.dart';

class HourlySalesReportPage extends StatefulWidget {
  const HourlySalesReportPage({super.key});

  @override
  State<HourlySalesReportPage> createState() => _HourlySalesReportPageState();
}

class _HourlySalesReportPageState extends State<HourlySalesReportPage> {
  late final ReportRepository _repo;
  DateTime _date = DateTime.now();
  List<Map<String, dynamic>> _data = [];
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _repo = ReportRepository(DatabaseHelper.instance);
    _load();
  }

  Future<void> _load() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final data = await _repo.getHourlySalesReport(_date);
      setState(() => _data = data);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(colorScheme: ColorScheme.light(primary: AppTheme.primary)),
        child: child!,
      ),
    );
    if (picked != null) { setState(() => _date = picked); _load(); }
  }

  String? _peakHour() {
    if (_data.isEmpty) return null;
    final peak = _data.reduce((a, b) =>
        (a['total_sales'] as num) > (b['total_sales'] as num) ? a : b);
    return '${peak['hour']}:00';
  }

  @override
  Widget build(BuildContext context) {
    final totalSales = _data.fold(0.0, (s, d) => s + (d['total_sales'] as num).toDouble());
    final totalBills = _data.fold(0, (s, d) => s + (d['bill_count'] as num).toInt());
    final peak = _peakHour();

    // Build bar chart groups
    final groups = List.generate(24, (h) {
      final row = _data.firstWhere(
          (d) => int.tryParse(d['hour'].toString()) == h,
          orElse: () => {'hour': h, 'total_sales': 0.0, 'bill_count': 0});
      final isPeak = peak != null && peak == '$h:00';
      return BarChartGroupData(
        x: h,
        barRods: [
          BarChartRodData(
            toY: (row['total_sales'] as num).toDouble(),
            color: isPeak ? AppTheme.primary : AppTheme.primary.withOpacity(0.5),
            width: 8.w,
            borderRadius: BorderRadius.circular(4.r),
          )
        ],
      );
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Hourly Sales Report')),
      body: Column(children: [
        Container(
          color: Colors.white,
          padding: EdgeInsets.all(16.w),
          child: Row(children: [
            Text('Date:', style: AppTheme.body),
            SizedBox(width: 12.w),
            GestureDetector(
              onTap: _pickDate,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
                decoration: BoxDecoration(
                  border: Border.all(color: AppTheme.primary),
                  borderRadius: BorderRadius.circular(10.r),
                ),
                child: Row(children: [
                  Icon(Icons.calendar_today, size: 14.sp, color: AppTheme.primary),
                  SizedBox(width: 6.w),
                  Text('${_date.day}/${_date.month}/${_date.year}',
                      style: TextStyle(fontSize: 13.sp, fontFamily: 'Poppins')),
                ]),
              ),
            ),
            const Spacer(),
            if (peak != null)
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20.r),
                ),
                child: Text('⚡ Peak: $peak',
                    style: TextStyle(
                        fontSize: 11.sp,
                        color: AppTheme.primary,
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.w600)),
              ),
          ]),
        ),
        if (_data.isNotEmpty)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
            child: Row(children: [
              _card('Total Sales', CurrencyFormatter.format(totalSales), AppTheme.primary, '💰'),
              SizedBox(width: 10.w),
              _card('Total Bills', totalBills.toString(), AppTheme.accent, '🧾'),
            ]),
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
                            Text('⏰', style: TextStyle(fontSize: 48.sp)),
                            SizedBox(height: 12.h),
                            Text('No sales on this date', style: AppTheme.heading3),
                          ]))
                      : SingleChildScrollView(
                          child: Column(children: [
                            // Bar Chart
                            Container(
                              margin: EdgeInsets.all(16.w),
                              height: 180.h,
                              child: BarChart(BarChartData(
                                barGroups: groups,
                                titlesData: FlTitlesData(
                                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                  bottomTitles: AxisTitles(
                                    sideTitles: SideTitles(
                                      showTitles: true,
                                      getTitlesWidget: (v, _) {
                                        if (v % 4 != 0) return const SizedBox.shrink();
                                        return Text('${v.toInt()}h',
                                            style: TextStyle(fontSize: 9.sp, fontFamily: 'Poppins'));
                                      },
                                    ),
                                  ),
                                ),
                                gridData: const FlGridData(show: false),
                                borderData: FlBorderData(show: false),
                              )),
                            ),
                            // List
                            ..._data.map((d) {
                              final h = int.tryParse(d['hour'].toString()) ?? 0;
                              final isPeak = peak == '$h:00';
                              return Container(
                                margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 4.h),
                                padding: EdgeInsets.all(12.w),
                                decoration: BoxDecoration(
                                  color: isPeak ? AppTheme.primary.withOpacity(0.06) : Colors.white,
                                  borderRadius: BorderRadius.circular(10.r),
                                  border: Border.all(
                                      color: isPeak ? AppTheme.primary : AppTheme.divider),
                                ),
                                child: Row(children: [
                                  Text('${h.toString().padLeft(2, '0')}:00 - ${(h + 1).toString().padLeft(2, '0')}:00',
                                      style: AppTheme.body.copyWith(fontWeight: FontWeight.w500)),
                                  const Spacer(),
                                  Text('${d['bill_count']} bills', style: AppTheme.caption),
                                  SizedBox(width: 16.w),
                                  Text(CurrencyFormatter.format((d['total_sales'] as num).toDouble()),
                                      style: AppTheme.body.copyWith(
                                          fontWeight: FontWeight.w700,
                                          color: AppTheme.primary)),
                                ]),
                              );
                            }),
                            SizedBox(height: 16.h),
                          ]),
                        ),
        ),
      ]),
    );
  }

  Widget _card(String label, String value, Color color, String emoji) {
    return Container(
      width: 140.w,
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(emoji, style: TextStyle(fontSize: 18.sp)),
        SizedBox(height: 4.h),
        Text(label, style: AppTheme.caption),
        Text(value, style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w700, color: color, fontFamily: 'Poppins')),
      ]),
    );
  }
}
