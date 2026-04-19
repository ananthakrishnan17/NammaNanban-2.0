import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../../core/database/database_helper.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/utils/currency_formatter.dart';
import '../../../../../core/utils/stock_display_helper.dart';
import '../../../data/repositories/report_repository.dart';

class WholesaleRetailReportPage extends StatefulWidget {
  const WholesaleRetailReportPage({super.key});

  @override
  State<WholesaleRetailReportPage> createState() =>
      _WholesaleRetailReportPageState();
}

class _WholesaleRetailReportPageState
    extends State<WholesaleRetailReportPage> {
  late final ReportRepository _repo;
  List<Map<String, dynamic>> _data = [];
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _repo = ReportRepository(DatabaseHelper.instance);
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final data = await _repo.getWholesaleRetailStockReport();
      setState(() => _data = data);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Wholesale / Retail Stock'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _load,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('⚠️', style: TextStyle(fontSize: 48.sp)),
                      SizedBox(height: 12.h),
                      Text(_error!, style: AppTheme.caption),
                      SizedBox(height: 16.h),
                      ElevatedButton(
                          onPressed: _load, child: const Text('Retry')),
                    ],
                  ),
                )
              : _data.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('📦', style: TextStyle(fontSize: 56.sp)),
                          SizedBox(height: 16.h),
                          Text('No wholesale products found',
                              style: AppTheme.heading2),
                          SizedBox(height: 8.h),
                          Text(
                            'Set "1 bag = X kg" on a product to see it here',
                            style: AppTheme.caption,
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.separated(
                        padding: EdgeInsets.all(14.w),
                        itemCount: _data.length,
                        separatorBuilder: (_, __) => SizedBox(height: 12.h),
                        itemBuilder: (_, i) => _buildCard(_data[i]),
                      ),
                    ),
    );
  }

  Widget _buildCard(Map<String, dynamic> row) {
    final name = row['name'] as String;
    final stockQty = (row['stock_quantity'] as num).toDouble();
    final wholesaleUnit = row['wholesale_unit'] as String? ?? 'bag';
    final retailUnit = row['retail_unit'] as String? ?? 'kg';
    final conversionQty =
        (row['wholesale_to_retail_qty'] as num?)?.toDouble() ?? 1.0;
    final wholesalePrice =
        (row['wholesale_price'] as num?)?.toDouble() ?? 0.0;
    final retailPrice = (row['retail_price'] as num?)?.toDouble() ?? 0.0;
    final totalWholesaleSold =
        (row['total_wholesale_sold'] as num?)?.toDouble() ?? 0.0;
    final totalRetailSold =
        (row['total_retail_sold'] as num?)?.toDouble() ?? 0.0;
    final totalPurchasedBags =
        (row['total_purchased_bags'] as num?)?.toDouble() ?? 0.0;

    final stockDisplay = StockDisplayHelper.formatMixedStock(
      stockRetailQty: stockQty,
      wholesaleToRetailQty: conversionQty,
      wholesaleUnit: wholesaleUnit,
      retailUnit: retailUnit,
    );

    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: AppTheme.divider),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Text(name,
                style: AppTheme.heading3.copyWith(fontWeight: FontWeight.w700)),
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
            decoration: BoxDecoration(
              color: AppTheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8.r),
            ),
            child: Text(
              '1 $wholesaleUnit = ${conversionQty.toStringAsFixed(1)} $retailUnit',
              style: TextStyle(
                  fontSize: 10.sp,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primary,
                  fontFamily: 'Poppins'),
            ),
          ),
        ]),
        SizedBox(height: 10.h),
        // Stock remaining
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(10.w),
          decoration: BoxDecoration(
            color: AppTheme.accent.withOpacity(0.08),
            borderRadius: BorderRadius.circular(10.r),
          ),
          child: Row(children: [
            Icon(Icons.inventory_2_outlined,
                color: AppTheme.accent, size: 18.sp),
            SizedBox(width: 8.w),
            Text('Remaining Stock: ',
                style: AppTheme.caption.copyWith(fontWeight: FontWeight.w600)),
            Text(stockDisplay,
                style: TextStyle(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.accent,
                    fontFamily: 'Poppins')),
          ]),
        ),
        SizedBox(height: 10.h),
        // Stats grid
        Row(children: [
          _statChip(
              '📥', 'Purchased',
              '${totalPurchasedBags.toStringAsFixed(1)} ${wholesaleUnit}s',
              AppTheme.primary),
          SizedBox(width: 8.w),
          _statChip(
              '📦', 'Wholesale Sold',
              '${totalWholesaleSold.toStringAsFixed(1)} ${wholesaleUnit}s',
              AppTheme.warning),
          SizedBox(width: 8.w),
          _statChip(
              '🛒', 'Retail Sold',
              '${totalRetailSold.toStringAsFixed(1)} $retailUnit',
              Colors.teal),
        ]),
        SizedBox(height: 10.h),
        Row(children: [
          if (wholesalePrice > 0)
            _priceChip(
                '📦 ${CurrencyFormatter.format(wholesalePrice)}/$wholesaleUnit'),
          if (wholesalePrice > 0) SizedBox(width: 8.w),
          if (retailPrice > 0)
            _priceChip(
                '🛒 ${CurrencyFormatter.format(retailPrice)}/$retailUnit'),
        ]),
      ]),
    );
  }

  Widget _statChip(String icon, String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 8.h, horizontal: 6.w),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(8.r),
        ),
        child: Column(children: [
          Text(icon, style: TextStyle(fontSize: 16.sp)),
          SizedBox(height: 2.h),
          Text(label,
              style: AppTheme.caption.copyWith(fontSize: 9.sp),
              textAlign: TextAlign.center),
          SizedBox(height: 2.h),
          Text(value,
              style: TextStyle(
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w700,
                  color: color,
                  fontFamily: 'Poppins'),
              textAlign: TextAlign.center),
        ]),
      ),
    );
  }

  Widget _priceChip(String label) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 11.sp,
              fontWeight: FontWeight.w600,
              fontFamily: 'Poppins',
              color: AppTheme.textPrimary)),
    );
  }
}
