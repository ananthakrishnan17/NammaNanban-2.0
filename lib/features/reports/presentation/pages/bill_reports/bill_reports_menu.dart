import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../../core/theme/app_theme.dart';
import '../../../../billing/presentation/pages/all_bills_page.dart';
import 'billwise_report_page.dart';
import 'cancelled_bill_report_page.dart';
import 'gst_report_page.dart';
import 'hourly_sales_report_page.dart';
import 'modified_bill_report_page.dart';
import 'sales_by_bill_report_page.dart';

class BillReportsMenu extends StatelessWidget {
  const BillReportsMenu({super.key});

  @override
  Widget build(BuildContext context) {
    final items = [
      ('🗂️', 'All Bills', 'Browse & view all bills',
          const AllBillsPage()),
      ('📝', 'Modified Bill Report', 'Bills with modifications',
          const ModifiedBillReportPage()),
      ('❌', 'Cancelled Bill Report', 'All cancelled bills',
          const CancelledBillReportPage()),
      ('📄', 'Sales by Bill', 'Bill-wise sales summary',
          const SalesByBillReportPage()),
      ('🧾', 'Bill-wise Report', 'Detailed per-bill breakdown',
          const BillwiseReportPage()),
      ('⏰', 'Hourly Sales Report', 'Sales distribution by hour',
          const HourlySalesReportPage()),
      ('🏛️', 'GST Report', 'GST summary with JSON export',
          const GstReportPage()),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Bill Reports')),
      body: ListView.separated(
        padding: EdgeInsets.all(16.w),
        itemCount: items.length,
        separatorBuilder: (_, __) => SizedBox(height: 10.h),
        itemBuilder: (ctx, i) {
          final (emoji, title, sub, page) = items[i];
          return ListTile(
            contentPadding:
                EdgeInsets.symmetric(horizontal: 16.w, vertical: 6.h),
            tileColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12.r),
              side: BorderSide(color: AppTheme.divider),
            ),
            leading: Container(
              width: 44.w,
              height: 44.h,
              decoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10.r)),
              child: Center(child: Text(emoji, style: TextStyle(fontSize: 20.sp))),
            ),
            title: Text(title, style: AppTheme.body.copyWith(fontWeight: FontWeight.w600)),
            subtitle: Text(sub, style: AppTheme.caption),
            trailing: Icon(Icons.chevron_right, color: AppTheme.textSecondary),
            onTap: () => Navigator.push(
                ctx, MaterialPageRoute(builder: (_) => page)),
          );
        },
      ),
    );
  }
}
