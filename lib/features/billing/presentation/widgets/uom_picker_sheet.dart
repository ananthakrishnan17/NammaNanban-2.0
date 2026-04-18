import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../products/domain/entities/product.dart';
import '../../../users/domain/entities/product_uom.dart';
import '../../domain/entities/bill.dart';
import '../bloc/billing_bloc.dart';

/// Bottom sheet shown when a product with multiple UOMs is tapped in billing.
/// Displays the base-unit option plus all configured loose-sale UOMs.
class UomPickerSheet extends StatelessWidget {
  final Product product;
  final List<ProductUom> uoms;

  const UomPickerSheet({super.key, required this.product, required this.uoms});

  @override
  Widget build(BuildContext context) {
    final billType = context.read<BillingBloc>().state.billType;
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
          Container(
            width: 40.w, height: 4.h,
            decoration: BoxDecoration(
              color: AppTheme.divider,
              borderRadius: BorderRadius.circular(2.r),
            ),
          ),
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
                  color: isWholesale
                      ? AppTheme.secondary.withOpacity(0.12)
                      : AppTheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Text(
                  isWholesale ? '📦 Wholesale' : '🛒 Retail',
                  style: TextStyle(
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Poppins',
                    color: isWholesale ? AppTheme.secondary : AppTheme.primary,
                  ),
                ),
              ),
            ]),
          ),
          SizedBox(height: 12.h),
          const Divider(height: 1),
          // Base unit + UOM options list
          ListView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.all(14.w),
            children: [
              // Base unit option
              _buildTile(
                context: context,
                shortName: product.displayUnit,
                name: '${product.displayUnit} (Base unit)',
                conversionLabel: '1 ${product.unit}',
                price: isWholesale ? product.wholesalePrice : product.sellingPrice,
                isDefault: true,
                isWholesale: isWholesale,
                onTap: () {
                  Navigator.pop(context);
                  context.read<BillingBloc>().add(AddToCart(CartItem(
                    productId: product.id!,
                    productName: product.name,
                    unit: product.displayUnit,
                    sellingPrice: product.sellingPrice,
                    wholesalePrice: product.wholesalePrice,
                    purchasePrice: product.purchasePrice,
                    gstRate: product.gstRate,
                    gstInclusive: product.gstInclusive,
                    rateType: product.rateType,
                    quantity: 1,
                    conversionQty: 1.0,
                  )));
                },
              ),
              SizedBox(height: 8.h),
              // Loose sale UOM options
              ...uoms.map((uom) {
                final price = isWholesale && uom.wholesalePrice > 0
                    ? uom.wholesalePrice
                    : uom.sellingPrice;
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildTile(
                      context: context,
                      shortName: uom.uomShortName,
                      name: uom.uomName,
                      conversionLabel: '${uom.conversionQty} ${product.unit} · Loose sale',
                      price: price,
                      isDefault: uom.isDefault,
                      isWholesale: isWholesale,
                      onTap: () {
                        Navigator.pop(context);
                        context.read<BillingBloc>().add(AddToCart(CartItem(
                          productId: product.id!,
                          productName: product.name,
                          unit: uom.uomShortName,
                          sellingPrice: uom.sellingPrice,
                          wholesalePrice: uom.wholesalePrice,
                          purchasePrice: uom.purchasePrice,
                          gstRate: product.gstRate,
                          gstInclusive: product.gstInclusive,
                          rateType: product.rateType,
                          quantity: 1,
                          saleUomId: uom.id,
                          saleUomShortName: uom.uomShortName,
                          conversionQty: uom.conversionQty,
                        )));
                      },
                    ),
                    SizedBox(height: 8.h),
                  ],
                );
              }),
            ],
          ),
          SizedBox(height: 8.h),
        ],
      ),
    );
  }

  Widget _buildTile({
    required BuildContext context,
    required String shortName,
    required String name,
    required String conversionLabel,
    required double price,
    required bool isDefault,
    required bool isWholesale,
    required VoidCallback onTap,
  }) {
    final tileColor = isWholesale ? AppTheme.secondary : AppTheme.primary;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(14.w),
        decoration: BoxDecoration(
          color: isDefault ? tileColor.withOpacity(0.06) : Colors.white,
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(
            color: isDefault ? tileColor.withOpacity(0.3) : AppTheme.divider,
            width: isDefault ? 1.5 : 1,
          ),
        ),
        child: Row(children: [
          Container(
            width: 44.w, height: 44.h,
            decoration: BoxDecoration(
              color: tileColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10.r),
            ),
            child: Center(
              child: Text(
                shortName,
                style: TextStyle(
                  fontSize: shortName.length > 3 ? 10.sp : 14.sp,
                  fontWeight: FontWeight.w700,
                  color: tileColor,
                  fontFamily: 'Poppins',
                ),
              ),
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name, style: AppTheme.heading3),
            Text(conversionLabel, style: AppTheme.caption),
          ])),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(
              CurrencyFormatter.format(price),
              style: TextStyle(
                fontSize: 18.sp,
                fontWeight: FontWeight.w700,
                fontFamily: 'Poppins',
                color: tileColor,
              ),
            ),
            Text('per $shortName', style: AppTheme.caption),
          ]),
        ]),
      ),
    );
  }
}
