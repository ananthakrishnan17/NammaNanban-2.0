import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../products/domain/entities/product.dart';

class ProductGridItem extends StatelessWidget {
  final Product product;
  final VoidCallback onTap;

  const ProductGridItem({super.key, required this.product, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: product.isOutOfStock
              ? AppTheme.outOfStockColor
              : Colors.white,
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
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Main Content
            Padding(
              padding: EdgeInsets.all(10.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Emoji / Icon placeholder
                  Container(
                    width: double.infinity,
                    height: 44.h,
                    decoration: BoxDecoration(
                      color: _getCategoryColor(),
                      borderRadius: BorderRadius.circular(10.r),
                    ),
                    child: Center(
                      child: Text(
                        _getCategoryEmoji(),
                        style: TextStyle(fontSize: 22.sp),
                      ),
                    ),
                  ),
                  SizedBox(height: 6.h),
                  // Product Name
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
                  // Price
                  Text(
                    CurrencyFormatter.format(product.sellingPrice),
                    style: TextStyle(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w700,
                      color: product.isOutOfStock ? AppTheme.textSecondary : AppTheme.primary,
                      fontFamily: 'Poppins',
                    ),
                  ),
                  // Stock
                  Text(
                    '${product.stockQuantity} ${product.unit}',
                    style: TextStyle(
                      fontSize: 9.sp,
                      color: product.isLowStock
                          ? AppTheme.warning
                          : AppTheme.textSecondary,
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
                top: 6.h,
                right: 6.w,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 2.h),
                  decoration: BoxDecoration(
                    color: AppTheme.danger,
                    borderRadius: BorderRadius.circular(4.r),
                  ),
                  child: Text(
                    'OUT',
                    style: TextStyle(color: Colors.white, fontSize: 7.sp, fontWeight: FontWeight.w700),
                  ),
                ),
              )
            else if (product.isLowStock)
              Positioned(
                top: 6.h,
                right: 6.w,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 2.h),
                  decoration: BoxDecoration(
                    color: AppTheme.warning,
                    borderRadius: BorderRadius.circular(4.r),
                  ),
                  child: Text(
                    'LOW',
                    style: TextStyle(color: Colors.white, fontSize: 7.sp, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Color _getCategoryColor() {
    // Return light pastel background based on category
    const colors = [
      Color(0xFFFFF3E0), Color(0xFFE8F5E9), Color(0xFFFCE4EC),
      Color(0xFFE3F2FD), Color(0xFFF3E5F5), Color(0xFFE0F2F1),
    ];
    return colors[(product.categoryId ?? 0) % colors.length];
  }

  String _getCategoryEmoji() {
    final name = product.categoryName?.toLowerCase() ?? '';
    if (name.contains('beverage') || name.contains('drink')) return '☕';
    if (name.contains('food')) return '🍱';
    if (name.contains('snack')) return '🍪';
    if (name.contains('sweet')) return '🍬';
    if (name.contains('bakery') || name.contains('bread')) return '🥖';
    return '📦';
  }
}
