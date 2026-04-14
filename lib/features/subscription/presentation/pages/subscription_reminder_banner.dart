import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/app_theme.dart';
import '../../services/subscription_service.dart';
import '../pages/subscription_lock_screen.dart';

class SubscriptionReminderBanner extends StatefulWidget {
  const SubscriptionReminderBanner({super.key});

  @override
  State<SubscriptionReminderBanner> createState() => _SubscriptionReminderBannerState();
}

class _SubscriptionReminderBannerState extends State<SubscriptionReminderBanner> {
  int _daysLeft = 0;
  SubscriptionStatus _status = SubscriptionStatus.active;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final status = await SubscriptionService.instance.getStatus();
    final days = await SubscriptionService.instance.getDaysLeft();
    if (mounted) setState(() { _status = status; _daysLeft = days; });
  }

  @override
  Widget build(BuildContext context) {
    if (!_status.needsReminder && _status != SubscriptionStatus.expired) {
      return const SizedBox();
    }

    final isExpired = _status == SubscriptionStatus.expired;

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SubscriptionLockScreen(status: _status),
        ),
      ),
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
        decoration: BoxDecoration(
          color: isExpired ? AppTheme.danger : AppTheme.warning,
          borderRadius: BorderRadius.circular(12.r),
          boxShadow: [
            BoxShadow(
              color: (isExpired ? AppTheme.danger : AppTheme.warning).withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(
              isExpired ? Icons.lock : Icons.warning_amber_rounded,
              color: Colors.white,
              size: 20.sp,
            ),
            SizedBox(width: 10.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isExpired
                        ? 'Subscription Expired!'
                        : '⏰ Expires in $_daysLeft day${_daysLeft == 1 ? '' : 's'}!',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'Poppins',
                    ),
                  ),
                  Text(
                    isExpired
                        ? 'Tap to renew — Billing is locked'
                        : 'Tap to renew now and avoid disruption',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 11.sp,
                      fontFamily: 'Poppins',
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8.r),
              ),
              child: Text(
                'Renew ₹200',
                style: TextStyle(
                  color: isExpired ? AppTheme.danger : AppTheme.warning,
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'Poppins',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
