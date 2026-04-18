import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../../core/theme/app_theme.dart';
import 'crm_points_report_page.dart';
import 'customer_balance_report_page.dart';
import 'supplier_balance_report_page.dart';

class LedgerReportsMenu extends StatelessWidget {
  const LedgerReportsMenu({super.key});

  @override
  Widget build(BuildContext context) {
    final items = [
      ('🏭', 'Supplier Balance & Statement', 'Supplier outstanding & purchase history',
          const SupplierBalanceReportPage()),
      ('👤', 'Customer Balance & Statement', 'Customer outstanding & bill history',
          const CustomerBalanceReportPage()),
      ('⭐', 'CRM Points', 'Customer points balance & ledger',
          const CrmPointsReportPage()),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Ledger Reports')),
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
              width: 44.w, height: 44.h,
              decoration: BoxDecoration(
                  color: AppTheme.warning.withOpacity(0.1),
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
