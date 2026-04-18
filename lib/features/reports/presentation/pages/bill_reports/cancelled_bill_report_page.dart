import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';

import '../../../../../core/database/database_helper.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/utils/currency_formatter.dart';
import '../../../data/repositories/report_repository.dart';
import '../../../utils/pdf_export_helper.dart';
import '../../widgets/date_range_filter.dart';
import '../../widgets/report_summary_card.dart';

class CancelledBillReportPage extends StatefulWidget {
  const CancelledBillReportPage({super.key});

  @override
  State<CancelledBillReportPage> createState() =>
      _CancelledBillReportPageState();
}

class _CancelledBillReportPageState extends State<CancelledBillReportPage> {
  late final ReportRepository _repo;
  late DateTime _from, _to;
  List<Map<String, dynamic>> _bills = [];
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
      final data = await _repo.getCancelledBills(from: _from, to: _to);
      setState(() => _bills = data);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _export() async {
    await PdfExportHelper.exportAndShare(
      title: 'Cancelled Bill Report',
      headers: ['Bill#', 'Customer', 'Amount', 'Date'],
      rows: _bills.map((b) => [
        b['bill_number']?.toString() ?? '',
        b['customer_name']?.toString() ?? 'Walk-in',
        CurrencyFormatter.format((b['total_amount'] as num).toDouble()),
        DateFormat('dd MMM yyyy').format(DateTime.parse(b['created_at'] as String)),
      ]).toList(),
      summary: {
        'Total Cancelled': _bills.length.toString(),
        'Total Amount': CurrencyFormatter.format(
            _bills.fold(0.0, (s, b) => s + (b['total_amount'] as num).toDouble())),
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final total = _bills.fold(0.0, (s, b) => s + (b['total_amount'] as num).toDouble());
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cancelled Bill Report'),
        actions: [
          if (_bills.isNotEmpty)
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
        if (_bills.isNotEmpty)
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
            child: Row(children: [
              Expanded(child: ReportSummaryCard(label: 'Cancelled Bills',
                  value: _bills.length.toString(), color: AppTheme.danger, emoji: '❌')),
              SizedBox(width: 10.w),
              Expanded(child: ReportSummaryCard(label: 'Total Amount',
                  value: CurrencyFormatter.format(total), color: AppTheme.secondary, emoji: '💰')),
            ]),
          ),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? Center(child: Text('Error: $_error'))
                  : _bills.isEmpty
                      ? Center(child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('❌', style: TextStyle(fontSize: 48.sp)),
                            SizedBox(height: 12.h),
                            Text('No cancelled bills', style: AppTheme.heading3),
                          ]))
                      : ListView.separated(
                          padding: EdgeInsets.all(16.w),
                          itemCount: _bills.length,
                          separatorBuilder: (_, __) => SizedBox(height: 8.h),
                          itemBuilder: (_, i) {
                            final b = _bills[i];
                            final date = DateTime.parse(b['created_at'] as String);
                            return Container(
                              padding: EdgeInsets.all(14.w),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12.r),
                                border: Border.all(color: AppTheme.danger.withOpacity(0.3)),
                              ),
                              child: Row(children: [
                                Expanded(child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Bill #${b['bill_number']}',
                                        style: AppTheme.body.copyWith(fontWeight: FontWeight.w600)),
                                    Text(b['customer_name']?.toString() ?? 'Walk-in',
                                        style: AppTheme.caption),
                                    Text(DateFormat('dd MMM yyyy').format(date),
                                        style: AppTheme.caption),
                                  ],
                                )),
                                Text(CurrencyFormatter.format((b['total_amount'] as num).toDouble()),
                                    style: AppTheme.price.copyWith(
                                        fontSize: 14.sp, color: AppTheme.danger)),
                              ]),
                            );
                          }),
        ),
      ]),
    );
  }
}
