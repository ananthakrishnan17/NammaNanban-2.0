import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../billing/presentation/pages/billing_screen.dart';
import '../../../expenses/presentation/pages/expenses_page.dart';
import '../../../masters/presentation/pages/masters_page.dart';
import '../../../products/presentation/pages/products_page.dart';
import '../../../purchase/presentation/pages/add_purchase_page.dart';
import '../../../reports/presentation/pages/reports_page.dart';
import '../../../sale_return/presentation/pages/sale_return_page.dart';
import '../../../sales/presentation/pages/dashboard_screen.dart';
import '../../../settings/presentation/pages/settings_page.dart';
import '../../../subscription/services/subscription_service.dart';
import '../../../subscription/presentation/pages/subscription_lock_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});
  @override State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  // 5 main tabs. Purchase/Masters/SaleReturn accessible via Settings or quick action
  Widget _buildPage(int index) {
    switch (index) {
      case 0: return const DashboardScreen();
      case 1: return const BillingScreen();
      case 2: return const ProductsPage();
      case 3: return const ReportsPage();
      case 4: return const SettingsPage();
      default: return const DashboardScreen();
    }
  }

  Future<void> _onTabTapped(int index) async {
    if (index == 1) {
      final status = await SubscriptionService.instance.getStatus();
      if (status.isLocked && mounted) {
        Navigator.push(context, MaterialPageRoute(builder: (_) => SubscriptionLockScreen(status: status)));
        return;
      }
    }
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: List.generate(5, _buildPage)),
      bottomNavigationBar: _buildNavBar(),
    );
  }

  Widget _buildNavBar() {
    final items = [
      (Icons.dashboard_rounded, 'Dashboard'),
      (Icons.point_of_sale_rounded, 'Billing'),
      (Icons.inventory_2_rounded, 'Products'),
      (Icons.receipt_long_rounded, 'Reports'),
      (Icons.settings_rounded, 'Settings'),
    ];
    return Container(
      decoration: BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: AppTheme.divider)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 12, offset: const Offset(0, -4))]),
      child: SafeArea(child: SizedBox(height: 60.h,
        child: Row(children: items.asMap().entries.map((entry) {
          final i = entry.key; final item = entry.value;
          final isSelected = _currentIndex == i;
          if (i == 1) {
            return Expanded(child: GestureDetector(onTap: () => _onTabTapped(i),
              child: Container(
                margin: EdgeInsets.symmetric(horizontal: 4.w, vertical: 6.h),
                decoration: BoxDecoration(color: AppTheme.primary, borderRadius: BorderRadius.circular(14.r),
                    boxShadow: [BoxShadow(color: AppTheme.primary.withOpacity(0.4), blurRadius: 8, offset: const Offset(0, 3))]),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(item.$1, color: Colors.white, size: 22.sp),
                  SizedBox(height: 2.h),
                  Text(item.$2, style: TextStyle(color: Colors.white, fontSize: 10.sp, fontWeight: FontWeight.w600, fontFamily: 'Poppins')),
                ]),
              ),
            ));
          }
          return Expanded(child: GestureDetector(onTap: () => _onTabTapped(i), behavior: HitTestBehavior.opaque,
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              AnimatedContainer(duration: const Duration(milliseconds: 200),
                  padding: EdgeInsets.all(6.w),
                  decoration: BoxDecoration(color: isSelected ? AppTheme.primary.withOpacity(0.1) : Colors.transparent, borderRadius: BorderRadius.circular(10.r)),
                  child: Icon(item.$1, color: isSelected ? AppTheme.primary : AppTheme.textSecondary, size: 20.sp)),
              SizedBox(height: 2.h),
              Text(item.$2, style: TextStyle(color: isSelected ? AppTheme.primary : AppTheme.textSecondary,
                  fontSize: 9.sp, fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400, fontFamily: 'Poppins')),
            ]),
          ));
        }).toList()),
      )),
    );
  }
}