import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';

import '../../../../../core/database/database_helper.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/utils/currency_formatter.dart';
import '../../../data/repositories/report_repository.dart';
import '../../../utils/pdf_export_helper.dart';
import '../../widgets/date_range_filter.dart';

class ItemwiseReportPage extends StatefulWidget {
  const ItemwiseReportPage({super.key});

  @override
  State<ItemwiseReportPage> createState() => _ItemwiseReportPageState();
}

class _ItemwiseReportPageState extends State<ItemwiseReportPage> {
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
      final data = await _repo.getItemwiseReport(from: _from, to: _to);
      setState(() => _items = data);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _export() async {
    await PdfExportHelper.exportAndShare(
      title: 'Item-wise Report',
      headers: ['Product', 'Bill#', 'Qty', 'Unit Price', 'Total', 'Date'],
      rows: _items.map((it) => [
        it['product_name'].toString(),
        it['bill_number']?.toString() ?? '',
        (it['quantity'] as num).toStringAsFixed(1),
        CurrencyFormatter.format((it['unit_price'] as num).toDouble()),
        CurrencyFormatter.format((it['total_price'] as num).toDouble()),
        DateFormat('dd MMM yyyy').format(DateTime.parse(it['created_at'] as String)),
      ]).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Item-wise Report'),
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
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? Center(child: Text('Error: $_error'))
                  : _items.isEmpty
                      ? Center(child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('📋', style: TextStyle(fontSize: 48.sp)),
                            SizedBox(height: 12.h),
                            Text('No item data found', style: AppTheme.heading3),
                          ]))
                      : ListView.separated(
                          padding: EdgeInsets.all(16.w),
                          itemCount: _items.length,
                          separatorBuilder: (_, __) => SizedBox(height: 8.h),
                          itemBuilder: (_, i) {
                            final it = _items[i];
                            final date = DateTime.parse(it['created_at'] as String);
                            return Container(
                              padding: EdgeInsets.all(14.w),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12.r),
                                border: Border.all(color: AppTheme.divider),
                              ),
                              child: Row(children: [
                                Expanded(child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(it['product_name'].toString(),
                                        style: AppTheme.body.copyWith(fontWeight: FontWeight.w600)),
                                    Text('Bill #${it['bill_number']}  •  Qty: ${(it['quantity'] as num).toStringAsFixed(1)}',
                                        style: AppTheme.caption),
                                    Text('@ ${CurrencyFormatter.format((it['unit_price'] as num).toDouble())}  •  ${DateFormat('dd MMM yyyy').format(date)}',
                                        style: AppTheme.caption),
                                  ],
                                )),
                                Text(CurrencyFormatter.format((it['total_price'] as num).toDouble()),
                                    style: AppTheme.body.copyWith(fontWeight: FontWeight.w700, color: AppTheme.primary)),
                              ]),
                            );
                          }),
        ),
      ]),
    );
  }
}
