import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../../core/theme/app_theme.dart';
import 'category_stock_report_page.dart';
import 'itemwise_report_page.dart';
import 'moving_products_report_page.dart';
import 'product_stock_history_page.dart';
import 'sales_by_item_report_page.dart';

class ProductReportsMenu extends StatelessWidget {
  const ProductReportsMenu({super.key});

  @override
  Widget build(BuildContext context) {
    final items = [
      ('🚀', 'Fast/Slow/Non-Moving', 'Product movement analysis',
          const MovingProductsReportPage()),
      ('🛒', 'Sales by Item', 'Item-wise sales summary',
          const SalesByItemReportPage()),
      ('📋', 'Item-wise Report', 'Detailed item transactions',
          const ItemwiseReportPage()),
      ('🗂️', 'Category Stock', 'Stock by category',
          const CategoryStockReportPage()),
      ('📈', 'Product Stock History', 'Stock movement history',
          const ProductStockHistoryPage()),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Product Reports')),
      body: ListView.separated(
        padding: EdgeInsets.all(16.w),
        itemCount: items.length,
        separatorBuilder: (_, __) => SizedBox(height: 10.h),
        itemBuilder: (ctx, i) {
          final (emoji, title, sub, page) = items[i];
          return ListTile(
            contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 6.h),
            tileColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12.r),
              side: BorderSide(color: AppTheme.divider),
            ),
            leading: Container(
              width: 44.w,
              height: 44.h,
              decoration: BoxDecoration(
                  color: AppTheme.accent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10.r)),
              child: Center(child: Text(emoji, style: TextStyle(fontSize: 20.sp))),
            ),
            title: Text(title, style: AppTheme.body.copyWith(fontWeight: FontWeight.w600)),
            subtitle: Text(sub, style: AppTheme.caption),
            trailing: Icon(Icons.chevron_right, color: AppTheme.textSecondary),
            onTap: () => Navigator.push(ctx, MaterialPageRoute(builder: (_) => page)),
          );
        },
      ),
    );
  }
}
