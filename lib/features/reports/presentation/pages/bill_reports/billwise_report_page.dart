import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';

import '../../../../../core/database/database_helper.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/utils/currency_formatter.dart';
import '../../../../billing/presentation/pages/bill_view_screen.dart';
import '../../../data/repositories/report_repository.dart';
import '../../../utils/pdf_export_helper.dart';
import '../../widgets/date_range_filter.dart';
import '../../widgets/report_summary_card.dart';

class BillwiseReportPage extends StatefulWidget {
  const BillwiseReportPage({super.key});

  @override
  State<BillwiseReportPage> createState() => _BillwiseReportPageState();
}

class _BillwiseReportPageState extends State<BillwiseReportPage> {
  late final ReportRepository _repo;
  late DateTime _from, _to;
  List<Map<String, dynamic>> _bills = [];
  bool _isLoading = false;
  String? _error;
  int _totalBillCount = 0;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _repo = ReportRepository(DatabaseHelper.instance);
    final now = DateTime.now();
    _from = DateTime(now.year, now.month, 1);
    _to = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
    _load();
    _loadTotalCount();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadTotalCount() async {
    try {
      final count = await _repo.getTotalBillCount();
      if (mounted) setState(() => _totalBillCount = count);
    } catch (_) {}
  }

  Future<void> _load() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final data = await _repo.getBillwiseReport(from: _from, to: _to);
      setState(() => _bills = data);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> get _filteredBills {
    if (_searchQuery.isEmpty) return _bills;
    final q = _searchQuery.toLowerCase();
    return _bills.where((b) {
      final billNum = (b['bill_number'] ?? '').toString().toLowerCase();
      final customer = (b['customer_name'] ?? '').toString().toLowerCase();
      return billNum.contains(q) || customer.contains(q);
    }).toList();
  }

  Future<void> _export() async {
    final bills = _filteredBills;
    final totalSales = bills.fold(0.0, (s, b) => s + (b['total_amount'] as num).toDouble());
    final avg = bills.isEmpty ? 0.0 : totalSales / bills.length;
    await PdfExportHelper.exportAndShare(
      title: 'Bill-wise Report',
      headers: ['Bill#', 'Date/Time', 'Customer', 'Payment', 'Items', 'Total'],
      rows: bills.map((b) => [
        b['bill_number']?.toString() ?? '',
        DateFormat('dd MMM yy HH:mm').format(DateTime.parse(b['created_at'] as String)),
        b['customer_name']?.toString() ?? 'Walk-in',
        b['payment_mode']?.toString() ?? '',
        b['item_count']?.toString() ?? '0',
        CurrencyFormatter.format((b['total_amount'] as num).toDouble()),
      ]).toList(),
      summary: {
        'Total Bills': bills.length.toString(),
        'Total Sales': CurrencyFormatter.format(totalSales),
        'Avg Bill Value': CurrencyFormatter.format(avg),
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final bills = _filteredBills;
    final totalSales = bills.fold(0.0, (s, b) => s + (b['total_amount'] as num).toDouble());
    final avg = bills.isEmpty ? 0.0 : totalSales / bills.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bill-wise Report'),
        subtitle: Text('All-time: $_totalBillCount bills', style: const TextStyle(fontSize: 12)),
        actions: [
          if (bills.isNotEmpty)
            IconButton(icon: const Icon(Icons.picture_as_pdf), onPressed: _export)
        ],
      ),
      body: Column(children: [
        Container(
          color: Colors.white,
          padding: EdgeInsets.all(16.w),
          child: Column(
            children: [
              DateRangeFilter(
                  from: _from, to: _to,
                  onChanged: (f, t) { setState(() { _from = f; _to = t; }); _load(); }),
              SizedBox(height: 10.h),
              TextField(
                controller: _searchController,
                onChanged: (v) => setState(() => _searchQuery = v.trim()),
                decoration: InputDecoration(
                  hintText: 'Search by bill number or customer...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          })
                      : null,
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(vertical: 10.h),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10.r)),
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
        if (bills.isNotEmpty)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
            child: Row(children: [
              ReportSummaryCard(label: 'Total Bills',
                  value: bills.length.toString(), color: AppTheme.primary, emoji: '🧾'),
              SizedBox(width: 10.w),
              ReportSummaryCard(label: 'Total Sales',
                  value: CurrencyFormatter.format(totalSales), color: AppTheme.accent, emoji: '💰'),
              SizedBox(width: 10.w),
              ReportSummaryCard(label: 'Avg Bill Value',
                  value: CurrencyFormatter.format(avg), color: AppTheme.secondary, emoji: '📊'),
            ]),
          ),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? Center(child: Text('Error: $_error'))
                  : bills.isEmpty
                      ? Center(child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('🧾', style: TextStyle(fontSize: 48.sp)),
                            SizedBox(height: 12.h),
                            Text(_searchQuery.isNotEmpty ? 'No matching bills' : 'No bills in this period',
                                style: AppTheme.heading3),
                          ]))
                      : ListView.separated(
                          padding: EdgeInsets.all(16.w),
                          itemCount: bills.length,
                          separatorBuilder: (_, __) => SizedBox(height: 8.h),
                          itemBuilder: (_, i) {
                            final b = bills[i];
                            final date = DateTime.parse(b['created_at'] as String);
                            return GestureDetector(
                              onTap: () async {
                                try {
                                  final bill = await _repo.getBillById(b['id'] as int);
                                  if (!mounted) return;
                                  Navigator.push(context,
                                    MaterialPageRoute(builder: (_) => BillViewScreen(bill: bill)));
                                } catch (e) {
                                  if (!mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Failed to load bill: $e')));
                                }
                              },
                              child: Container(
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
                                    Text('Bill #${b['bill_number']}',
                                        style: AppTheme.body.copyWith(fontWeight: FontWeight.w600)),
                                    SizedBox(height: 2.h),
                                    Text('${b['customer_name'] ?? 'Walk-in'}  •  ${b['payment_mode'] ?? ''}',
                                        style: AppTheme.caption),
                                    Text(DateFormat('dd MMM yyyy  h:mm a').format(date),
                                        style: AppTheme.caption),
                                    if (b['items_summary'] != null)
                                      Text(b['items_summary'].toString(),
                                          style: AppTheme.caption,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis),
                                  ],
                                )),
                                Text(CurrencyFormatter.format((b['total_amount'] as num).toDouble()),
                                    style: AppTheme.price.copyWith(fontSize: 14.sp)),
                              ]),
                            ),
                            );
                          }),
        ),
      ]),
    );
  }
}
