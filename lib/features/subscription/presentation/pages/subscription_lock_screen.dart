import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/theme/app_theme.dart';
import '../../services/subscription_service.dart';
import '../../../shell/presentation/pages/main_shell.dart';

class SubscriptionLockScreen extends StatefulWidget {
  final SubscriptionStatus status;
  const SubscriptionLockScreen({super.key, required this.status});

  @override
  State<SubscriptionLockScreen> createState() => _SubscriptionLockScreenState();
}

class _SubscriptionLockScreenState extends State<SubscriptionLockScreen> {
  final _keyCtrl = TextEditingController();
  bool _isActivating = false;
  String? _errorMsg;
  bool _isTrialActivating = false;

  @override
  void dispose() {
    _keyCtrl.dispose();
    super.dispose();
  }

  Future<void> _activate() async {
    if (_keyCtrl.text.trim().isEmpty) {
      setState(() => _errorMsg = 'Please enter a license key');
      return;
    }
    setState(() { _isActivating = true; _errorMsg = null; });

    final success = await SubscriptionService.instance
        .activateWithKey(_keyCtrl.text.trim());

    setState(() => _isActivating = false);

    if (success && mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const MainShell()),
      );
    } else {
      setState(() => _errorMsg = 'Invalid license key. Please check and try again.');
    }
  }

  Future<void> _activateTrial() async {
    setState(() => _isTrialActivating = true);
    await SubscriptionService.instance.activateFreeTrial();
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const MainShell()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isExpired = widget.status == SubscriptionStatus.expired;

    return Scaffold(
      backgroundColor: AppTheme.secondary,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(24.w),
          child: Column(
            children: [
              SizedBox(height: 40.h),

              // Lock Icon
              Container(
                width: 90.w,
                height: 90.h,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isExpired ? Icons.lock_clock : Icons.lock_outline,
                  color: Colors.white,
                  size: 44.sp,
                ),
              ),
              SizedBox(height: 24.h),

              Text(
                isExpired ? 'Subscription Expired' : 'Activate Shop POS',
                style: TextStyle(
                  fontSize: 24.sp,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  fontFamily: 'Poppins',
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 8.h),

              Text(
                isExpired
                    ? 'Your subscription has expired.\nRenew to continue billing.'
                    : 'Enter your license key to activate\nthe app and start billing.',
                style: TextStyle(
                  fontSize: 14.sp,
                  color: Colors.white70,
                  fontFamily: 'Poppins',
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 40.h),

              // Pricing Card
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(20.w),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20.r),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Plan badge
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20.r),
                      ),
                      child: Text(
                        'MONTHLY PLAN',
                        style: TextStyle(
                          fontSize: 11.sp,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.primary,
                          letterSpacing: 1.2,
                          fontFamily: 'Poppins',
                        ),
                      ),
                    ),
                    SizedBox(height: 12.h),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('₹', style: TextStyle(fontSize: 20.sp, color: AppTheme.primary, fontFamily: 'Poppins', fontWeight: FontWeight.w600)),
                        Text('200', style: TextStyle(fontSize: 48.sp, fontWeight: FontWeight.w700, color: AppTheme.primary, fontFamily: 'Poppins')),
                        Padding(
                          padding: EdgeInsets.only(top: 14.h),
                          child: Text('/month', style: TextStyle(fontSize: 14.sp, color: AppTheme.textSecondary, fontFamily: 'Poppins')),
                        ),
                      ],
                    ),
                    SizedBox(height: 12.h),

                    // Features
                    ...[
                      '✅  Unlimited billing',
                      '✅  Product & stock management',
                      '✅  Sales & profit reports',
                      '✅  Bluetooth thermal printing',
                      '✅  Google Drive backup',
                      '✅  Expense tracking',
                    ].map((f) => Padding(
                      padding: EdgeInsets.only(bottom: 6.h),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(f, style: TextStyle(fontSize: 13.sp, fontFamily: 'Poppins', color: AppTheme.textPrimary)),
                      ),
                    )),

                    SizedBox(height: 16.h),
                    Divider(color: AppTheme.divider),
                    SizedBox(height: 16.h),

                    // License Key Input
                    Text('Enter License Key', style: AppTheme.heading3),
                    SizedBox(height: 8.h),
                    TextField(
                      controller: _keyCtrl,
                      decoration: InputDecoration(
                        hintText: 'SHOP-XXXX-XXXX-XXXX',
                        prefixIcon: const Icon(Icons.vpn_key),
                        errorText: _errorMsg,
                      ),
                      textCapitalization: TextCapitalization.characters,
                      inputFormatters: [
                        TextInputFormatter.withFunction((old, newVal) {
                          // Auto-format: SHOP-XXXX-XXXX-XXXX
                          var text = newVal.text.replaceAll('-', '').toUpperCase();
                          if (text.length > 4 && !text.startsWith('SHOP')) {
                            text = 'SHOP${text.replaceFirst('SHOP', '')}';
                          }
                          return newVal.copyWith(text: newVal.text.toUpperCase());
                        }),
                      ],
                    ),
                    SizedBox(height: 12.h),

                    // Activate Button
                    ElevatedButton(
                      onPressed: _isActivating ? null : _activate,
                      style: ElevatedButton.styleFrom(
                        minimumSize: Size(double.infinity, 50.h),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                      ),
                      child: _isActivating
                          ? const CircularProgressIndicator(color: Colors.white)
                          : Text(isExpired ? 'Renew Subscription' : 'Activate Now'),
                    ),
                    SizedBox(height: 10.h),

                    // Contact info
                    Text(
                      'Contact us to get your license key:\n📞 +91 98765 43210',
                      style: AppTheme.caption.copyWith(fontSize: 11.sp),
                      textAlign: TextAlign.center,
                    ),

                    // Free trial (only for new activation)
                    if (!isExpired) ...[
                      SizedBox(height: 12.h),
                      Divider(color: AppTheme.divider),
                      SizedBox(height: 8.h),
                      TextButton(
                        onPressed: _isTrialActivating ? null : _activateTrial,
                        child: _isTrialActivating
                            ? const CircularProgressIndicator()
                            : Text(
                          'Start 30-day free trial',
                          style: TextStyle(color: AppTheme.primary, fontFamily: 'Poppins', fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              SizedBox(height: 40.h),
            ],
          ),
        ),
      ),
    );
  }
}
