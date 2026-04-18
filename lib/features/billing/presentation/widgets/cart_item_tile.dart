import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../domain/entities/bill.dart';

class CartItemTile extends StatelessWidget {
  final CartItem item;
  final BillType billType; // ✅ NEW
  final VoidCallback onIncrease;
  final VoidCallback onDecrease;
  final VoidCallback onRemove;

  const CartItemTile({
    super.key,
    required this.item,
    required this.billType,
    required this.onIncrease,
    required this.onDecrease,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final effectivePrice = item.effectivePrice(billType);
    final total = item.totalFor(billType);
    final isWholesale = billType == BillType.wholesale;

    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(
          color: isWholesale ? AppTheme.secondary.withOpacity(0.3) : AppTheme.divider,
        ),
      ),
      child: Row(
        children: [
          // Product Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.productName, style: AppTheme.heading3, maxLines: 1, overflow: TextOverflow.ellipsis),
                SizedBox(height: 2.h),
                Row(
                  children: [
                    Text(
                      '${CurrencyFormatter.format(effectivePrice)} / ${item.unit}',
                      style: AppTheme.caption,
                    ),
                    if (isWholesale) ...[
                      SizedBox(width: 4.w),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.h),
                        decoration: BoxDecoration(
                          color: AppTheme.secondary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(3.r),
                        ),
                        child: Text('WS', style: TextStyle(
                          fontSize: 8.sp, color: AppTheme.secondary,
                          fontWeight: FontWeight.w700, fontFamily: 'Poppins',
                        )),
                      ),
                    ],
                  ],
                ),
                if (item.conversionQty != 1.0) ...[
                  SizedBox(height: 2.h),
                  Text(
                    '= ${(item.quantity * item.conversionQty).toStringAsFixed(2)} ${item.unit.replaceAll(RegExp(r'\(.*\)'), '').trim()} base',
                    style: AppTheme.caption.copyWith(
                        color: AppTheme.accent, fontSize: 10.sp),
                  ),
                ],
                SizedBox(height: 4.h),
                Text(
                  CurrencyFormatter.format(total),
                  style: TextStyle(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w700,
                    color: isWholesale ? AppTheme.secondary : AppTheme.primary,
                    fontFamily: 'Poppins',
                  ),
                ),
              ],
            ),
          ),

          // Qty controls
          Row(
            children: [
              _qtyBtn(
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
                    fontSize: 16.sp, fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary, fontFamily: 'Poppins',
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              SizedBox(width: 10.w),
              _qtyBtn(icon: Icons.add, onTap: onIncrease, color: isWholesale ? AppTheme.secondary : AppTheme.primary),
            ],
          ),

          SizedBox(width: 8.w),
          // Delete
          GestureDetector(
            onTap: onRemove,
            child: Container(
              width: 32.w, height: 32.h,
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

  Widget _qtyBtn({required IconData icon, required VoidCallback onTap, required Color color}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32.w, height: 32.h,
        decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8.r)),
        child: Icon(icon, color: color, size: 18.sp),
      ),
    );
  }
}