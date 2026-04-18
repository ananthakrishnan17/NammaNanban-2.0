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

class ModifiedBillReportPage extends StatefulWidget {
  const ModifiedBillReportPage({super.key});

  @override
  State<ModifiedBillReportPage> createState() => _ModifiedBillReportPageState();
}

class _ModifiedBillReportPageState extends State<ModifiedBillReportPage> {
  late final ReportRepository _repo;
  late DateTime _from;
  late DateTime _to;
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
      final data = await _repo.getModifiedBills(from: _from, to: _to);
      setState(() => _bills = data);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _export() async {
    await PdfExportHelper.exportAndShare(
      title: 'Modified Bill Report',
      headers: ['Bill#', 'Customer', 'Amount', 'Note', 'Date'],
      rows: _bills.map((b) => [
        b['bill_number']?.toString() ?? '',
        b['customer_name']?.toString() ?? 'Walk-in',
        CurrencyFormatter.format((b['total_amount'] as num).toDouble()),
        b['modification_note']?.toString() ?? '',
        DateFormat('dd MMM yyyy').format(DateTime.parse(b['created_at'] as String)),
      ]).toList(),
      summary: {
        'Total Bills': _bills.length.toString(),
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
        title: const Text('Modified Bill Report'),
        actions: [
          if (_bills.isNotEmpty)
            IconButton(icon: const Icon(Icons.picture_as_pdf), onPressed: _export)
        ],
      ),
      body: Column(
        children: [
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
                Expanded(child: ReportSummaryCard(label: 'Total Bills',
                    value: _bills.length.toString(), color: AppTheme.primary, emoji: '📝')),
                SizedBox(width: 10.w),
                Expanded(child: ReportSummaryCard(label: 'Total Amount',
                    value: CurrencyFormatter.format(total), color: AppTheme.secondary, emoji: '💰')),
              ]),
            ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(child: Text('Error: $_error', style: AppTheme.caption))
                    : _bills.isEmpty
                        ? _empty()
                        : ListView.separated(
                            padding: EdgeInsets.all(16.w),
                            itemCount: _bills.length,
                            separatorBuilder: (_, __) => SizedBox(height: 8.h),
                            itemBuilder: (_, i) => _BillCard(bill: _bills[i]),
                          ),
          ),
        ],
      ),
    );
  }

  Widget _empty() => Center(
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Text('📝', style: TextStyle(fontSize: 48.sp)),
      SizedBox(height: 12.h),
      Text('No modified bills found', style: AppTheme.heading3),
      SizedBox(height: 4.h),
      Text('Try a different date range', style: AppTheme.caption),
    ]),
  );
}

class _BillCard extends StatelessWidget {
  final Map<String, dynamic> bill;
  const _BillCard({required this.bill});

  @override
  Widget build(BuildContext context) {
    final date = DateTime.parse(bill['created_at'] as String);
    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text('Bill #${bill['bill_number']}',
              style: AppTheme.body.copyWith(fontWeight: FontWeight.w600)),
          const Spacer(),
          Text(CurrencyFormatter.format((bill['total_amount'] as num).toDouble()),
              style: AppTheme.price.copyWith(fontSize: 14.sp)),
        ]),
        SizedBox(height: 4.h),
        Text(bill['customer_name']?.toString() ?? 'Walk-in', style: AppTheme.caption),
        if (bill['modification_note'] != null) ...[
          SizedBox(height: 4.h),
          Text('Note: ${bill['modification_note']}',
              style: AppTheme.caption.copyWith(color: AppTheme.warning)),
        ],
        SizedBox(height: 4.h),
        Text(DateFormat('dd MMM yyyy  h:mm a').format(date), style: AppTheme.caption),
      ]),
    );
  }
}
