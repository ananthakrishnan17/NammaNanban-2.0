import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';

class DateRangeFilter extends StatelessWidget {
  final DateTime from;
  final DateTime to;
  final Function(DateTime, DateTime) onChanged;

  const DateRangeFilter({
    super.key,
    required this.from,
    required this.to,
    required this.onChanged,
  });

  Future<void> _pickDate(BuildContext context, bool isFrom) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isFrom ? from : to,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: ColorScheme.light(primary: AppTheme.primary),
        ),
        child: child!,
      ),
    );
    if (picked == null) return;
    if (isFrom) {
      onChanged(picked, to.isBefore(picked) ? picked : to);
    } else {
      onChanged(from.isAfter(picked) ? picked : from, picked);
    }
  }

  void _setRange(DateTime f, DateTime t) => onChanged(f, t);

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _quickBtn('Today', () => _setRange(
              DateTime(now.year, now.month, now.day),
              DateTime(now.year, now.month, now.day, 23, 59, 59),
            )),
            SizedBox(width: 8.w),
            _quickBtn('This Week', () {
              final monday = now.subtract(Duration(days: now.weekday - 1));
              _setRange(DateTime(monday.year, monday.month, monday.day),
                  DateTime(now.year, now.month, now.day, 23, 59, 59));
            }),
            SizedBox(width: 8.w),
            _quickBtn('This Month', () => _setRange(
              DateTime(now.year, now.month, 1),
              DateTime(now.year, now.month + 1, 0, 23, 59, 59),
            )),
          ],
        ),
        SizedBox(height: 8.h),
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () => _pickDate(context, true),
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10.r),
                    border: Border.all(color: AppTheme.primary),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.calendar_today, size: 14.sp, color: AppTheme.primary),
                      SizedBox(width: 6.w),
                      Text(DateFormat('dd MMM yyyy').format(from),
                          style: TextStyle(
                              fontSize: 13.sp,
                              fontFamily: 'Poppins',
                              color: AppTheme.textPrimary)),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 8.w),
              child: Text('→', style: TextStyle(color: AppTheme.textSecondary, fontSize: 14.sp)),
            ),
            Expanded(
              child: GestureDetector(
                onTap: () => _pickDate(context, false),
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10.r),
                    border: Border.all(color: AppTheme.primary),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.calendar_today, size: 14.sp, color: AppTheme.primary),
                      SizedBox(width: 6.w),
                      Text(DateFormat('dd MMM yyyy').format(to),
                          style: TextStyle(
                              fontSize: 13.sp,
                              fontFamily: 'Poppins',
                              color: AppTheme.textPrimary)),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _quickBtn(String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
        decoration: BoxDecoration(
          color: AppTheme.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20.r),
          border: Border.all(color: AppTheme.primary.withOpacity(0.3)),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 11.sp,
                fontFamily: 'Poppins',
                color: AppTheme.primary,
                fontWeight: FontWeight.w500)),
      ),
    );
  }
}
