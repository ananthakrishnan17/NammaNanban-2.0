import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/theme/app_theme.dart';

class ReportSummaryCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final String emoji;

  const ReportSummaryCard({
    super.key,
    required this.label,
    required this.value,
    required this.color,
    required this.emoji,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(emoji, style: TextStyle(fontSize: 18.sp)),
              const Spacer(),
              Container(
                  width: 8.w,
                  height: 8.h,
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
            ],
          ),
          SizedBox(height: 6.h),
          Text(label, style: AppTheme.caption),
          Text(value,
              style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w700,
                  color: color,
                  fontFamily: 'Poppins')),
        ],
      ),
    );
  }
}
