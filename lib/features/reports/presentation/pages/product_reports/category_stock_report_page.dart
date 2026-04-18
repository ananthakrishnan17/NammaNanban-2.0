import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../../core/database/database_helper.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/utils/currency_formatter.dart';
import '../../../data/repositories/report_repository.dart';

class CategoryStockReportPage extends StatefulWidget {
  const CategoryStockReportPage({super.key});

  @override
  State<CategoryStockReportPage> createState() =>
      _CategoryStockReportPageState();
}

class _CategoryStockReportPageState extends State<CategoryStockReportPage> {
  late final ReportRepository _repo;
  List<Map<String, dynamic>> _categories = [];
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
      final data = await _repo.getCategoryStockReport();
      setState(() => _categories = data);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalProducts = _categories.fold(0, (s, c) => s + ((c['product_count'] as num?)?.toInt() ?? 0));
    final totalValue = _categories.fold(0.0, (s, c) => s + ((c['total_stock_value'] as num?)?.toDouble() ?? 0));

    return Scaffold(
      appBar: AppBar(title: const Text('Category Stock Report')),
      body: Column(children: [
        if (_categories.isNotEmpty)
          Container(
            color: Colors.white,
            padding: EdgeInsets.all(16.w),
            child: Row(children: [
              Expanded(child: _statCard('Categories', _categories.length.toString(), AppTheme.primary, '🗂️')),
              SizedBox(width: 10.w),
              Expanded(child: _statCard('Products', totalProducts.toString(), AppTheme.accent, '📦')),
              SizedBox(width: 10.w),
              Expanded(child: _statCard('Stock Value', CurrencyFormatter.format(totalValue), AppTheme.secondary, '💰')),
            ]),
          ),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? Center(child: Text('Error: $_error'))
                  : _categories.isEmpty
                      ? Center(child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('🗂️', style: TextStyle(fontSize: 48.sp)),
                            SizedBox(height: 12.h),
                            Text('No categories found', style: AppTheme.heading3),
                          ]))
                      : ListView.separated(
                          padding: EdgeInsets.all(16.w),
                          itemCount: _categories.length,
                          separatorBuilder: (_, __) => SizedBox(height: 10.h),
                          itemBuilder: (_, i) => _CategoryCard(
                              category: _categories[i], repo: _repo),
                        ),
        ),
      ]),
    );
  }

  Widget _statCard(String label, String value, Color color, String emoji) =>
      Container(
        padding: EdgeInsets.all(10.w),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10.r),
          border: Border.all(color: AppTheme.divider),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(emoji, style: TextStyle(fontSize: 16.sp)),
          SizedBox(height: 4.h),
          Text(label, style: AppTheme.caption),
          Text(value,
              style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w700, color: color, fontFamily: 'Poppins'),
              maxLines: 1, overflow: TextOverflow.ellipsis),
        ]),
      );
}

class _CategoryCard extends StatefulWidget {
  final Map<String, dynamic> category;
  final ReportRepository repo;
  const _CategoryCard({required this.category, required this.repo});

  @override
  State<_CategoryCard> createState() => _CategoryCardState();
}

class _CategoryCardState extends State<_CategoryCard> {
  bool _expanded = false;
  List<Map<String, dynamic>> _products = [];
  bool _loadingProducts = false;

  Future<void> _loadProducts() async {
    if (_products.isNotEmpty) { setState(() => _expanded = !_expanded); return; }
    setState(() { _loadingProducts = true; _expanded = true; });
    _products = await widget.repo.getProductsByCategory(widget.category['category_id'] as int);
    setState(() => _loadingProducts = false);
  }

  @override
  Widget build(BuildContext context) {
    final cat = widget.category;
    final icon = cat['icon']?.toString() ?? '📦';
    final productCount = (cat['product_count'] as num?)?.toInt() ?? 0;
    final stockQty = (cat['total_stock_qty'] as num?)?.toDouble() ?? 0;
    final stockVal = (cat['total_stock_value'] as num?)?.toDouble() ?? 0;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(children: [
        ListTile(
          contentPadding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 6.h),
          leading: Container(
            width: 44.w, height: 44.h,
            decoration: BoxDecoration(
                color: AppTheme.accent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10.r)),
            child: Center(child: Text(icon, style: TextStyle(fontSize: 20.sp))),
          ),
          title: Text(cat['category_name'].toString(),
              style: AppTheme.body.copyWith(fontWeight: FontWeight.w600)),
          subtitle: Text('$productCount products  •  Qty: ${stockQty.toStringAsFixed(1)}',
              style: AppTheme.caption),
          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
            Text(CurrencyFormatter.format(stockVal),
                style: AppTheme.body.copyWith(fontWeight: FontWeight.w700, color: AppTheme.primary)),
            Icon(_expanded ? Icons.expand_less : Icons.expand_more, color: AppTheme.textSecondary),
          ]),
          onTap: _loadProducts,
        ),
        if (_expanded) ...[
          Divider(height: 1, color: AppTheme.divider),
          if (_loadingProducts)
            Padding(padding: EdgeInsets.all(12.w), child: const CircularProgressIndicator())
          else if (_products.isEmpty)
            Padding(
              padding: EdgeInsets.all(12.w),
              child: Text('No products in this category', style: AppTheme.caption),
            )
          else
            ..._products.map((p) => Padding(
              padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 6.h),
              child: Row(children: [
                SizedBox(width: 8.w),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p['name'].toString(), style: AppTheme.body),
                    Text('Stock: ${(p['stock_quantity'] as num).toStringAsFixed(1)}',
                        style: AppTheme.caption),
                  ],
                )),
                Text(CurrencyFormatter.format((p['stock_value'] as num? ?? 0).toDouble()),
                    style: AppTheme.caption.copyWith(color: AppTheme.primary, fontWeight: FontWeight.w600)),
              ]),
            )),
          SizedBox(height: 8.h),
        ],
      ]),
    );
  }
}
