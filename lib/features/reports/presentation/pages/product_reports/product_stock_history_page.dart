import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';

import '../../../../../core/database/database_helper.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/utils/currency_formatter.dart';
import '../../../data/repositories/report_repository.dart';
import '../../widgets/date_range_filter.dart';

class ProductStockHistoryPage extends StatefulWidget {
  const ProductStockHistoryPage({super.key});

  @override
  State<ProductStockHistoryPage> createState() =>
      _ProductStockHistoryPageState();
}

class _ProductStockHistoryPageState extends State<ProductStockHistoryPage> {
  late final ReportRepository _repo;
  late DateTime _from, _to;
  List<Map<String, dynamic>> _products = [];
  List<Map<String, dynamic>> _history = [];
  Map<String, dynamic>? _selectedProduct;
  bool _isLoading = false;
  String? _error;
  double _currentStock = 0;

  @override
  void initState() {
    super.initState();
    _repo = ReportRepository(DatabaseHelper.instance);
    final now = DateTime.now();
    _from = DateTime(now.year, now.month, 1);
    _to = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    try {
      final db = await DatabaseHelper.instance.database;
      final data = await db.rawQuery(
          "SELECT id, name, stock_quantity FROM products WHERE is_active=1 ORDER BY name ASC");
      setState(() => _products = data);
    } catch (_) {}
  }

  Future<void> _loadHistory() async {
    if (_selectedProduct == null) return;
    setState(() { _isLoading = true; _error = null; });
    try {
      final productId = _selectedProduct!['id'] as int;
      final data = await _repo.getProductStockHistory(productId, from: _from, to: _to);
      setState(() {
        _history = data;
        _currentStock = (_selectedProduct!['stock_quantity'] as num?)?.toDouble() ?? 0;
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Color _typeColor(String type) {
    if (type == 'purchase' || type == 'adjustment_in') return AppTheme.accent;
    if (type == 'sale') return AppTheme.danger;
    return AppTheme.warning;
  }

  String _typeEmoji(String type) {
    if (type == 'purchase') return '📥';
    if (type == 'sale') return '📤';
    return '⚙️';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Product Stock History')),
      body: Column(children: [
        Container(
          color: Colors.white,
          padding: EdgeInsets.all(16.w),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Select Product', style: AppTheme.body.copyWith(fontWeight: FontWeight.w600)),
            SizedBox(height: 8.h),
            DropdownButtonFormField<Map<String, dynamic>>(
              value: _selectedProduct,
              hint: Text('Choose a product', style: AppTheme.caption),
              decoration: InputDecoration(
                contentPadding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10.r),
                    borderSide: BorderSide(color: AppTheme.divider)),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10.r),
                    borderSide: BorderSide(color: AppTheme.divider)),
              ),
              items: _products.map((p) => DropdownMenuItem(
                value: p,
                child: Text(p['name'].toString(),
                    style: TextStyle(fontSize: 13.sp, fontFamily: 'Poppins')),
              )).toList(),
              onChanged: (p) { setState(() => _selectedProduct = p); _loadHistory(); },
            ),
            if (_selectedProduct != null) ...[
              SizedBox(height: 12.h),
              DateRangeFilter(
                  from: _from, to: _to,
                  onChanged: (f, t) { setState(() { _from = f; _to = t; }); _loadHistory(); }),
              SizedBox(height: 8.h),
              Container(
                padding: EdgeInsets.all(10.w),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Row(children: [
                  Text('Current Stock: ', style: AppTheme.body),
                  Text(_currentStock.toStringAsFixed(1),
                      style: AppTheme.body.copyWith(
                          fontWeight: FontWeight.w700, color: AppTheme.primary)),
                ]),
              ),
            ],
          ]),
        ),
        Expanded(
          child: _selectedProduct == null
              ? Center(child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('📈', style: TextStyle(fontSize: 48.sp)),
                    SizedBox(height: 12.h),
                    Text('Select a product to view history', style: AppTheme.heading3),
                  ]))
              : _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(child: Text('Error: $_error'))
                      : _history.isEmpty
                          ? Center(child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text('📊', style: TextStyle(fontSize: 48.sp)),
                                SizedBox(height: 12.h),
                                Text('No history in this period', style: AppTheme.heading3),
                              ]))
                          : ListView.separated(
                              padding: EdgeInsets.all(16.w),
                              itemCount: _history.length,
                              separatorBuilder: (_, __) => SizedBox(height: 8.h),
                              itemBuilder: (_, i) {
                                final h = _history[i];
                                final type = h['type'] as String;
                                final qty = (h['qty_change'] as num).toDouble();
                                final date = DateTime.parse(h['created_at'] as String);
                                final color = _typeColor(type);
                                return Container(
                                  padding: EdgeInsets.all(12.w),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(10.r),
                                    border: Border.all(color: color.withOpacity(0.3)),
                                  ),
                                  child: Row(children: [
                                    Text(_typeEmoji(type), style: TextStyle(fontSize: 20.sp)),
                                    SizedBox(width: 10.w),
                                    Expanded(child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(h['reference']?.toString() ?? type,
                                            style: AppTheme.body.copyWith(fontWeight: FontWeight.w600)),
                                        Text(DateFormat('dd MMM yyyy  h:mm a').format(date),
                                            style: AppTheme.caption),
                                      ],
                                    )),
                                    Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                                      Text('${qty >= 0 ? '+' : ''}${qty.toStringAsFixed(1)}',
                                          style: TextStyle(
                                              fontSize: 14.sp,
                                              fontWeight: FontWeight.w700,
                                              color: color,
                                              fontFamily: 'Poppins')),
                                      if ((h['amount'] as num?)?.toDouble() != 0 && h['amount'] != null)
                                        Text(CurrencyFormatter.format((h['amount'] as num).toDouble()),
                                            style: AppTheme.caption),
                                    ]),
                                  ]),
                                );
                              }),
        ),
      ]),
    );
  }
}
