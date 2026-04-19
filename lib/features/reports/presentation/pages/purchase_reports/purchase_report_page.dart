import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';

import '../../../../../core/database/database_helper.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/utils/currency_formatter.dart';
import '../../../data/repositories/report_repository.dart';
import '../../../utils/pdf_export_helper.dart';
import '../../widgets/date_range_filter.dart';

class PurchaseReportPage extends StatefulWidget {
  const PurchaseReportPage({super.key});

  @override
  State<PurchaseReportPage> createState() => _PurchaseReportPageState();
}

class _PurchaseReportPageState extends State<PurchaseReportPage> {
  late final ReportRepository _repo;

  DateTime _from = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _to = DateTime.now();

  int? _selectedSupplierId;
  int? _selectedProductId;
  int? _selectedCategoryId;

  List<Map<String, dynamic>> _suppliers = [];
  List<Map<String, dynamic>> _categories = [];
  List<Map<String, dynamic>> _products = [];
  List<Map<String, dynamic>> _items = [];

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
      final suppliers = await _repo.getAllSuppliers();
      final categories = await _repo.getAllCategories();
      final products = await _repo.getAllProductsForFilter();
      if (mounted) {
        setState(() {
          _suppliers = suppliers;
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
      final data = await _repo.getPurchaseReport(
        from: _from,
        to: _to,
        supplierId: _selectedSupplierId,
        productId: _selectedProductId,
        categoryId: _selectedCategoryId,
      );
      setState(() => _items = data);
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
      _selectedSupplierId = null;
      _selectedProductId = null;
      _selectedCategoryId = null;
    });
    _load();
  }

  Future<void> _export() async {
    final totalAmount =
        _items.fold(0.0, (s, d) => s + (d['total_cost'] as num).toDouble());
    await PdfExportHelper.exportAndShare(
      title: 'Purchase Report',
      headers: [
        'Date',
        'Purchase #',
        'Product',
        'Supplier',
        'Qty',
        'Unit',
        'Rate',
        'Total'
      ],
      rows: _items
          .map((d) => [
                d['purchase_date'].toString(),
                d['purchase_number']?.toString() ?? '',
                d['product_name']?.toString() ?? '',
                d['supplier_name']?.toString() ?? '',
                (d['quantity'] as num).toStringAsFixed(2),
                d['unit']?.toString() ?? '',
                CurrencyFormatter.format((d['unit_cost'] as num).toDouble()),
                CurrencyFormatter.format((d['total_cost'] as num).toDouble()),
              ])
          .toList(),
      summary: {
        'Total Entries': _items.length.toString(),
        'Total Purchase Amount': CurrencyFormatter.format(totalAmount),
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalAmount =
        _items.fold(0.0, (s, d) => s + (d['total_cost'] as num).toDouble());

    return Scaffold(
      appBar: AppBar(
        title: const Text('Purchase Report'),
        actions: [
          if (_items.isNotEmpty)
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
                        label: 'Supplier',
                        value: _selectedSupplierId,
                        hint: 'All Suppliers',
                        items: [
                          DropdownMenuItem<int?>(
                              value: null, child: const Text('All Suppliers')),
                          ..._suppliers.map((s) => DropdownMenuItem<int?>(
                                value: s['id'] as int,
                                child: Text(s['name']?.toString() ?? ''),
                              )),
                        ],
                        onChanged: (v) => setState(() {
                          _selectedSupplierId = v;
                        }),
                      ),
                    ),
                    SizedBox(width: 8.w),
                    Expanded(
                      child: _DropdownField<int?>(
                        label: 'Category',
                        value: _selectedCategoryId,
                        hint: 'All Categories',
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
                  ],
                ),
                SizedBox(height: 8.h),
                _DropdownField<int?>(
                  label: 'Product',
                  value: _selectedProductId,
                  hint: 'All Products',
                  items: [
                    DropdownMenuItem<int?>(
                        value: null, child: const Text('All Products')),
                    ..._products.map((p) => DropdownMenuItem<int?>(
                          value: p['id'] as int,
                          child: Text(p['name']?.toString() ?? ''),
                        )),
                  ],
                  onChanged: (v) => setState(() {
                    _selectedProductId = v;
                  }),
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
                        child: Text('Apply Filters',
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
                          style:
                              TextStyle(fontSize: 13.sp, fontFamily: 'Poppins')),
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
                    : _items.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text('📥',
                                    style: TextStyle(fontSize: 48.sp)),
                                SizedBox(height: 12.h),
                                Text('No purchase entries found',
                                    style: AppTheme.heading3),
                              ],
                            ),
                          )
                        : SingleChildScrollView(
                            child: Column(
                              children: [
                                // Summary card
                                Padding(
                                  padding: EdgeInsets.all(16.w),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: _sCard(
                                          'Total Entries',
                                          _items.length.toString(),
                                          AppTheme.primary,
                                          '📋',
                                        ),
                                      ),
                                      SizedBox(width: 10.w),
                                      Expanded(
                                        child: _sCard(
                                          'Total Amount',
                                          CurrencyFormatter.format(totalAmount),
                                          AppTheme.accent,
                                          '💰',
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                // Purchase entries list
                                ..._items.map((d) => _PurchaseItemCard(data: d)),
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

class _PurchaseItemCard extends StatelessWidget {
  final Map<String, dynamic> data;
  const _PurchaseItemCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final productName = data['product_name']?.toString() ?? 'Unknown';
    final supplierName = data['supplier_name']?.toString() ?? 'N/A';
    final purchaseDate = data['purchase_date']?.toString() ?? '';
    final quantity = (data['quantity'] as num).toDouble();
    final unit = data['unit']?.toString() ?? '';
    final unitCost = (data['unit_cost'] as num).toDouble();
    final totalCost = (data['total_cost'] as num).toDouble();

    String formattedDate = purchaseDate;
    try {
      formattedDate =
          DateFormat('dd MMM yyyy').format(DateTime.parse(purchaseDate));
    } catch (_) {}

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 4.h),
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(productName,
                    style: AppTheme.heading3,
                    overflow: TextOverflow.ellipsis),
              ),
              Text(formattedDate, style: AppTheme.caption),
            ],
          ),
          SizedBox(height: 4.h),
          Row(
            children: [
              Icon(Icons.store, size: 12.sp, color: AppTheme.textSecondary),
              SizedBox(width: 4.w),
              Expanded(
                child: Text(supplierName,
                    style: AppTheme.caption, overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          SizedBox(height: 6.h),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Qty: ${quantity % 1 == 0 ? quantity.toInt() : quantity.toStringAsFixed(2)} $unit',
                  style: AppTheme.body,
                ),
              ),
              Text('Rate: ${CurrencyFormatter.format(unitCost)}',
                  style: AppTheme.body),
              SizedBox(width: 8.w),
              Text('Total: ${CurrencyFormatter.format(totalCost)}',
                  style: AppTheme.body
                      .copyWith(fontWeight: FontWeight.w700, color: AppTheme.accent)),
            ],
          ),
        ],
      ),
    );
  }
}

class _DropdownField<T> extends StatelessWidget {
  final String label;
  final T value;
  final String hint;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;

  const _DropdownField({
    required this.label,
    required this.value,
    required this.hint,
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
