import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../../core/database/database_helper.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/utils/currency_formatter.dart';
import '../../../../../core/utils/stock_display_helper.dart';
import '../../../data/repositories/report_repository.dart';
import '../../../utils/pdf_export_helper.dart';
import '../../widgets/date_range_filter.dart';

class ProductStockSalesReportPage extends StatefulWidget {
  const ProductStockSalesReportPage({super.key});

  @override
  State<ProductStockSalesReportPage> createState() =>
      _ProductStockSalesReportPageState();
}

class _ProductStockSalesReportPageState
    extends State<ProductStockSalesReportPage> {
  late final ReportRepository _repo;

  DateTime _from = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _to = DateTime.now();

  int? _selectedProductId;
  int? _selectedCategoryId;

  List<Map<String, dynamic>> _categories = [];
  List<Map<String, dynamic>> _products = [];
  List<Map<String, dynamic>> _rows = [];

  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _repo = ReportRepository(DatabaseHelper.instance);
    _loadDropdowns();
    _load();
  }

  Future<void> _loadDropdowns() async {
    try {
      final categories = await _repo.getAllCategories();
      final products = await _repo.getAllProductsForFilter();
      if (mounted) {
        setState(() {
          _categories = categories;
          _products = products;
        });
      }
    } catch (_) {
      // Dropdown loading failure is non-fatal; filters will be empty
    }
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final data = await _repo.getProductStockSalesReport(
        from: _from,
        to: _to,
        productId: _selectedProductId,
        categoryId: _selectedCategoryId,
      );
      setState(() => _rows = data);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _clearFilters() {
    setState(() {
      final now = DateTime.now();
      _from = DateTime(now.year, now.month, 1);
      _to = now;
      _selectedProductId = null;
      _selectedCategoryId = null;
    });
    _load();
  }

  Future<void> _export() async {
    final totalPurchaseValue = _rows.fold(
        0.0, (s, d) => s + (d['total_purchase_value'] as num).toDouble());
    final totalSalesValue = _rows.fold(
        0.0,
        (s, d) =>
            s +
            (d['total_wholesale_sold_value'] as num).toDouble() +
            (d['total_retail_sold_value'] as num).toDouble());

    await PdfExportHelper.exportAndShare(
      title: 'Product Stock & Sales Report',
      headers: [
        'Product',
        'Category',
        'Purchased Qty',
        'Purchase Value',
        'WS Sold',
        'Retail Sold',
        'Sales Value',
        'Balance'
      ],
      rows: _rows.map((d) {
        final wsToRetail = (d['wholesale_to_retail_qty'] as num).toDouble();
        final currentStock = (d['current_stock'] as num).toDouble();
        final balance = StockDisplayHelper.formatMixedStock(
          stockRetailQty: currentStock,
          wholesaleToRetailQty: wsToRetail,
          wholesaleUnit: d['wholesale_unit']?.toString() ?? 'bag',
          retailUnit: d['retail_unit']?.toString() ?? 'kg',
        );
        final salesVal =
            (d['total_wholesale_sold_value'] as num).toDouble() +
                (d['total_retail_sold_value'] as num).toDouble();
        return [
          d['name']?.toString() ?? '',
          d['category_name']?.toString() ?? '',
          (d['total_purchased_qty'] as num).toStringAsFixed(2),
          CurrencyFormatter.format(
              (d['total_purchase_value'] as num).toDouble()),
          (d['total_wholesale_sold_qty'] as num).toStringAsFixed(2),
          (d['total_retail_sold_qty'] as num).toStringAsFixed(2),
          CurrencyFormatter.format(salesVal),
          balance,
        ];
      }).toList(),
      summary: {
        'Total Purchase Value': CurrencyFormatter.format(totalPurchaseValue),
        'Total Sales Value': CurrencyFormatter.format(totalSalesValue),
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalPurchaseValue = _rows.fold(
        0.0, (s, d) => s + (d['total_purchase_value'] as num).toDouble());
    final totalSalesValue = _rows.fold(
        0.0,
        (s, d) =>
            s +
            (d['total_wholesale_sold_value'] as num).toDouble() +
            (d['total_retail_sold_value'] as num).toDouble());

    return Scaffold(
      appBar: AppBar(
        title: const Text('Stock & Sales Report'),
        actions: [
          if (_rows.isNotEmpty)
            IconButton(
                icon: const Icon(Icons.picture_as_pdf), onPressed: _export),
        ],
      ),
      body: Column(
        children: [
          // ── Filter Section ─────────────────────────────────────────────────
          Container(
            color: Colors.white,
            padding: EdgeInsets.all(16.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DateRangeFilter(
                  from: _from,
                  to: _to,
                  onChanged: (f, t) => setState(() {
                    _from = f;
                    _to = t;
                  }),
                ),
                SizedBox(height: 12.h),
                Row(
                  children: [
                    Expanded(
                      child: _DropdownField<int?>(
                        label: 'Category',
                        value: _selectedCategoryId,
                        items: [
                          DropdownMenuItem<int?>(
                              value: null,
                              child: const Text('All Categories')),
                          ..._categories.map((c) => DropdownMenuItem<int?>(
                                value: c['id'] as int,
                                child: Text(c['name']?.toString() ?? ''),
                              )),
                        ],
                        onChanged: (v) => setState(() {
                          _selectedCategoryId = v;
                        }),
                      ),
                    ),
                    SizedBox(width: 8.w),
                    Expanded(
                      child: _DropdownField<int?>(
                        label: 'Product',
                        value: _selectedProductId,
                        items: [
                          DropdownMenuItem<int?>(
                              value: null,
                              child: const Text('All Products')),
                          ..._products.map((p) => DropdownMenuItem<int?>(
                                value: p['id'] as int,
                                child: Text(p['name']?.toString() ?? ''),
                              )),
                        ],
                        onChanged: (v) => setState(() {
                          _selectedProductId = v;
                        }),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12.h),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _load,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10.r)),
                          padding: EdgeInsets.symmetric(vertical: 10.h),
                        ),
                        child: Text('Apply',
                            style: TextStyle(
                                fontSize: 13.sp, fontFamily: 'Poppins')),
                      ),
                    ),
                    SizedBox(width: 8.w),
                    OutlinedButton(
                      onPressed: _clearFilters,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.textSecondary,
                        side: BorderSide(color: AppTheme.divider),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10.r)),
                        padding: EdgeInsets.symmetric(
                            vertical: 10.h, horizontal: 16.w),
                      ),
                      child: Text('Clear',
                          style: TextStyle(
                              fontSize: 13.sp, fontFamily: 'Poppins')),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // ── Content ────────────────────────────────────────────────────────
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(child: Text('Error: $_error'))
                    : _rows.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text('📊',
                                    style: TextStyle(fontSize: 48.sp)),
                                SizedBox(height: 12.h),
                                Text('No products found',
                                    style: AppTheme.heading3),
                              ],
                            ),
                          )
                        : SingleChildScrollView(
                            child: Column(
                              children: [
                                // Summary cards
                                Padding(
                                  padding: EdgeInsets.all(16.w),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: _sCard(
                                          'Total Purchase Value',
                                          CurrencyFormatter.format(
                                              totalPurchaseValue),
                                          AppTheme.primary,
                                          '💰',
                                        ),
                                      ),
                                      SizedBox(width: 10.w),
                                      Expanded(
                                        child: _sCard(
                                          'Total Sales Value',
                                          CurrencyFormatter.format(
                                              totalSalesValue),
                                          AppTheme.accent,
                                          '💵',
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                // Product rows
                                ..._rows.map(
                                    (row) => _ProductStockCard(data: row)),
                                SizedBox(height: 16.h),
                              ],
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  Widget _sCard(String label, String value, Color color, String emoji) =>
      Container(
        padding: EdgeInsets.all(12.w),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: AppTheme.divider),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text(emoji, style: TextStyle(fontSize: 16.sp)),
            const Spacer(),
            Container(
                width: 8.w,
                height: 8.h,
                decoration:
                    BoxDecoration(color: color, shape: BoxShape.circle)),
          ]),
          SizedBox(height: 4.h),
          Text(label, style: AppTheme.caption),
          Text(value,
              style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w700,
                  color: color,
                  fontFamily: 'Poppins')),
        ]),
      );
}

class _ProductStockCard extends StatefulWidget {
  final Map<String, dynamic> data;
  const _ProductStockCard({required this.data});

  @override
  State<_ProductStockCard> createState() => _ProductStockCardState();
}

class _ProductStockCardState extends State<_ProductStockCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final row = widget.data;
    final name = row['name']?.toString() ?? 'Unknown';
    final categoryName = row['category_name']?.toString() ?? 'Uncategorized';
    final currentStock = (row['current_stock'] as num).toDouble();
    final wsToRetail = (row['wholesale_to_retail_qty'] as num).toDouble();
    final wholesaleUnit = row['wholesale_unit']?.toString() ?? 'bag';
    final retailUnit = row['retail_unit']?.toString() ?? 'kg';
    final purchasedQty = (row['total_purchased_qty'] as num).toDouble();
    final purchaseValue = (row['total_purchase_value'] as num).toDouble();
    final wholesaleSoldQty =
        (row['total_wholesale_sold_qty'] as num).toDouble();
    final wholesaleSoldValue =
        (row['total_wholesale_sold_value'] as num).toDouble();
    final retailSoldQty = (row['total_retail_sold_qty'] as num).toDouble();
    final retailSoldValue = (row['total_retail_sold_value'] as num).toDouble();
    final totalSalesValue = wholesaleSoldValue + retailSoldValue;

    final balanceDisplay = StockDisplayHelper.formatMixedStock(
      stockRetailQty: currentStock,
      wholesaleToRetailQty: wsToRetail,
      wholesaleUnit: wholesaleUnit,
      retailUnit: retailUnit,
    );

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(
        children: [
          // ── Header (always visible) ─────────────────────────────────────
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(12.r),
            child: Padding(
              padding: EdgeInsets.all(12.w),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name,
                            style: AppTheme.heading3,
                            overflow: TextOverflow.ellipsis),
                        SizedBox(height: 2.h),
                        Text(categoryName, style: AppTheme.caption),
                        SizedBox(height: 4.h),
                        Row(children: [
                          Text('Balance: ',
                              style: AppTheme.caption
                                  .copyWith(fontWeight: FontWeight.w600)),
                          Text(balanceDisplay,
                              style: AppTheme.caption.copyWith(
                                  color: AppTheme.primary,
                                  fontWeight: FontWeight.w700)),
                        ]),
                      ],
                    ),
                  ),
                  Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    color: AppTheme.textSecondary,
                  ),
                ],
              ),
            ),
          ),
          // ── Expanded Detail ─────────────────────────────────────────────
          if (_expanded) ...[
            Divider(height: 1, color: AppTheme.divider),
            Padding(
              padding: EdgeInsets.all(12.w),
              child: Column(
                children: [
                  _detailRow('📥', 'Purchased',
                      '${_fmtQty(purchasedQty)} $wholesaleUnit'),
                  SizedBox(height: 4.h),
                  if (wsToRetail > 1.0) ...[
                    _detailRow('📦', 'Wholesale Sold',
                        '${_fmtQty(wholesaleSoldQty)} $wholesaleUnit'),
                    SizedBox(height: 4.h),
                    _detailRow('🛒', 'Retail Sold',
                        '${_fmtQty(retailSoldQty)} $retailUnit'),
                  ] else ...[
                    _detailRow('🛒', 'Sold',
                        '${_fmtQty(retailSoldQty)} $retailUnit'),
                  ],
                  SizedBox(height: 8.h),
                  Divider(height: 1, color: AppTheme.divider),
                  SizedBox(height: 8.h),
                  _detailRow('💰', 'Purchase Value',
                      CurrencyFormatter.format(purchaseValue)),
                  SizedBox(height: 4.h),
                  _detailRow('💵', 'Sales Value',
                      CurrencyFormatter.format(totalSalesValue)),
                  SizedBox(height: 8.h),
                  Divider(height: 1, color: AppTheme.divider),
                  SizedBox(height: 8.h),
                  _detailRow('📊', 'Balance', balanceDisplay,
                      valueColor: AppTheme.primary),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _fmtQty(double qty) {
    if (qty % 1 == 0) return qty.toInt().toString();
    return qty.toStringAsFixed(2);
  }

  Widget _detailRow(String emoji, String label, String value,
      {Color? valueColor}) {
    return Row(
      children: [
        Text(emoji, style: TextStyle(fontSize: 14.sp)),
        SizedBox(width: 6.w),
        Expanded(
          child: Text(label,
              style: AppTheme.body.copyWith(color: AppTheme.textSecondary)),
        ),
        Text(value,
            style: AppTheme.body.copyWith(
                fontWeight: FontWeight.w600,
                color: valueColor ?? AppTheme.textPrimary)),
      ],
    );
  }
}

class _DropdownField<T> extends StatelessWidget {
  final String label;
  final T value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;

  const _DropdownField({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T>(
      value: value,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: AppTheme.caption,
        contentPadding:
            EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10.r),
          borderSide: BorderSide(color: AppTheme.divider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10.r),
          borderSide: BorderSide(color: AppTheme.divider),
        ),
        filled: true,
        fillColor: Colors.white,
        isDense: true,
      ),
      items: items,
      onChanged: onChanged,
    );
  }
}
