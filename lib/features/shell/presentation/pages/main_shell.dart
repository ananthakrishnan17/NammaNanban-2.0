import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../billing/presentation/pages/billing_screen.dart';
import '../../../expenses/presentation/pages/expenses_page.dart';
import '../../../products/presentation/pages/products_page.dart';
import '../../../reports/presentation/pages/reports_page.dart';
import '../../../sales/presentation/pages/dashboard_screen.dart';
import '../../../settings/presentation/pages/settings_page.dart';
import '../../../subscription/services/subscription_service.dart';
import '../../../subscription/presentation/pages/subscription_lock_screen.dart';
import '../../../users/domain/entities/app_user.dart';


class MainShell extends StatefulWidget {
  const MainShell({super.key});
  @override State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

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

  // Check if current user can access this tab
  bool _canAccess(int index, AppUser? user) {
    if (user == null || user.isAdmin) return true; // admin always OK
    switch (index) {
      case 0: return user.permissions.canViewDashboard;
      case 1: return user.permissions.canBill;
      case 2: return user.permissions.canManageProducts;
      case 3: return user.permissions.canViewReports;
      case 4: return true; // settings always accessible (limited view for users)
      default: return false;
    }
  }

  Future<void> _onTabTapped(int index, AppUser? user) async {
    // Subscription check for billing tab
    if (index == 1) {
      final status = await SubscriptionService.instance.getStatus();
      if (status.isLocked && mounted) {
        Navigator.push(context, MaterialPageRoute(builder: (_) => SubscriptionLockScreen(status: status)));
        return;
      }
    }
    // Permission check
    if (!_canAccess(index, user)) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('You don\'t have permission to access this.'),
        backgroundColor: AppTheme.danger,
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.only(bottom: 80.h, left: 16.w, right: 16.w),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
      ));
      return;
    }
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    // Get current user from UserBloc
    final userBloc = context.read<UserBloc>();
    final currentUser = userBloc.currentUser;

    final navItems = [
      (Icons.dashboard_rounded, 'Dashboard'),
      (Icons.point_of_sale_rounded, 'Billing'),
      (Icons.inventory_2_rounded, 'Products'),
      (Icons.receipt_long_rounded, 'Reports'),
      (Icons.settings_rounded, 'Settings'),
    ];

    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: List.generate(5, _buildPage)),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(color: Colors.white,
            border: Border(top: BorderSide(color: AppTheme.divider)),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 12, offset: const Offset(0, -4))]),
        child: SafeArea(child: SizedBox(height: 60.h,
          child: Row(children: navItems.asMap().entries.map((entry) {
            final i = entry.key; final item = entry.value;
            final isSelected = _currentIndex == i;
            final canAccess = _canAccess(i, currentUser);

            if (i == 1) { // Billing — centre highlight button
              return Expanded(child: GestureDetector(
                onTap: () => _onTabTapped(i, currentUser),
                child: Container(
                  margin: EdgeInsets.symmetric(horizontal: 4.w, vertical: 6.h),
                  decoration: BoxDecoration(
                      color: canAccess ? AppTheme.primary : AppTheme.textSecondary,
                      borderRadius: BorderRadius.circular(14.r),
                      boxShadow: [BoxShadow(color: (canAccess ? AppTheme.primary : AppTheme.textSecondary).withOpacity(0.4), blurRadius: 8, offset: const Offset(0, 3))]),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(item.$1, color: Colors.white, size: 22.sp),
                    SizedBox(height: 2.h),
                    Text(item.$2, style: TextStyle(color: Colors.white, fontSize: 10.sp, fontWeight: FontWeight.w600, fontFamily: 'Poppins')),
                  ]),
                ),
              ));
            }

            return Expanded(child: GestureDetector(
              onTap: () => _onTabTapped(i, currentUser),
              behavior: HitTestBehavior.opaque,
              child: Opacity(
                opacity: canAccess ? 1.0 : 0.35,
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  AnimatedContainer(duration: const Duration(milliseconds: 200),
                      padding: EdgeInsets.all(6.w),
                      decoration: BoxDecoration(
                          color: isSelected ? AppTheme.primary.withOpacity(0.1) : Colors.transparent,
                          borderRadius: BorderRadius.circular(10.r)),
                      child: Icon(item.$1, color: isSelected ? AppTheme.primary : AppTheme.textSecondary, size: 20.sp)),
                  SizedBox(height: 2.h),
                  Text(item.$2, style: TextStyle(color: isSelected ? AppTheme.primary : AppTheme.textSecondary,
                      fontSize: 9.sp, fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400, fontFamily: 'Poppins')),
                ]),
              ),
            ));
          }).toList()),
        )),
      ),
    );
  }
}