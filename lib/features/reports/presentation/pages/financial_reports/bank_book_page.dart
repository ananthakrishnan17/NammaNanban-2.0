import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';

import '../../../../../core/database/database_helper.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/utils/currency_formatter.dart';
import '../../../data/repositories/report_repository.dart';
import '../../../utils/pdf_export_helper.dart';
import '../../widgets/date_range_filter.dart';

class BankBookPage extends StatefulWidget {
  const BankBookPage({super.key});

  @override
  State<BankBookPage> createState() => _BankBookPageState();
}

class _BankBookPageState extends State<BankBookPage>
    with SingleTickerProviderStateMixin {
  late final ReportRepository _repo;
  late TabController _tabs;
  late DateTime _from, _to;
  List<Map<String, dynamic>> _entries = [];
  bool _isLoading = false;
  String? _error;

  static const _tabModes = [null, 'upi', 'card', 'bank'];
  static const _tabLabels = ['All Digital', 'UPI', 'Card', 'Bank'];

  @override
  void initState() {
    super.initState();
    _repo = ReportRepository(DatabaseHelper.instance);
    _tabs = TabController(length: 4, vsync: this);
    _tabs.addListener(() { if (!_tabs.indexIsChanging) _load(); });
    final now = DateTime.now();
    _from = DateTime(now.year, now.month, 1);
    _to = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final data = await _repo.getBankBook(
          from: _from, to: _to, mode: _tabModes[_tabs.index]);
      setState(() => _entries = data);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _export() async {
    final total = _entries.fold(0.0, (s, e) => s + (e['amount'] as num).toDouble());
    await PdfExportHelper.exportAndShare(
      title: 'Bank Book - ${_tabLabels[_tabs.index]}',
      headers: ['Date', 'Description', 'Amount'],
      rows: _entries.map((e) {
        final dateStr = e['date'] as String;
        String formatted;
        try { formatted = DateFormat('dd MMM yyyy').format(DateTime.parse(dateStr)); }
        catch (_) { formatted = dateStr; }
        return [formatted, e['description']?.toString() ?? '', CurrencyFormatter.format((e['amount'] as num).toDouble())];
      }).toList(),
      summary: {'Total': CurrencyFormatter.format(total)},
    );
  }

  @override
  Widget build(BuildContext context) {
    final total = _entries.fold(0.0, (s, e) => s + (e['amount'] as num).toDouble());

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bank Book'),
        actions: [
          if (_entries.isNotEmpty)
            IconButton(icon: const Icon(Icons.picture_as_pdf), onPressed: _export)
        ],
        bottom: TabBar(
          controller: _tabs,
          labelColor: AppTheme.primary,
          unselectedLabelColor: AppTheme.textSecondary,
          indicatorColor: AppTheme.primary,
          tabs: _tabLabels.map((l) => Tab(text: l)).toList(),
        ),
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
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
            child: Row(children: [
              Text('Total: ', style: AppTheme.body),
              Text(CurrencyFormatter.format(total),
                  style: AppTheme.body.copyWith(fontWeight: FontWeight.w700, color: AppTheme.accent)),
              Text(' (${_entries.length} transactions)', style: AppTheme.caption),
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
                            Text('🏦', style: TextStyle(fontSize: 48.sp)),
                            SizedBox(height: 12.h),
                            Text('No digital transactions found', style: AppTheme.heading3),
                          ]))
                      : ListView.separated(
                          padding: EdgeInsets.all(16.w),
                          itemCount: _entries.length,
                          separatorBuilder: (_, __) => SizedBox(height: 6.h),
                          itemBuilder: (_, i) {
                            final e = _entries[i];
                            final dateStr = e['date'] as String;
                            String dateFormatted;
                            try { dateFormatted = DateFormat('dd MMM yyyy').format(DateTime.parse(dateStr)); }
                            catch (_) { dateFormatted = dateStr; }
                            return Container(
                              padding: EdgeInsets.all(12.w),
                              decoration: BoxDecoration(
                                color: AppTheme.accent.withOpacity(0.04),
                                borderRadius: BorderRadius.circular(10.r),
                                border: Border.all(color: AppTheme.accent.withOpacity(0.2)),
                              ),
                              child: Row(children: [
                                Icon(Icons.account_balance, color: AppTheme.secondary, size: 18.sp),
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
                                        fontWeight: FontWeight.w700, color: AppTheme.accent)),
                              ]),
                            );
                          }),
        ),
      ]),
    );
  }
}
