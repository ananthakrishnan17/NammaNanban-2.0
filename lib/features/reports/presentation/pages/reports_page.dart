import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/theme/app_theme.dart';
import 'bill_reports/bill_reports_menu.dart';
import 'financial_reports/financial_reports_menu.dart';
import 'ledger_reports/ledger_reports_menu.dart';
import 'product_reports/product_reports_menu.dart';
import 'purchase_reports/purchase_report_page.dart';
import 'stock_reports/product_stock_sales_report_page.dart';

class ReportsPage extends StatelessWidget {
  const ReportsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports'),
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Report Categories', style: AppTheme.heading2),
            SizedBox(height: 4.h),
            Text('Choose a category to view detailed reports',
                style: AppTheme.caption),
            SizedBox(height: 20.h),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 14.w,
              mainAxisSpacing: 14.h,
              childAspectRatio: 1.1,
              children: [
                _HubCard(
                  emoji: '📋',
                  title: 'Bill Reports',
                  subtitle: '5 Reports',
                  color: AppTheme.primary,
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const BillReportsMenu())),
                ),
                _HubCard(
                  emoji: '📦',
                  title: 'Product Reports',
                  subtitle: '5 Reports',
                  color: AppTheme.accent,
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const ProductReportsMenu())),
                ),
                _HubCard(
                  emoji: '💰',
                  title: 'Financial Reports',
                  subtitle: '6 Reports',
                  color: AppTheme.secondary,
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(
                          builder: (_) => const FinancialReportsMenu())),
                ),
                _HubCard(
                  emoji: '👥',
                  title: 'Ledger Reports',
                  subtitle: '3 Reports',
                  color: AppTheme.warning,
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const LedgerReportsMenu())),
                ),
                _HubCard(
                  emoji: '📥',
                  title: 'Purchase Report',
                  subtitle: 'Purchase entries',
                  color: AppTheme.secondary,
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const PurchaseReportPage())),
                ),
                _HubCard(
                  emoji: '📊',
                  title: 'Stock & Sales',
                  subtitle: 'Product reconciliation',
                  color: AppTheme.danger,
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(
                          builder: (_) => const ProductStockSalesReportPage())),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _HubCard extends StatelessWidget {
  final String emoji;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _HubCard({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(color: color.withOpacity(0.3)),
          boxShadow: [
            BoxShadow(
                color: color.withOpacity(0.08),
                blurRadius: 8,
                offset: const Offset(0, 2))
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              width: 44.w,
              height: 44.h,
              decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12.r)),
              child: Center(
                  child: Text(emoji, style: TextStyle(fontSize: 22.sp))),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Poppins',
                        color: AppTheme.textPrimary)),
                SizedBox(height: 2.h),
                Text(subtitle, style: AppTheme.caption),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
