import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/theme/app_theme.dart';

/// Validated mobile number input widget.
/// Calls [onChanged] with the raw 10-digit number whenever valid.
class MobileNumberInput extends StatefulWidget {
  final TextEditingController controller;
  final String? errorText;
  final ValueChanged<String>? onChanged;
  final bool enabled;

  const MobileNumberInput({
    super.key,
    required this.controller,
    this.errorText,
    this.onChanged,
    this.enabled = true,
  });

  @override
  State<MobileNumberInput> createState() => _MobileNumberInputState();
}

class _MobileNumberInputState extends State<MobileNumberInput> {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Mobile Number',
          style: TextStyle(
            fontSize: 13.sp,
            fontWeight: FontWeight.w600,
            color: Colors.white70,
            fontFamily: 'Poppins',
          ),
        ),
        SizedBox(height: 8.h),
        TextField(
          controller: widget.controller,
          enabled: widget.enabled,
          keyboardType: TextInputType.phone,
          maxLength: 10,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: TextStyle(
            color: Colors.white,
            fontFamily: 'Poppins',
            fontSize: 16.sp,
            letterSpacing: 1.5,
          ),
          decoration: InputDecoration(
            counterText: '',
            hintText: '9876543210',
            hintStyle: TextStyle(color: Colors.white30, fontFamily: 'Poppins', fontSize: 14.sp),
            prefixIcon: Padding(
              padding: EdgeInsets.symmetric(horizontal: 12.w),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.phone_android, color: Colors.white54, size: 18.sp),
                  SizedBox(width: 6.w),
                  Text(
                    '+91',
                    style: TextStyle(
                      color: Colors.white70,
                      fontFamily: 'Poppins',
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(width: 6.w),
                  Container(width: 1, height: 20.h, color: Colors.white24),
                ],
              ),
            ),
            filled: true,
            fillColor: Colors.white.withOpacity(0.08),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.r),
              borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.r),
              borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.r),
              borderSide: BorderSide(color: AppTheme.primary, width: 1.5),
            ),
            errorText: widget.errorText,
            errorStyle: TextStyle(
              color: AppTheme.danger,
              fontSize: 11.sp,
              fontFamily: 'Poppins',
            ),
          ),
          onChanged: (val) {
            if (widget.onChanged != null) widget.onChanged!(val);
          },
        ),
      ],
    );
  }
}

/// Returns null if valid, or an error message
String? validateMobileNumber(String value) {
  final digits = value.replaceAll(RegExp(r'\D'), '');
  if (digits.isEmpty) return 'Please enter your mobile number';
  if (digits.length != 10) return 'Enter a valid 10-digit mobile number';
  if (!RegExp(r'^[6-9]\d{9}$').hasMatch(digits)) {
    return 'Enter a valid Indian mobile number';
  }
  return null;
}
