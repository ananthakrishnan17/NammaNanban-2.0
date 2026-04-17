import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../domain/entities/bill.dart';
import '../bloc/billing_bloc.dart';
import 'held_bills_page.dart';

/// Split Bill Page — lets the user divide the current cart into two bills.
/// Bill 1 is loaded back into the main cart for normal payment.
/// Bill 2 is saved as a held bill so the user can process it separately.
class SplitBillPage extends StatefulWidget {
  final CartState cart;
  const SplitBillPage({super.key, required this.cart});

  @override
  State<SplitBillPage> createState() => _SplitBillPageState();
}

class _SplitBillPageState extends State<SplitBillPage> {
  // productIds of items assigned to Bill 2 (everything else stays in Bill 1)
  final Set<int> _bill2Ids = {};

  List<CartItem> get _bill1Items =>
      widget.cart.items.where((i) => !_bill2Ids.contains(i.productId)).toList();

  List<CartItem> get _bill2Items =>
      widget.cart.items.where((i) => _bill2Ids.contains(i.productId)).toList();

  double _total(List<CartItem> items) =>
      items.fold(0.0, (s, i) => s + i.totalFor(widget.cart.billType));

  void _toggleItem(int productId) {
    setState(() {
      if (_bill2Ids.contains(productId)) {
        _bill2Ids.remove(productId);
      } else {
        _bill2Ids.add(productId);
      }
    });
  }

  void _confirmSplit(BuildContext context) {
    final bill1 = _bill1Items;
    final bill2 = _bill2Items;

    if (bill1.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Bill 1 cannot be empty. Move some items back to Bill 1.'),
      ));
      return;
    }

    if (bill2.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Bill 2 is empty. Tap items to assign them to Bill 2.'),
      ));
      return;
    }

    // Save Bill 2 as a held bill.
    // Note: discounts are intentionally reset to 0 for each split bill.
    // The cashier can re-apply a discount when processing each bill separately.
    final bill2CartState = CartState(
      items: bill2,
      billType: widget.cart.billType,
      customerName: widget.cart.customerName,
      discountAmount: 0,
      paymentMode: widget.cart.paymentMode,
    );
    context.read<HeldBillBloc>().add(
          HoldCurrentBill(bill2CartState, holdName: '🔀 Split — Bill 2'),
        );

    // Load Bill 1 into main cart (discount reset; cashier re-applies if needed)
    context.read<BillingBloc>().add(RestoreHeldCartItems(
          items: bill1,
          billType: widget.cart.billType.value,
          customerName: widget.cart.customerName,
          discountAmount: 0,
        ));

    // Capture messenger before popping to safely show snackbar on parent screen
    final messenger = ScaffoldMessenger.of(context);
    Navigator.pop(context);

    messenger.showSnackBar(SnackBar(
      content: const Text('✅ Bill 1 ready to pay. Bill 2 saved to held bills.'),
      backgroundColor: AppTheme.accent,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 3),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final bill1 = _bill1Items;
    final bill2 = _bill2Items;
    final canConfirm = bill1.isNotEmpty && bill2.isNotEmpty;

    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        title: const Text('Split Bill'),
        backgroundColor: Colors.white,
        actions: [
          TextButton(
            onPressed: canConfirm ? () => _confirmSplit(context) : null,
            child: Text(
              'Confirm',
              style: TextStyle(
                color: canConfirm ? AppTheme.primary : AppTheme.textSecondary,
                fontWeight: FontWeight.w700,
                fontSize: 15.sp,
                fontFamily: 'Poppins',
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Instruction banner
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
            color: AppTheme.primary.withOpacity(0.06),
            child: Text(
              '💡 Tap an item to move it between Bill 1 and Bill 2. '
              'Bill 2 will be saved to held bills.',
              style: AppTheme.caption,
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.all(12.w),
              children: [
                _buildBillSection(
                  label: '📋 Bill 1',
                  items: bill1,
                  color: AppTheme.primary,
                  moveLabel: '→ B2',
                  moveColor: AppTheme.accent,
                  emptyText: 'All items moved to Bill 2.',
                ),
                SizedBox(height: 12.h),
                _buildBillSection(
                  label: '📋 Bill 2',
                  items: bill2,
                  color: AppTheme.accent,
                  moveLabel: '← B1',
                  moveColor: AppTheme.warning,
                  emptyText: 'Tap Bill 1 items to move them here.',
                ),
              ],
            ),
          ),
          _buildBottomBar(context, bill1, bill2, canConfirm),
        ],
      ),
    );
  }

  Widget _buildBillSection({
    required String label,
    required List<CartItem> items,
    required Color color,
    required String moveLabel,
    required Color moveColor,
    required String emptyText,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: color.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(12.w, 12.h, 12.w, 8.h),
            child: Row(
              children: [
                Container(
                  padding:
                      EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w700,
                      color: color,
                      fontFamily: 'Poppins',
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  '${items.length} item${items.length == 1 ? '' : 's'}',
                  style: AppTheme.caption,
                ),
                SizedBox(width: 8.w),
                Text(
                  CurrencyFormatter.format(_total(items)),
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w700,
                    color: color,
                    fontFamily: 'Poppins',
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: color.withOpacity(0.15)),
          if (items.isEmpty)
            Padding(
              padding: EdgeInsets.all(16.w),
              child: Center(
                child: Text(
                  emptyText,
                  style: AppTheme.caption,
                  textAlign: TextAlign.center,
                ),
              ),
            )
          else
            ...items.map((item) => _buildItemTile(item, moveLabel, moveColor)),
        ],
      ),
    );
  }

  Widget _buildItemTile(CartItem item, String moveLabel, Color moveColor) {
    final price = item.effectivePrice(widget.cart.billType);
    final total = item.totalFor(widget.cart.billType);
    final qty = item.quantity % 1 == 0
        ? item.quantity.toInt().toString()
        : item.quantity.toStringAsFixed(1);

    return InkWell(
      onTap: () => _toggleItem(item.productId),
      borderRadius: BorderRadius.zero,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.productName,
                      style: AppTheme.body,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  SizedBox(height: 2.h),
                  Text(
                    '$qty ${item.unit}  ×  ${CurrencyFormatter.format(price)}',
                    style: AppTheme.caption,
                  ),
                ],
              ),
            ),
            Text(
              CurrencyFormatter.format(total),
              style: TextStyle(
                fontSize: 14.sp,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
                fontFamily: 'Poppins',
              ),
            ),
            SizedBox(width: 8.w),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
              decoration: BoxDecoration(
                color: moveColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6.r),
                border: Border.all(color: moveColor.withOpacity(0.3)),
              ),
              child: Text(
                moveLabel,
                style: TextStyle(
                  fontSize: 10.sp,
                  fontWeight: FontWeight.w700,
                  color: moveColor,
                  fontFamily: 'Poppins',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar(
    BuildContext context,
    List<CartItem> bill1,
    List<CartItem> bill2,
    bool canConfirm,
  ) {
    return Container(
      padding: EdgeInsets.fromLTRB(16.w, 14.h, 16.w, 28.h),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Summary row
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Bill 1',
                        style:
                            AppTheme.caption.copyWith(color: AppTheme.primary)),
                    Text(
                      '${bill1.length} items · ${CurrencyFormatter.format(_total(bill1))}',
                      style: TextStyle(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primary,
                        fontFamily: 'Poppins',
                      ),
                    ),
                  ],
                ),
              ),
              Container(width: 1, height: 32.h, color: AppTheme.divider),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(left: 16.w),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Bill 2',
                          style: AppTheme.caption
                              .copyWith(color: AppTheme.accent)),
                      Text(
                        '${bill2.length} items · ${CurrencyFormatter.format(_total(bill2))}',
                        style: TextStyle(
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.accent,
                          fontFamily: 'Poppins',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          ElevatedButton(
            onPressed: canConfirm ? () => _confirmSplit(context) : null,
            style: ElevatedButton.styleFrom(
              minimumSize: Size(double.infinity, 48.h),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.r)),
            ),
            child: Text(
              canConfirm
                  ? '✅ Confirm Split — Process Bill 1 First'
                  : 'Tap items to assign to Bill 2',
              style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
