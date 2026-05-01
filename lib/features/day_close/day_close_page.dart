import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/database/database_helper.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/currency_formatter.dart';
import '../reports/data/repositories/report_repository.dart';


/// Day Close (EOD) page.
///
/// The owner enters cash drawer opening balance and closing physical count.
/// The page fetches today's computed numbers and shows variance.
/// On submit, a [day_close] row is written to SQLite.
class DayClosePage extends StatefulWidget {
  const DayClosePage({super.key});

  @override
  State<DayClosePage> createState() => _DayClosePageState();
}

class _DayClosePageState extends State<DayClosePage> {
  late final ReportRepository _repo;
  Map<String, dynamic>? _summary;
  bool _isLoading = false;
  bool _isClosed = false;
  bool _isSaving = false;
  String? _error;

  final _openingCtrl = TextEditingController();
  final _closingCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  final today = DateTime.now();

  @override
  void initState() {
    super.initState();
    _repo = ReportRepository(DatabaseHelper.instance);
    _load();
  }

  @override
  void dispose() {
    _openingCtrl.dispose();
    _closingCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final summary = await _repo.getDayCloseSummary(today);
      final closed = await _repo.isDayClosed(today);
      setState(() { _summary = summary; _isClosed = closed; });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _save() async {
    final opening = double.tryParse(_openingCtrl.text.trim()) ?? 0;
    final closing = double.tryParse(_closingCtrl.text.trim());
    if (closing == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Enter closing cash amount'), backgroundColor: Colors.red));
      return;
    }
    setState(() => _isSaving = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final closedBy = prefs.getString('active_user') ?? 'Admin';
      await _repo.saveCloseDay(
        date: today,
        cashOpening: opening,
        cashClosing: closing,
        summary: _summary!,
        notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
        closedBy: closedBy,
      );
      setState(() => _isClosed = true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('✅ Day closed successfully!'),
          backgroundColor: AppTheme.accent,
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.only(bottom: 24.h, left: 16.w, right: 16.w),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    } finally {
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(title: const Text('Day Close (EOD)')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text('Error: $_error', style: TextStyle(color: AppTheme.danger)))
              : _summary == null
                  ? const SizedBox()
                  : SingleChildScrollView(
                      padding: EdgeInsets.all(16.w),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Date chip
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                            decoration: BoxDecoration(
                              color: AppTheme.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20.r),
                            ),
                            child: Text(
                              DateFormat('EEEE, dd MMMM yyyy').format(today),
                              style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w600,
                                  color: AppTheme.primary, fontFamily: 'Poppins'),
                            ),
                          ),

                          if (_isClosed) ...[
                            SizedBox(height: 16.h),
                            Container(
                              padding: EdgeInsets.all(16.w),
                              decoration: BoxDecoration(
                                  color: AppTheme.accent.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12.r),
                                  border: Border.all(color: AppTheme.accent.withOpacity(0.4))),
                              child: Row(children: [
                                Icon(Icons.check_circle, color: AppTheme.accent, size: 22.sp),
                                SizedBox(width: 8.w),
                                Text('Day already closed', style: AppTheme.body.copyWith(
                                    color: AppTheme.accent, fontWeight: FontWeight.w700)),
                              ]),
                            ),
                          ],

                          SizedBox(height: 16.h),
                          _sectionTitle('📈 Today\'s Summary'),
                          SizedBox(height: 8.h),
                          _summaryGrid(_summary!),

                          SizedBox(height: 20.h),
                          _sectionTitle('💰 Cash Reconciliation'),
                          SizedBox(height: 10.h),

                          if (!_isClosed) ...[
                            _amountField(_openingCtrl, 'Opening Cash Balance'),
                            SizedBox(height: 10.h),
                            _amountField(_closingCtrl, 'Closing Cash (Physical Count)'),
                            SizedBox(height: 10.h),
                            // Live variance preview
                            ValueListenableBuilder(
                              valueListenable: _closingCtrl,
                              builder: (_, __, ___) {
                                final opening = double.tryParse(_openingCtrl.text) ?? 0;
                                final closing = double.tryParse(_closingCtrl.text) ?? 0;
                                final cashSales = (_summary!['cash_sales'] as num).toDouble();
                                final expenses = (_summary!['total_expenses'] as num).toDouble();
                                final expected = opening + cashSales - expenses;
                                final variance = closing - expected;
                                if (_closingCtrl.text.isEmpty) return const SizedBox();
                                return Container(
                                  padding: EdgeInsets.all(12.w),
                                  decoration: BoxDecoration(
                                    color: variance.abs() < 1 ? AppTheme.accent.withOpacity(0.08)
                                        : AppTheme.warning.withOpacity(0.08),
                                    borderRadius: BorderRadius.circular(10.r),
                                    border: Border.all(
                                        color: variance.abs() < 1 ? AppTheme.accent : AppTheme.warning),
                                  ),
                                  child: Row(children: [
                                    Text('Expected: ${CurrencyFormatter.format(expected)}  ',
                                        style: AppTheme.caption),
                                    Text(
                                      'Variance: ${CurrencyFormatter.format(variance)}',
                                      style: TextStyle(
                                        fontSize: 12.sp, fontWeight: FontWeight.w700, fontFamily: 'Poppins',
                                        color: variance.abs() < 1 ? AppTheme.accent : AppTheme.warning,
                                      ),
                                    ),
                                  ]),
                                );
                              },
                            ),
                            SizedBox(height: 10.h),
                            TextField(
                              controller: _notesCtrl,
                              maxLines: 2,
                              decoration: InputDecoration(
                                labelText: 'Notes (optional)',
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10.r)),
                                contentPadding:
                                    EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
                              ),
                              style: AppTheme.body,
                            ),
                            SizedBox(height: 20.h),
                            SizedBox(
                              width: double.infinity,
                              height: 50.h,
                              child: ElevatedButton(
                                onPressed: _isSaving ? null : _save,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.primary,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14.r)),
                                ),
                                child: _isSaving
                                    ? const CircularProgressIndicator(color: Colors.white)
                                    : Text('Close Day',
                                        style: TextStyle(color: Colors.white, fontSize: 15.sp,
                                            fontWeight: FontWeight.w700, fontFamily: 'Poppins')),
                              ),
                            ),
                          ],
                          SizedBox(height: 20.h),
                        ],
                      ),
                    ),
    );
  }

  Widget _sectionTitle(String t) => Text(t,
      style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w700,
          color: AppTheme.textPrimary, fontFamily: 'Poppins'));

  Widget _amountField(TextEditingController ctrl, String label) => TextField(
    controller: ctrl,
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    decoration: InputDecoration(
      labelText: label,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10.r)),
      contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
      prefixText: '₹ ',
    ),
    style: AppTheme.body,
    onChanged: (_) => setState(() {}),
  );

  Widget _summaryGrid(Map<String, dynamic> s) {
    final items = [
      ('🧾', 'Total Sales', (s['total_sales'] as num).toDouble(), AppTheme.accent),
      ('📊', 'Bill Count', (s['bill_count'] as num).toDouble(), AppTheme.primary),
      ('💵', 'Cash Sales', (s['cash_sales'] as num).toDouble(), AppTheme.accent),
      ('📱', 'Digital Sales', (s['digital_sales'] as num).toDouble(), const Color(0xFF6B48FF)),
      ('💸', 'Expenses', (s['total_expenses'] as num).toDouble(), AppTheme.danger),
      ('↩️', 'Returns', (s['total_returns'] as num).toDouble(), AppTheme.warning),
    ];
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10.h,
      crossAxisSpacing: 10.w,
      childAspectRatio: 2.2,
      children: items.map((item) {
        final isCount = item.$1 == '📊';
        return Container(
          padding: EdgeInsets.all(12.w),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(color: (item.$4 as Color).withOpacity(0.3)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text(item.$1, style: TextStyle(fontSize: 14.sp)),
              SizedBox(width: 4.w),
              Expanded(child: Text(item.$2,
                  style: AppTheme.caption, overflow: TextOverflow.ellipsis)),
            ]),
            SizedBox(height: 2.h),
            Text(
              isCount ? '${item.$3.toInt()} bills' : CurrencyFormatter.format(item.$3),
              style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w700,
                  color: item.$4, fontFamily: 'Poppins'),
            ),
          ]),
        );
      }).toList(),
    );
  }
}
