import 'package:NammaNanban/features/users/domain/entities/product_uom.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../../../../core/theme/app_theme.dart';
import '../../../../../../../core/utils/currency_formatter.dart';

import '../../../billing/domain/entities/bill.dart';
import '../../../products/domain/entities/product.dart';

/// Bottom sheet to pick which UOM to use when adding a product to cart.
/// Shown when a product has multiple UOMs set up.
class UomPickerSheet extends StatelessWidget {
  final Product product;
  final List<ProductUom> uoms;
  final BillType billType;
  final void Function(ProductUom selected) onSelect;

  const UomPickerSheet({
    super.key,
    required this.product,
    required this.uoms,
    required this.billType,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final isWholesale = billType == BillType.wholesale;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(height: 12.h),
          Container(width: 40.w, height: 4.h,
              decoration: BoxDecoration(color: AppTheme.divider, borderRadius: BorderRadius.circular(2.r))),
          SizedBox(height: 14.h),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 20.w),
            child: Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Select Unit', style: AppTheme.heading2),
                Text(product.name, style: AppTheme.caption),
              ])),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                decoration: BoxDecoration(
                  color: isWholesale ? AppTheme.secondary.withOpacity(0.12) : AppTheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Text(
                  isWholesale ? '📦 Wholesale' : '🛒 Retail',
                  style: TextStyle(
                    fontSize: 11.sp, fontWeight: FontWeight.w600, fontFamily: 'Poppins',
                    color: isWholesale ? AppTheme.secondary : AppTheme.primary,
                  ),
                ),
              ),
            ]),
          ),
          SizedBox(height: 12.h),
          const Divider(height: 1),
          // UOM list
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.all(14.w),
            itemCount: uoms.length,
            separatorBuilder: (_, __) => SizedBox(height: 8.h),
            itemBuilder: (_, i) {
              final uom = uoms[i];
              final price = uom.effectivePrice(isWholesale);
              final isDefault = uom.isDefault;

              return GestureDetector(
                onTap: () {
                  onSelect(uom);
                  Navigator.pop(context);
                },
                child: Container(
                  padding: EdgeInsets.all(14.w),
                  decoration: BoxDecoration(
                    color: isDefault ? (isWholesale ? AppTheme.secondary : AppTheme.primary).withOpacity(0.06) : Colors.white,
                    borderRadius: BorderRadius.circular(12.r),
                    border: Border.all(
                      color: isDefault
                          ? (isWholesale ? AppTheme.secondary : AppTheme.primary).withOpacity(0.3)
                          : AppTheme.divider,
                      width: isDefault ? 1.5 : 1,
                    ),
                  ),
                  child: Row(children: [
                    // UOM icon
                    Container(
                      width: 44.w, height: 44.h,
                      decoration: BoxDecoration(
                        color: isWholesale ? AppTheme.secondary.withOpacity(0.1) : AppTheme.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10.r),
                      ),
                      child: Center(
                        child: Text(
                          uom.uomShortName,
                          style: TextStyle(
                            fontSize: uom.uomShortName.length > 3 ? 10.sp : 14.sp,
                            fontWeight: FontWeight.w700,
                            color: isWholesale ? AppTheme.secondary : AppTheme.primary,
                            fontFamily: 'Poppins',
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 12.w),
                    // Info
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Text(uom.uomName, style: AppTheme.heading3),
                        if (isDefault) ...[
                          SizedBox(width: 6.w),
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 2.h),
                            decoration: BoxDecoration(
                              color: AppTheme.warning.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(4.r),
                            ),
                            child: Text('Default', style: TextStyle(fontSize: 9.sp, color: AppTheme.warning, fontWeight: FontWeight.w700, fontFamily: 'Poppins')),
                          ),
                        ],
                      ]),
                      if (uom.conversionQty > 1)
                        Text(
                          '${uom.conversionQty.toInt()} ${product.displayUnit} per ${uom.uomShortName}',
                          style: AppTheme.caption,
                        ),
                    ])),
                    // Price
                    Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Text(
                        CurrencyFormatter.format(price),
                        style: TextStyle(
                          fontSize: 18.sp, fontWeight: FontWeight.w700, fontFamily: 'Poppins',
                          color: isWholesale ? AppTheme.secondary : AppTheme.primary,
                        ),
                      ),
                      Text('per ${uom.uomShortName}', style: AppTheme.caption),
                    ]),
                  ]),
                ),
              );
            },
          ),
          SizedBox(height: 16.h),
        ],
      ),
    );
  }
}