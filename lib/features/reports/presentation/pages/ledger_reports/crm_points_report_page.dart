import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';

import '../../../../../core/database/database_helper.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../data/repositories/report_repository.dart';

class CrmPointsReportPage extends StatefulWidget {
  const CrmPointsReportPage({super.key});

  @override
  State<CrmPointsReportPage> createState() => _CrmPointsReportPageState();
}

class _CrmPointsReportPageState extends State<CrmPointsReportPage> {
  late final ReportRepository _repo;
  List<Map<String, dynamic>> _balances = [];
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
      final data = await _repo.getCRMPointsBalances();
      setState(() => _balances = data);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('CRM Points')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text('Error: $_error'))
              : _balances.isEmpty
                  ? Center(child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('⭐', style: TextStyle(fontSize: 48.sp)),
                        SizedBox(height: 12.h),
                        Text('No CRM data yet', style: AppTheme.heading3),
                        SizedBox(height: 8.h),
                        Text('CRM points will appear here once customers earn points.',
                            style: AppTheme.caption, textAlign: TextAlign.center),
                      ]))
                  : ListView.separated(
                      padding: EdgeInsets.all(16.w),
                      itemCount: _balances.length,
                      separatorBuilder: (_, __) => SizedBox(height: 8.h),
                      itemBuilder: (_, i) {
                        final b = _balances[i];
                        final points = (b['total_points'] as num?)?.toDouble() ?? 0;
                        return ListTile(
                          contentPadding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 6.h),
                          tileColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12.r),
                            side: BorderSide(color: AppTheme.divider),
                          ),
                          leading: CircleAvatar(
                            backgroundColor: AppTheme.warning.withOpacity(0.1),
                            child: Text('⭐', style: TextStyle(fontSize: 16.sp)),
                          ),
                          title: Text(b['customer_name'].toString(),
                              style: AppTheme.body.copyWith(fontWeight: FontWeight.w600)),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text('${points.toStringAsFixed(1)} pts',
                                  style: TextStyle(
                                      fontSize: 14.sp,
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.warning,
                                      fontFamily: 'Poppins')),
                              Text('total points', style: AppTheme.caption),
                            ],
                          ),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => _CrmStatementPage(
                                  customerId: b['customer_id'] as int,
                                  customerName: b['customer_name'].toString()),
                            ),
                          ),
                        );
                      }),
    );
  }
}

class _CrmStatementPage extends StatefulWidget {
  final int customerId;
  final String customerName;
  const _CrmStatementPage({required this.customerId, required this.customerName});

  @override
  State<_CrmStatementPage> createState() => _CrmStatementPageState();
}

class _CrmStatementPageState extends State<_CrmStatementPage> {
  late final ReportRepository _repo;
  List<Map<String, dynamic>> _ledger = [];
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
      final data = await _repo.getCRMStatement(widget.customerId);
      setState(() => _ledger = data);
    } catch (_) {}
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('${widget.customerName} - CRM')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _ledger.isEmpty
              ? Center(child: Text('No CRM history found', style: AppTheme.caption))
              : ListView.separated(
                  padding: EdgeInsets.all(16.w),
                  itemCount: _ledger.length,
                  separatorBuilder: (_, __) => SizedBox(height: 8.h),
                  itemBuilder: (_, i) {
                    final entry = _ledger[i];
                    final date = DateTime.parse(entry['created_at'] as String);
                    final points = (entry['points'] as num?)?.toDouble() ?? 0;
                    final isEarned = entry['points_type'] == 'earned';
                    final color = isEarned ? AppTheme.accent : AppTheme.danger;

                    return Container(
                      padding: EdgeInsets.all(12.w),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10.r),
                        border: Border.all(color: color.withOpacity(0.2)),
                      ),
                      child: Row(children: [
                        Text(isEarned ? '⭐' : '🔄', style: TextStyle(fontSize: 20.sp)),
                        SizedBox(width: 10.w),
                        Expanded(child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(entry['points_type']?.toString().toUpperCase() ?? '',
                                style: AppTheme.body.copyWith(
                                    fontWeight: FontWeight.w600, color: color)),
                            if (entry['note'] != null)
                              Text(entry['note'].toString(), style: AppTheme.caption),
                            Text(DateFormat('dd MMM yyyy  h:mm a').format(date),
                                style: AppTheme.caption),
                          ],
                        )),
                        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                          Text('${isEarned ? '+' : '-'}${points.toStringAsFixed(1)} pts',
                              style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w700,
                                  color: color, fontFamily: 'Poppins')),
                          Text('Bal: ${(entry['balance'] as num?)?.toStringAsFixed(1) ?? '0'}',
                              style: AppTheme.caption),
                        ]),
                      ]),
                    );
                  }),
    );
  }
}
