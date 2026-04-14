import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../shell/presentation/pages/main_shell.dart';
import '../../../subscription/services/subscription_service.dart';
import '../../../subscription/presentation/pages/subscription_lock_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with TickerProviderStateMixin {
  String _enteredPin = '';
  String _shopName = '';
  bool _isWrong = false;
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _shakeAnimation = Tween<double>(begin: 0, end: 12).chain(
      CurveTween(curve: Curves.elasticIn),
    ).animate(_shakeController);
    _loadShopName();
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  Future<void> _loadShopName() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _shopName = prefs.getString('shop_name') ?? 'Shop POS');
  }

  void _onKeyPress(String digit) {
    if (_enteredPin.length >= 4) return;
    setState(() {
      _enteredPin += digit;
      _isWrong = false;
    });
    if (_enteredPin.length == 4) _verifyPin();
  }

  void _onDelete() {
    if (_enteredPin.isEmpty) return;
    setState(() => _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1));
  }

  Future<void> _verifyPin() async {
    final prefs = await SharedPreferences.getInstance();
    final storedPin = prefs.getString('shop_pin') ?? '0000';

    if (_enteredPin == storedPin) {
      // Check subscription before entering app
      final status = await SubscriptionService.instance.getStatus();
      if (!mounted) return;

      if (status.isLocked) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => SubscriptionLockScreen(status: status)),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const MainShell()),
        );
      }
    } else {
      setState(() { _isWrong = true; _enteredPin = ''; });
      _shakeController.forward(from: 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.secondary,
      body: SafeArea(
        child: Column(
          children: [
            SizedBox(height: 60.h),

            // Logo
            Container(
              width: 72.w,
              height: 72.h,
              decoration: BoxDecoration(
                color: AppTheme.primary,
                borderRadius: BorderRadius.circular(20.r),
              ),
              child: Icon(Icons.point_of_sale, color: Colors.white, size: 40.sp),
            ),
            SizedBox(height: 16.h),

            Text(
              _shopName,
              style: TextStyle(
                fontSize: 22.sp,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                fontFamily: 'Poppins',
              ),
            ),
            SizedBox(height: 4.h),
            Text(
              'Enter your PIN to continue',
              style: TextStyle(
                fontSize: 14.sp,
                color: Colors.white60,
                fontFamily: 'Poppins',
              ),
            ),

            SizedBox(height: 48.h),

            // PIN Dots
            AnimatedBuilder(
              animation: _shakeAnimation,
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(_isWrong ? _shakeAnimation.value * ((_shakeController.value * 10).toInt() % 2 == 0 ? 1 : -1) : 0, 0),
                  child: child,
                );
              },
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(4, (i) {
                  final filled = i < _enteredPin.length;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    margin: EdgeInsets.symmetric(horizontal: 10.w),
                    width: 18.w,
                    height: 18.h,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _isWrong
                          ? AppTheme.danger
                          : filled
                          ? AppTheme.primary
                          : Colors.white.withOpacity(0.3),
                      border: Border.all(
                        color: _isWrong
                            ? AppTheme.danger
                            : filled
                            ? AppTheme.primary
                            : Colors.white.withOpacity(0.5),
                        width: 2,
                      ),
                    ),
                  );
                }),
              ),
            ),

            if (_isWrong) ...[
              SizedBox(height: 12.h),
              Text(
                'Wrong PIN. Try again.',
                style: TextStyle(color: AppTheme.danger, fontSize: 13.sp, fontFamily: 'Poppins'),
              ),
            ],

            const Spacer(),

            // Number Pad
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 40.w),
              child: Column(
                children: [
                  _buildRow(['1', '2', '3']),
                  SizedBox(height: 12.h),
                  _buildRow(['4', '5', '6']),
                  SizedBox(height: 12.h),
                  _buildRow(['7', '8', '9']),
                  SizedBox(height: 12.h),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      const SizedBox(width: 72),
                      _buildKey('0'),
                      _buildDeleteKey(),
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(height: 40.h),
          ],
        ),
      ),
    );
  }

  Widget _buildRow(List<String> digits) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: digits.map(_buildKey).toList(),
    );
  }

  Widget _buildKey(String digit) {
    return GestureDetector(
      onTap: () => _onKeyPress(digit),
      child: Container(
        width: 72.w,
        height: 72.h,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withOpacity(0.2)),
        ),
        child: Center(
          child: Text(
            digit,
            style: TextStyle(
              fontSize: 24.sp,
              fontWeight: FontWeight.w600,
              color: Colors.white,
              fontFamily: 'Poppins',
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDeleteKey() {
    return GestureDetector(
      onTap: _onDelete,
      child: Container(
        width: 72.w,
        height: 72.h,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.08),
          shape: BoxShape.circle,
        ),
        child: Icon(Icons.backspace_outlined, color: Colors.white70, size: 22.sp),
      ),
    );
  }
}
