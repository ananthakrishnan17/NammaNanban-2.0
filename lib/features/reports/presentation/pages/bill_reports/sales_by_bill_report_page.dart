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

class SalesByBillReportPage extends StatefulWidget {
  const SalesByBillReportPage({super.key});

  @override
  State<SalesByBillReportPage> createState() => _SalesByBillReportPageState();
}

class _SalesByBillReportPageState extends State<SalesByBillReportPage> {
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
      final data = await _repo.getSalesByBill(from: _from, to: _to);
      setState(() => _bills = data);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _export() async {
    final totalSales = _bills.fold(0.0, (s, b) => s + (b['total_amount'] as num).toDouble());
    final totalProfit = _bills.fold(0.0, (s, b) => s + (b['total_profit'] as num? ?? 0).toDouble());
    await PdfExportHelper.exportAndShare(
      title: 'Sales by Bill Report',
      headers: ['Bill#', 'Customer', 'Payment', 'Items', 'Amount'],
      rows: _bills.map((b) => [
        b['bill_number']?.toString() ?? '',
        b['customer_name']?.toString() ?? 'Walk-in',
        b['payment_mode']?.toString() ?? '',
        b['items_summary']?.toString() ?? '',
        CurrencyFormatter.format((b['total_amount'] as num).toDouble()),
      ]).toList(),
      summary: {
        'Total Bills': _bills.length.toString(),
        'Total Sales': CurrencyFormatter.format(totalSales),
        'Total Profit': CurrencyFormatter.format(totalProfit),
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalSales = _bills.fold(0.0, (s, b) => s + (b['total_amount'] as num).toDouble());
    final totalProfit = _bills.fold(0.0, (s, b) => s + (b['total_profit'] as num? ?? 0).toDouble());

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sales by Bill'),
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
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
            child: Row(children: [
              ReportSummaryCard(label: 'Total Bills',
                  value: _bills.length.toString(), color: AppTheme.primary, emoji: '📄'),
              SizedBox(width: 10.w),
              ReportSummaryCard(label: 'Total Sales',
                  value: CurrencyFormatter.format(totalSales), color: AppTheme.accent, emoji: '💰'),
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
                  : _bills.isEmpty
                      ? Center(child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('📄', style: TextStyle(fontSize: 48.sp)),
                            SizedBox(height: 12.h),
                            Text('No bills in this period', style: AppTheme.heading3),
                          ]))
                      : ListView.separated(
                          padding: EdgeInsets.all(16.w),
                          itemCount: _bills.length,
                          separatorBuilder: (_, __) => SizedBox(height: 8.h),
                          itemBuilder: (_, i) => _ExpandableBillCard(bill: _bills[i]),
                        ),
        ),
      ]),
    );
  }
}

class _ExpandableBillCard extends StatefulWidget {
  final Map<String, dynamic> bill;
  const _ExpandableBillCard({required this.bill});

  @override
  State<_ExpandableBillCard> createState() => _ExpandableBillCardState();
}

class _ExpandableBillCardState extends State<_ExpandableBillCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final b = widget.bill;
    final date = DateTime.parse(b['created_at'] as String);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(children: [
        ListTile(
          contentPadding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 4.h),
          title: Text('Bill #${b['bill_number']}',
              style: AppTheme.body.copyWith(fontWeight: FontWeight.w600)),
          subtitle: Text(
              '${b['customer_name'] ?? 'Walk-in'}  •  ${b['payment_mode'] ?? ''}\n'
              '${DateFormat('dd MMM yyyy  h:mm a').format(date)}',
              style: AppTheme.caption),
          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
            Text(CurrencyFormatter.format((b['total_amount'] as num).toDouble()),
                style: AppTheme.price.copyWith(fontSize: 14.sp)),
            Icon(_expanded ? Icons.expand_less : Icons.expand_more,
                color: AppTheme.textSecondary),
          ]),
          onTap: () => setState(() => _expanded = !_expanded),
        ),
        if (_expanded && b['items_summary'] != null)
          Padding(
            padding: EdgeInsets.fromLTRB(14.w, 0, 14.w, 12.h),
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.all(10.w),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(8.r),
              ),
              child: Text(b['items_summary'].toString(),
                  style: AppTheme.caption),
            ),
          ),
      ]),
    );
  }
}
