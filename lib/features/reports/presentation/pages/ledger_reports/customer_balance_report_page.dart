import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';

import '../../../../../core/database/database_helper.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/utils/currency_formatter.dart';
import '../../../data/repositories/report_repository.dart';

class CustomerBalanceReportPage extends StatefulWidget {
  const CustomerBalanceReportPage({super.key});

  @override
  State<CustomerBalanceReportPage> createState() =>
      _CustomerBalanceReportPageState();
}

class _CustomerBalanceReportPageState
    extends State<CustomerBalanceReportPage> {
  late final ReportRepository _repo;
  List<Map<String, dynamic>> _customers = [];
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
      final data = await _repo.getAllCustomerBalances();
      setState(() => _customers = data);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalOutstanding = _customers.fold(
        0.0, (s, c) => s + ((c['outstanding_balance'] as num?)?.toDouble() ?? 0));

    return Scaffold(
      appBar: AppBar(title: const Text('Customer Balance')),
      body: Column(children: [
        if (_customers.isNotEmpty)
          Container(
            color: Colors.white,
            padding: EdgeInsets.all(16.w),
            child: Row(children: [
              Expanded(child: _statCard('Total Customers', _customers.length.toString(), AppTheme.primary)),
              SizedBox(width: 10.w),
              Expanded(child: _statCard('Total Outstanding',
                  CurrencyFormatter.format(totalOutstanding), AppTheme.danger)),
            ]),
          ),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? Center(child: Text('Error: $_error'))
                  : _customers.isEmpty
                      ? Center(child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('👤', style: TextStyle(fontSize: 48.sp)),
                            SizedBox(height: 12.h),
                            Text('No customers found', style: AppTheme.heading3),
                          ]))
                      : ListView.separated(
                          padding: EdgeInsets.all(16.w),
                          itemCount: _customers.length,
                          separatorBuilder: (_, __) => SizedBox(height: 8.h),
                          itemBuilder: (_, i) {
                            final c = _customers[i];
                            final balance = (c['outstanding_balance'] as num?)?.toDouble() ?? 0;
                            return ListTile(
                              contentPadding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 6.h),
                              tileColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12.r),
                                side: BorderSide(color: AppTheme.divider),
                              ),
                              leading: CircleAvatar(
                                backgroundColor: AppTheme.accent.withOpacity(0.1),
                                child: Text(
                                  c['name'].toString().substring(0, 1).toUpperCase(),
                                  style: TextStyle(color: AppTheme.accent, fontWeight: FontWeight.w700, fontFamily: 'Poppins'),
                                ),
                              ),
                              title: Text(c['name'].toString(),
                                  style: AppTheme.body.copyWith(fontWeight: FontWeight.w600)),
                              subtitle: Text(c['phone']?.toString() ?? '', style: AppTheme.caption),
                              trailing: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(CurrencyFormatter.format(balance),
                                      style: AppTheme.body.copyWith(
                                          fontWeight: FontWeight.w700,
                                          color: balance > 0 ? AppTheme.danger : AppTheme.accent)),
                                  Text('outstanding', style: AppTheme.caption),
                                ],
                              ),
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => _CustomerStatementPage(
                                      customerId: c['id'] as int,
                                      customerName: c['name'].toString()),
                                ),
                              ),
                            );
                          }),
        ),
      ]),
    );
  }

  Widget _statCard(String label, String value, Color color) => Container(
    padding: EdgeInsets.all(12.w),
    decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(10.r)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: AppTheme.caption),
      Text(value, style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w700, color: color, fontFamily: 'Poppins'),
          maxLines: 1, overflow: TextOverflow.ellipsis),
    ]),
  );
}

class _CustomerStatementPage extends StatefulWidget {
  final int customerId;
  final String customerName;
  const _CustomerStatementPage({required this.customerId, required this.customerName});

  @override
  State<_CustomerStatementPage> createState() => _CustomerStatementPageState();
}

class _CustomerStatementPageState extends State<_CustomerStatementPage> {
  late final ReportRepository _repo;
  Map<String, dynamic>? _statement;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _repo = ReportRepository(DatabaseHelper.instance);
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final data = await _repo.getCustomerStatement(widget.customerId);
      setState(() => _statement = data);
    } catch (_) {}
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final bills = (_statement?['bills'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final total = bills.fold(0.0, (s, b) => s + (b['total_amount'] as num).toDouble());
    final outstanding = (_statement?['customer']?['outstanding_balance'] as num?)?.toDouble() ?? 0;

    return Scaffold(
      appBar: AppBar(title: Text(widget.customerName)),
      body: Column(children: [
        Container(
          color: Colors.white,
          padding: EdgeInsets.all(16.w),
          child: Row(children: [
            Expanded(child: _sCard('Total Billed', CurrencyFormatter.format(total), AppTheme.primary)),
            SizedBox(width: 10.w),
            Expanded(child: _sCard('Outstanding', CurrencyFormatter.format(outstanding),
                outstanding > 0 ? AppTheme.danger : AppTheme.accent)),
          ]),
        ),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : bills.isEmpty
                  ? Center(child: Text('No bills found', style: AppTheme.caption))
                  : ListView.separated(
                      padding: EdgeInsets.all(16.w),
                      itemCount: bills.length,
                      separatorBuilder: (_, __) => SizedBox(height: 8.h),
                      itemBuilder: (_, i) {
                        final b = bills[i];
                        final date = DateTime.parse(b['created_at'] as String);
                        return Container(
                          padding: EdgeInsets.all(12.w),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10.r),
                            border: Border.all(color: AppTheme.divider),
                          ),
                          child: Row(children: [
                            Expanded(child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Bill #${b['bill_number']}',
                                    style: AppTheme.body.copyWith(fontWeight: FontWeight.w600)),
                                Text('${b['payment_mode'] ?? ''}  •  ${DateFormat('dd MMM yyyy').format(date)}',
                                    style: AppTheme.caption),
                              ],
                            )),
                            Text(CurrencyFormatter.format((b['total_amount'] as num).toDouble()),
                                style: AppTheme.body.copyWith(fontWeight: FontWeight.w700, color: AppTheme.primary)),
                          ]),
                        );
                      }),
        ),
      ]),
    );
  }

  Widget _sCard(String label, String value, Color color) => Container(
    padding: EdgeInsets.all(10.w),
    decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(8.r)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: AppTheme.caption),
      Text(value, style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w700, color: color, fontFamily: 'Poppins'),
          maxLines: 1, overflow: TextOverflow.ellipsis),
    ]),
  );
}
