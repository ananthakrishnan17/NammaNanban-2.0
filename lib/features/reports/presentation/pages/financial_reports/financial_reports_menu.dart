import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../../core/theme/app_theme.dart';
import 'bank_book_page.dart';
import 'cashier_sales_report_page.dart';
import 'cash_book_page.dart';
import 'day_book_page.dart';
import 'daywise_profit_report_page.dart';
import 'profit_loss_report_page.dart';

class FinancialReportsMenu extends StatelessWidget {
  const FinancialReportsMenu({super.key});

  @override
  Widget build(BuildContext context) {
    final items = [
      ('📅', 'Day-wise Profit', 'Daily profit trend', const DaywiseProfitReportPage()),
      ('👨‍💼', 'Cashier-wise Sales', 'Sales by cashier', const CashierSalesReportPage()),
      ('💵', 'Cash Book', 'Cash receipts & payments', const CashBookPage()),
      ('🏦', 'Bank Book', 'Digital payments ledger', const BankBookPage()),
      ('📖', 'Day Book', 'All transactions by date', const DayBookPage()),
      ('📊', 'Profit & Loss', 'P&L statement', const ProfitLossReportPage()),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Financial Reports')),
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
                  color: AppTheme.secondary.withOpacity(0.1),
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
