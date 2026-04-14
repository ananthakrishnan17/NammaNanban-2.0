import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../domain/entities/bill.dart';

class CartItemTile extends StatelessWidget {
  final CartItem item;
  final VoidCallback onIncrease;
  final VoidCallback onDecrease;
  final VoidCallback onRemove;

  const CartItemTile({
    super.key,
    required this.item,
    required this.onIncrease,
    required this.onDecrease,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Row(
        children: [
          // Product Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.productName,
                  style: AppTheme.heading3,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 2.h),
                Text(
                  '${CurrencyFormatter.format(item.sellingPrice)} / ${item.unit}',
                  style: AppTheme.caption,
                ),
                SizedBox(height: 4.h),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.productName, // Changed from item.product.name
                      style: AppTheme.heading3,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      '${CurrencyFormatter.format(item.sellingPrice)} / ${item.unit}',
                      style: AppTheme.caption,
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      // Calculated inline to fix the "totalAmount not defined" error
                      CurrencyFormatter.format(item.sellingPrice * item.quantity),
                      style: TextStyle(
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primary,
                        fontFamily: 'Poppins',
                      ),
                    ),
                  ],
                )
              ],
            ),
          ),

          // Quantity Controls
          Row(
            children: [
              _quantityButton(
                icon: Icons.remove,
                onTap: onDecrease,
                color: item.quantity <= 1 ? AppTheme.danger : AppTheme.primary,
              ),
              SizedBox(width: 10.w),
              SizedBox(
                width: 32.w,
                child: Text(
                  item.quantity % 1 == 0
                      ? item.quantity.toInt().toString()
                      : item.quantity.toStringAsFixed(1),
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                    fontFamily: 'Poppins',
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              SizedBox(width: 10.w),
              _quantityButton(
                icon: Icons.add,
                onTap: onIncrease,
                color: AppTheme.primary,
              ),
            ],
          ),

          SizedBox(width: 8.w),
          // Delete button
          GestureDetector(
            onTap: onRemove,
            child: Container(
              width: 32.w,
              height: 32.h,
              decoration: BoxDecoration(
                color: AppTheme.danger.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8.r),
              ),
              child: Icon(Icons.delete_outline, color: AppTheme.danger, size: 18.sp),
            ),
          ),
        ],
      ),
    );
  }

  Widget _quantityButton({
    required IconData icon,
    required VoidCallback onTap,
    required Color color,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32.w,
        height: 32.h,
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8.r),
        ),
        child: Icon(icon, color: color, size: 18.sp),
      ),
    );
  }
}
