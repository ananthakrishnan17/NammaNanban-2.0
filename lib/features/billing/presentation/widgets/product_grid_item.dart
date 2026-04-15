import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../products/domain/entities/product.dart';
import '../../domain/entities/bill.dart';

class ProductGridItem extends StatelessWidget {
  final Product product;
  final BillType billType; // ✅ NEW — shows correct price
  final VoidCallback onTap;

  const ProductGridItem({
    super.key,
    required this.product,
    required this.billType,
    required this.onTap,
  });

  // ✅ Returns the correct display price based on bill type
  double get _displayPrice {
    if (billType == BillType.wholesale && product.wholesalePrice > 0) {
      return product.wholesalePrice;
    }
    return product.sellingPrice;
  }

  @override
  Widget build(BuildContext context) {
    final isWholesale = billType == BillType.wholesale;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: product.isOutOfStock ? AppTheme.outOfStockColor : Colors.white,
          borderRadius: BorderRadius.circular(14.r),
          border: Border.all(
            color: product.isLowStock
                ? AppTheme.warning
                : product.isOutOfStock
                ? AppTheme.danger.withOpacity(0.3)
                : AppTheme.divider,
            width: product.isLowStock ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2)),
          ],
        ),
        child: Stack(
          children: [
            Padding(
              padding: EdgeInsets.all(9.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Emoji icon area
                  Container(
                    width: double.infinity,
                    height: 42.h,
                    decoration: BoxDecoration(
                      color: _getCategoryColor(),
                      borderRadius: BorderRadius.circular(9.r),
                    ),
                    child: Center(
                      child: Text(_getCategoryEmoji(), style: TextStyle(fontSize: 20.sp)),
                    ),
                  ),
                  SizedBox(height: 5.h),

                  // Product name
                  Text(
                    product.name,
                    style: TextStyle(
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w600,
                      color: product.isOutOfStock ? AppTheme.textSecondary : AppTheme.textPrimary,
                      fontFamily: 'Poppins',
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const Spacer(),

                  // ✅ Price — shows wholesale or retail based on toggle
                  Text(
                    CurrencyFormatter.format(_displayPrice),
                    style: TextStyle(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w700,
                      color: product.isOutOfStock
                          ? AppTheme.textSecondary
                          : isWholesale
                          ? AppTheme.secondary
                          : AppTheme.primary,
                      fontFamily: 'Poppins',
                    ),
                  ),

                  // Stock info
                  Text(
                    '${product.stockQuantity % 1 == 0 ? product.stockQuantity.toInt() : product.stockQuantity} ${product.displayUnit}',
                    style: TextStyle(
                      fontSize: 9.sp,
                      color: product.isLowStock ? AppTheme.warning : AppTheme.textSecondary,
                      fontWeight: FontWeight.w500,
                      fontFamily: 'Poppins',
                    ),
                  ),
                ],
              ),
            ),

            // Status badges
            if (product.isOutOfStock)
              Positioned(
                top: 5.h, right: 5.w,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
                  decoration: BoxDecoration(color: AppTheme.danger, borderRadius: BorderRadius.circular(4.r)),
                  child: Text('OUT', style: TextStyle(color: Colors.white, fontSize: 7.sp, fontWeight: FontWeight.w700)),
                ),
              )
            else if (product.isLowStock)
              Positioned(
                top: 5.h, right: 5.w,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
                  decoration: BoxDecoration(color: AppTheme.warning, borderRadius: BorderRadius.circular(4.r)),
                  child: Text('LOW', style: TextStyle(color: Colors.white, fontSize: 7.sp, fontWeight: FontWeight.w700)),
                ),
              ),

            // ✅ Wholesale badge
            if (isWholesale && product.wholesalePrice > 0)
              Positioned(
                bottom: 28.h, right: 5.w,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.h),
                  decoration: BoxDecoration(
                    color: AppTheme.secondary.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(3.r),
                  ),
                  child: Text('WS', style: TextStyle(color: AppTheme.secondary, fontSize: 7.sp, fontWeight: FontWeight.w700)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Color _getCategoryColor() {
    const colors = [
      Color(0xFFFFF3E0), Color(0xFFE8F5E9), Color(0xFFFCE4EC),
      Color(0xFFE3F2FD), Color(0xFFF3E5F5), Color(0xFFE0F2F1),
    ];
    return colors[(product.categoryId ?? 0) % colors.length];
  }

  String _getCategoryEmoji() {
    final name = (product.categoryName ?? '').toLowerCase();
    if (name.contains('beverage') || name.contains('drink')) return '☕';
    if (name.contains('food')) return '🍱';
    if (name.contains('snack')) return '🍪';
    if (name.contains('sweet')) return '🍬';
    if (name.contains('bakery') || name.contains('bread')) return '🥖';
    return '📦';
  }
}