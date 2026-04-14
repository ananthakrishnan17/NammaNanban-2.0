import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/theme/app_theme.dart';

class SetPinScreen extends StatefulWidget {
  final VoidCallback onPinSet;
  const SetPinScreen({super.key, required this.onPinSet});

  @override
  State<SetPinScreen> createState() => _SetPinScreenState();
}

class _SetPinScreenState extends State<SetPinScreen> {
  String _pin = '';
  String _confirmPin = '';
  bool _isConfirming = false;
  String? _errorMsg;

  void _onKey(String digit) {
    if (_isConfirming) {
      if (_confirmPin.length >= 4) return;
      setState(() => _confirmPin += digit);
      if (_confirmPin.length == 4) _checkMatch();
    } else {
      if (_pin.length >= 4) return;
      setState(() => _pin += digit);
      if (_pin.length == 4) setState(() => _isConfirming = true);
    }
  }

  void _onDelete() {
    setState(() {
      if (_isConfirming) {
        if (_confirmPin.isNotEmpty) _confirmPin = _confirmPin.substring(0, _confirmPin.length - 1);
      } else {
        if (_pin.isNotEmpty) _pin = _pin.substring(0, _pin.length - 1);
      }
    });
  }

  Future<void> _checkMatch() async {
    if (_pin == _confirmPin) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('shop_pin', _pin);
      widget.onPinSet();
    } else {
      setState(() {
        _errorMsg = 'PINs do not match. Try again.';
        _pin = '';
        _confirmPin = '';
        _isConfirming = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final current = _isConfirming ? _confirmPin : _pin;
    return Column(
      children: [
        Text(
          _isConfirming ? 'Confirm your PIN' : 'Set a 4-digit PIN',
          style: AppTheme.heading3,
        ),
        SizedBox(height: 4.h),
        Text(
          _isConfirming ? 'Enter the PIN again to confirm' : 'This protects your billing app',
          style: AppTheme.caption,
        ),
        SizedBox(height: 24.h),

        // Dots
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(4, (i) {
            return AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              margin: EdgeInsets.symmetric(horizontal: 10.w),
              width: 16.w,
              height: 16.h,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: i < current.length ? AppTheme.primary : AppTheme.divider,
              ),
            );
          }),
        ),

        if (_errorMsg != null) ...[
          SizedBox(height: 10.h),
          Text(_errorMsg!, style: TextStyle(color: AppTheme.danger, fontSize: 12.sp, fontFamily: 'Poppins')),
        ],

        SizedBox(height: 24.h),

        // Keypad
        ...([
          ['1', '2', '3'],
          ['4', '5', '6'],
          ['7', '8', '9'],
        ].map((row) => Padding(
          padding: EdgeInsets.only(bottom: 10.h),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: row.map((d) => _key(d)).toList(),
          ),
        ))),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(width: 64.w + 20.w),
            _key('0'),
            GestureDetector(
              onTap: _onDelete,
              child: Container(
                width: 64.w, height: 52.h,
                margin: EdgeInsets.symmetric(horizontal: 10.w),
                decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(10.r)),
                child: Icon(Icons.backspace_outlined, size: 20.sp, color: AppTheme.textSecondary),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _key(String digit) {
    return GestureDetector(
      onTap: () => _onKey(digit),
      child: Container(
        width: 64.w,
        height: 52.h,
        margin: EdgeInsets.symmetric(horizontal: 10.w),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10.r),
          border: Border.all(color: AppTheme.divider),
        ),
        child: Center(
          child: Text(digit, style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.w600, fontFamily: 'Poppins')),
        ),
      ),
    );
  }
}
