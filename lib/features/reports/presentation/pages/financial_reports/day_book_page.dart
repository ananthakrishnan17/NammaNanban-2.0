import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';

import '../../../../../core/database/database_helper.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/utils/currency_formatter.dart';
import '../../../data/repositories/report_repository.dart';
import '../../../utils/pdf_export_helper.dart';
import '../../widgets/date_range_filter.dart';

class DayBookPage extends StatefulWidget {
  const DayBookPage({super.key});

  @override
  State<DayBookPage> createState() => _DayBookPageState();
}

class _DayBookPageState extends State<DayBookPage> {
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
      final data = await _repo.getDayBook(from: _from, to: _to);
      setState(() => _entries = data);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _export() async {
    await PdfExportHelper.exportAndShare(
      title: 'Day Book',
      headers: ['Date', 'Type', 'Description', 'Amount', 'Payment'],
      rows: _entries.map((e) {
        final dateStr = e['date'] as String;
        String formatted;
        try { formatted = DateFormat('dd MMM yyyy').format(DateTime.parse(dateStr)); }
        catch (_) { formatted = dateStr; }
        return [
          formatted,
          e['tx_type']?.toString() ?? '',
          e['description']?.toString() ?? '',
          CurrencyFormatter.format((e['amount'] as num).toDouble()),
          e['payment_mode']?.toString() ?? '',
        ];
      }).toList(),
    );
  }

  Color _typeColor(String type) {
    switch (type) {
      case 'sale': return AppTheme.accent;
      case 'purchase': return AppTheme.danger;
      case 'expense': return AppTheme.warning;
      case 'return': return AppTheme.secondary;
      default: return AppTheme.textSecondary;
    }
  }

  String _typeEmoji(String type) {
    switch (type) {
      case 'sale': return '💰';
      case 'purchase': return '🏭';
      case 'expense': return '💸';
      case 'return': return '↩️';
      default: return '📋';
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalIn = _entries
        .where((e) => e['tx_type'] == 'sale')
        .fold(0.0, (s, e) => s + (e['amount'] as num).toDouble());
    final totalOut = _entries
        .where((e) => e['tx_type'] != 'sale')
        .fold(0.0, (s, e) => s + (e['amount'] as num).toDouble());
    final net = totalIn - totalOut;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Day Book'),
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
              Expanded(child: _statCard('Total In', CurrencyFormatter.format(totalIn), AppTheme.accent)),
              SizedBox(width: 8.w),
              Expanded(child: _statCard('Total Out', CurrencyFormatter.format(totalOut), AppTheme.danger)),
              SizedBox(width: 8.w),
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
                            Text('📖', style: TextStyle(fontSize: 48.sp)),
                            SizedBox(height: 12.h),
                            Text('No transactions found', style: AppTheme.heading3),
                          ]))
                      : ListView.separated(
                          padding: EdgeInsets.all(16.w),
                          itemCount: _entries.length,
                          separatorBuilder: (_, __) => SizedBox(height: 6.h),
                          itemBuilder: (_, i) {
                            final e = _entries[i];
                            final type = e['tx_type']?.toString() ?? '';
                            final color = _typeColor(type);
                            final dateStr = e['date'] as String;
                            String dateFormatted;
                            try { dateFormatted = DateFormat('dd MMM yyyy HH:mm').format(DateTime.parse(dateStr)); }
                            catch (_) { dateFormatted = dateStr; }
                            return Container(
                              padding: EdgeInsets.all(12.w),
                              decoration: BoxDecoration(
                                color: color.withOpacity(0.04),
                                borderRadius: BorderRadius.circular(10.r),
                                border: Border.all(color: color.withOpacity(0.2)),
                              ),
                              child: Row(children: [
                                Text(_typeEmoji(type), style: TextStyle(fontSize: 18.sp)),
                                SizedBox(width: 10.w),
                                Expanded(child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(e['description']?.toString() ?? '',
                                        style: AppTheme.body.copyWith(fontWeight: FontWeight.w500),
                                        maxLines: 1, overflow: TextOverflow.ellipsis),
                                    Text('$dateFormatted  •  ${e['payment_mode'] ?? ''}',
                                        style: AppTheme.caption),
                                  ],
                                )),
                                Text(CurrencyFormatter.format((e['amount'] as num).toDouble()),
                                    style: AppTheme.body.copyWith(fontWeight: FontWeight.w700, color: color)),
                              ]),
                            );
                          }),
        ),
      ]),
    );
  }

  Widget _statCard(String label, String value, Color color) => Container(
    padding: EdgeInsets.all(8.w),
    decoration: BoxDecoration(
      color: color.withOpacity(0.08),
      borderRadius: BorderRadius.circular(8.r),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: AppTheme.caption),
      Text(value, style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.w700, color: color, fontFamily: 'Poppins'),
          maxLines: 1, overflow: TextOverflow.ellipsis),
    ]),
  );
}
