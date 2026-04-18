import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';

import '../../../../../core/database/database_helper.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/utils/currency_formatter.dart';
import '../../../data/repositories/report_repository.dart';
import '../../../utils/pdf_export_helper.dart';
import '../../widgets/date_range_filter.dart';

class CashBookPage extends StatefulWidget {
  const CashBookPage({super.key});

  @override
  State<CashBookPage> createState() => _CashBookPageState();
}

class _CashBookPageState extends State<CashBookPage> {
  late final ReportRepository _repo;
  late DateTime _from, _to;
  List<Map<String, dynamic>> _entries = [];
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
      final data = await _repo.getCashBook(from: _from, to: _to);
      setState(() => _entries = data);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _export() async {
    final totalIn = _entries.where((e) => e['flow_type'] == 'in')
        .fold(0.0, (s, e) => s + (e['amount'] as num).toDouble());
    final totalOut = _entries.where((e) => e['flow_type'] == 'out')
        .fold(0.0, (s, e) => s + (e['amount'] as num).toDouble());
    await PdfExportHelper.exportAndShare(
      title: 'Cash Book',
      headers: ['Date', 'Type', 'Description', 'Amount'],
      rows: _entries.map((e) {
        final dateStr = e['date'] as String;
        String formatted;
        try { formatted = DateFormat('dd MMM yyyy').format(DateTime.parse(dateStr)); }
        catch (_) { formatted = dateStr; }
        return [
          formatted,
          e['flow_type'] == 'in' ? 'Receipt' : 'Payment',
          e['description']?.toString() ?? '',
          CurrencyFormatter.format((e['amount'] as num).toDouble()),
        ];
      }).toList(),
      summary: {
        'Total Receipts': CurrencyFormatter.format(totalIn),
        'Total Payments': CurrencyFormatter.format(totalOut),
        'Net': CurrencyFormatter.format(totalIn - totalOut),
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final receipts = _entries.where((e) => e['flow_type'] == 'in').toList();
    final payments = _entries.where((e) => e['flow_type'] == 'out').toList();
    final totalIn = receipts.fold(0.0, (s, e) => s + (e['amount'] as num).toDouble());
    final totalOut = payments.fold(0.0, (s, e) => s + (e['amount'] as num).toDouble());
    final net = totalIn - totalOut;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cash Book'),
        actions: [
          if (_entries.isNotEmpty)
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
        if (_entries.isNotEmpty)
          Container(
            color: Colors.white,
            padding: EdgeInsets.all(16.w),
            child: Row(children: [
              Expanded(child: _statCard('Receipts', CurrencyFormatter.format(totalIn), AppTheme.accent)),
              SizedBox(width: 10.w),
              Expanded(child: _statCard('Payments', CurrencyFormatter.format(totalOut), AppTheme.danger)),
              SizedBox(width: 10.w),
              Expanded(child: _statCard('Net', CurrencyFormatter.format(net),
                  net >= 0 ? AppTheme.accent : AppTheme.danger)),
            ]),
          ),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? Center(child: Text('Error: $_error'))
                  : _entries.isEmpty
                      ? Center(child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('💵', style: TextStyle(fontSize: 48.sp)),
                            SizedBox(height: 12.h),
                            Text('No cash transactions found', style: AppTheme.heading3),
                          ]))
                      : ListView.separated(
                          padding: EdgeInsets.all(16.w),
                          itemCount: _entries.length,
                          separatorBuilder: (_, __) => SizedBox(height: 6.h),
                          itemBuilder: (_, i) {
                            final e = _entries[i];
                            final isIn = e['flow_type'] == 'in';
                            final color = isIn ? AppTheme.accent : AppTheme.danger;
                            final dateStr = e['date'] as String;
                            String dateFormatted;
                            try { dateFormatted = DateFormat('dd MMM yyyy').format(DateTime.parse(dateStr)); }
                            catch (_) { dateFormatted = dateStr; }
                            return Container(
                              padding: EdgeInsets.all(12.w),
                              decoration: BoxDecoration(
                                color: color.withOpacity(0.04),
                                borderRadius: BorderRadius.circular(10.r),
                                border: Border.all(color: color.withOpacity(0.2)),
                              ),
                              child: Row(children: [
                                Icon(isIn ? Icons.arrow_downward : Icons.arrow_upward,
                                    color: color, size: 18.sp),
                                SizedBox(width: 8.w),
                                Expanded(child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(e['description']?.toString() ?? '',
                                        style: AppTheme.body.copyWith(fontWeight: FontWeight.w500),
                                        maxLines: 1, overflow: TextOverflow.ellipsis),
                                    Text(dateFormatted, style: AppTheme.caption),
                                  ],
                                )),
                                Text(CurrencyFormatter.format((e['amount'] as num).toDouble()),
                                    style: AppTheme.body.copyWith(
                                        fontWeight: FontWeight.w700, color: color)),
                              ]),
                            );
                          }),
        ),
      ]),
    );
  }

  Widget _statCard(String label, String value, Color color) => Container(
    padding: EdgeInsets.all(10.w),
    decoration: BoxDecoration(
      color: color.withOpacity(0.08),
      borderRadius: BorderRadius.circular(10.r),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: AppTheme.caption),
      Text(value, style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w700, color: color, fontFamily: 'Poppins'),
          maxLines: 1, overflow: TextOverflow.ellipsis),
    ]),
  );
}
