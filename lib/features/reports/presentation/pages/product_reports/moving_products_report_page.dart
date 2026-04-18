import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../../core/database/database_helper.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/utils/currency_formatter.dart';
import '../../../data/repositories/report_repository.dart';

class MovingProductsReportPage extends StatefulWidget {
  const MovingProductsReportPage({super.key});

  @override
  State<MovingProductsReportPage> createState() =>
      _MovingProductsReportPageState();
}

class _MovingProductsReportPageState extends State<MovingProductsReportPage>
    with SingleTickerProviderStateMixin {
  late final ReportRepository _repo;
  late TabController _tabs;
  int _days = 30;
  List<Map<String, dynamic>> _all = [];
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _repo = ReportRepository(DatabaseHelper.instance);
    _tabs = TabController(length: 4, vsync: this);
    _tabs.addListener(() => setState(() {}));
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
      final data = await _repo.getProductMovementReport(_days);
      setState(() => _all = data);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> get _filtered {
    switch (_tabs.index) {
      case 1: return _all.where((p) => p['movement_type'] == 'fast').toList();
      case 2: return _all.where((p) => p['movement_type'] == 'slow').toList();
      case 3: return _all.where((p) => p['movement_type'] == 'non-moving').toList();
      default: return _all;
    }
  }

  Color _movementColor(String type) {
    switch (type) {
      case 'fast': return AppTheme.accent;
      case 'slow': return AppTheme.warning;
      default: return AppTheme.danger;
    }
  }

  @override
  Widget build(BuildContext context) {
    final fast = _all.where((p) => p['movement_type'] == 'fast').length;
    final slow = _all.where((p) => p['movement_type'] == 'slow').length;
    final nonMoving = _all.where((p) => p['movement_type'] == 'non-moving').length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Product Movement'),
        bottom: TabBar(
          controller: _tabs,
          labelColor: AppTheme.primary,
          unselectedLabelColor: AppTheme.textSecondary,
          indicatorColor: AppTheme.primary,
          tabs: const [
            Tab(text: 'All'),
            Tab(text: 'Fast'),
            Tab(text: 'Slow'),
            Tab(text: 'Non-Moving'),
          ],
        ),
      ),
      body: Column(children: [
        Container(
          color: Colors.white,
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
          child: Row(children: [
            Text('Period:', style: AppTheme.body),
            SizedBox(width: 8.w),
            ...[7, 30, 90].map((d) => Padding(
              padding: EdgeInsets.only(right: 8.w),
              child: GestureDetector(
                onTap: () { setState(() => _days = d); _load(); },
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 6.h),
                  decoration: BoxDecoration(
                    color: _days == d ? AppTheme.primary : Colors.white,
                    borderRadius: BorderRadius.circular(20.r),
                    border: Border.all(color: AppTheme.primary),
                  ),
                  child: Text('${d}d',
                      style: TextStyle(
                          fontSize: 12.sp,
                          fontFamily: 'Poppins',
                          color: _days == d ? Colors.white : AppTheme.primary,
                          fontWeight: FontWeight.w500)),
                ),
              ),
            )),
          ]),
        ),
        if (_all.isNotEmpty)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
            child: Row(children: [
              _statChip('🟢 Fast', fast, AppTheme.accent),
              SizedBox(width: 8.w),
              _statChip('🟡 Slow', slow, AppTheme.warning),
              SizedBox(width: 8.w),
              _statChip('🔴 Non-Moving', nonMoving, AppTheme.danger),
            ]),
          ),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? Center(child: Text('Error: $_error'))
                  : _filtered.isEmpty
                      ? Center(child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('📦', style: TextStyle(fontSize: 48.sp)),
                            SizedBox(height: 12.h),
                            Text('No products found', style: AppTheme.heading3),
                          ]))
                      : ListView.separated(
                          padding: EdgeInsets.all(16.w),
                          itemCount: _filtered.length,
                          separatorBuilder: (_, __) => SizedBox(height: 8.h),
                          itemBuilder: (_, i) {
                            final p = _filtered[i];
                            final type = p['movement_type'] as String;
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
                                    Text(p['product_name'].toString(),
                                        style: AppTheme.body.copyWith(fontWeight: FontWeight.w600)),
                                    SizedBox(height: 2.h),
                                    Text('Qty Sold: ${(p['total_qty_sold'] as num).toStringAsFixed(1)}',
                                        style: AppTheme.caption),
                                  ],
                                )),
                                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                                  Container(
                                    padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                                    decoration: BoxDecoration(
                                      color: _movementColor(type).withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(20.r),
                                    ),
                                    child: Text(type.toUpperCase(),
                                        style: TextStyle(
                                            fontSize: 10.sp,
                                            color: _movementColor(type),
                                            fontFamily: 'Poppins',
                                            fontWeight: FontWeight.w600)),
                                  ),
                                  SizedBox(height: 4.h),
                                  Text(CurrencyFormatter.format((p['total_revenue'] as num).toDouble()),
                                      style: AppTheme.body.copyWith(
                                          fontWeight: FontWeight.w700, color: AppTheme.primary)),
                                ]),
                              ]),
                            );
                          }),
        ),
      ]),
    );
  }

  Widget _statChip(String label, int count, Color color) => Container(
    padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
    decoration: BoxDecoration(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(20.r),
    ),
    child: Text('$label: $count',
        style: TextStyle(fontSize: 12.sp, color: color, fontFamily: 'Poppins', fontWeight: FontWeight.w600)),
  );
}
