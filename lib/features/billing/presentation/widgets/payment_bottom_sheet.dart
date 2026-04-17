import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../domain/entities/bill.dart';
import '../bloc/billing_bloc.dart';

class PaymentBottomSheet extends StatefulWidget {
  final CartState cart;
  const PaymentBottomSheet({super.key, required this.cart});

  @override
  State<PaymentBottomSheet> createState() => _PaymentBottomSheetState();
}

class _SplitEntry {
  String mode;
  final TextEditingController controller;
  _SplitEntry({required this.mode, String amount = ''})
      : controller = TextEditingController(text: amount);
  double get amount => double.tryParse(controller.text) ?? 0.0;
  void dispose() => controller.dispose();
}

class _PaymentBottomSheetState extends State<PaymentBottomSheet> {
  late String _selectedMode;
  bool _isSplitMode = false;
  final List<_SplitEntry> _splitEntries = [];
  final TextEditingController _discountController = TextEditingController();
  final TextEditingController _customerController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selectedMode = widget.cart.paymentMode;
    _discountController.text = widget.cart.discountAmount > 0
        ? widget.cart.discountAmount.toStringAsFixed(2)
        : '';
    _customerController.text = widget.cart.customerName ?? '';
    // Initialise split entries if cart already has splits
    if (widget.cart.splitPayments.isNotEmpty) {
      _isSplitMode = true;
      for (final sp in widget.cart.splitPayments) {
        _splitEntries.add(_SplitEntry(
          mode: sp.mode,
          amount: sp.amount % 1 == 0
              ? sp.amount.toInt().toString()
              : sp.amount.toStringAsFixed(2),
        ));
      }
    } else {
      _splitEntries.add(_SplitEntry(mode: PaymentMode.values.first.name));
      _splitEntries.add(_SplitEntry(mode: PaymentMode.cash.name));
    }
  }

  @override
  void dispose() {
    _discountController.dispose();
    _customerController.dispose();
    for (final e in _splitEntries) {
      e.dispose();
    }
    super.dispose();
  }

  double get _splitTotal =>
      _splitEntries.fold(0.0, (s, e) => s + e.amount);

  bool get _isSplitBalanced =>
      (_splitTotal - widget.cart.totalAmount).abs() <= 1.0;

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<BillingBloc, CartState>(
      // ✅ FIX: Close the sheet the moment save finishes (isSaving flips false + bill set)
      //         Without this the sheet stays open forever showing a spinner.
      listenWhen: (prev, curr) =>
      prev.isSaving == true &&
          curr.isSaving == false,
      listener: (context, state) {
        // Close sheet regardless of success/failure — errors shown by BillingScreen
        Navigator.of(context).pop();
      },
      builder: (context, state) {
        final cart = state as CartState;
        final isSaving = cart.isSaving;

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
          ),
          padding: EdgeInsets.only(
            left: 20.w,
            right: 20.w,
            top: 20.h,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24.h,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle bar
                Center(
                  child: Container(
                    width: 40.w,
                    height: 4.h,
                    decoration: BoxDecoration(
                      color: AppTheme.divider,
                      borderRadius: BorderRadius.circular(2.r),
                    ),
                  ),
                ),
                SizedBox(height: 16.h),

                Text('Confirm Payment', style: AppTheme.heading2),
                SizedBox(height: 4.h),
                Text(
                  cart.billType == BillType.retail
                      ? '🛒 Retail Bill'
                      : '📦 Wholesale Bill',
                  style:
                  AppTheme.caption.copyWith(color: AppTheme.textSecondary),
                ),
                SizedBox(height: 20.h),

                // ── Customer Name (optional) ────────────────────────────────
                Text('Customer Name (optional)', style: AppTheme.caption),
                SizedBox(height: 6.h),
                TextField(
                  controller: _customerController,
                  onChanged: (v) =>
                      context.read<BillingBloc>().add(SetCustomerName(v)),
                  decoration: InputDecoration(
                    hintText: 'Walk-in customer',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10.r)),
                    contentPadding: EdgeInsets.symmetric(
                        horizontal: 12.w, vertical: 10.h),
                    isDense: true,
                  ),
                ),
                SizedBox(height: 16.h),

                // ── Discount ───────────────────────────────────────────────
                Text('Discount Amount', style: AppTheme.caption),
                SizedBox(height: 6.h),
                TextField(
                  controller: _discountController,
                  keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (v) {
                    final d = double.tryParse(v) ?? 0.0;
                    context.read<BillingBloc>().add(ApplyDiscount(d));
                  },
                  decoration: InputDecoration(
                    hintText: '0.00',
                    prefixText: '₹ ',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10.r)),
                    contentPadding: EdgeInsets.symmetric(
                        horizontal: 12.w, vertical: 10.h),
                    isDense: true,
                  ),
                ),
                SizedBox(height: 16.h),

                // ── Payment Mode Toggle ────────────────────────────────────
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _isSplitMode = false),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: EdgeInsets.symmetric(vertical: 10.h),
                          decoration: BoxDecoration(
                            color: !_isSplitMode
                                ? AppTheme.primary
                                : AppTheme.surface,
                            borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(10.r),
                              bottomLeft: Radius.circular(10.r),
                            ),
                            border: Border.all(color: AppTheme.primary),
                          ),
                          child: Center(
                            child: Text(
                              'Single Payment',
                              style: TextStyle(
                                fontSize: 12.sp,
                                fontWeight: FontWeight.w600,
                                color: !_isSplitMode
                                    ? Colors.white
                                    : AppTheme.primary,
                                fontFamily: 'Poppins',
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _isSplitMode = true),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: EdgeInsets.symmetric(vertical: 10.h),
                          decoration: BoxDecoration(
                            color: _isSplitMode
                                ? AppTheme.primary
                                : AppTheme.surface,
                            borderRadius: BorderRadius.only(
                              topRight: Radius.circular(10.r),
                              bottomRight: Radius.circular(10.r),
                            ),
                            border: Border.all(color: AppTheme.primary),
                          ),
                          child: Center(
                            child: Text(
                              'Split Payment',
                              style: TextStyle(
                                fontSize: 12.sp,
                                fontWeight: FontWeight.w600,
                                color: _isSplitMode
                                    ? Colors.white
                                    : AppTheme.primary,
                                fontFamily: 'Poppins',
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12.h),

                if (!_isSplitMode) ...[
                  // ── Single Payment Mode ──────────────────────────────────
                  Text('Payment Mode', style: AppTheme.caption),
                  SizedBox(height: 8.h),
                  Row(
                    children: PaymentMode.values.map((mode) {
                      final isSelected = _selectedMode == mode.name;
                      return Expanded(
                        child: GestureDetector(
                          onTap: () {
                            setState(() => _selectedMode = mode.name);
                            context
                                .read<BillingBloc>()
                                .add(SetPaymentMode(mode.name));
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            margin: EdgeInsets.only(right: 6.w),
                            padding: EdgeInsets.symmetric(
                                vertical: 10.h, horizontal: 4.w),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppTheme.primary.withOpacity(0.12)
                                  : AppTheme.surface,
                              borderRadius: BorderRadius.circular(10.r),
                              border: Border.all(
                                color: isSelected
                                    ? AppTheme.primary
                                    : AppTheme.divider,
                                width: isSelected ? 1.5 : 1,
                              ),
                            ),
                            child: Column(
                              children: [
                                Text(mode.icon,
                                    style: TextStyle(fontSize: 18.sp)),
                                SizedBox(height: 3.h),
                                Text(
                                  mode.label,
                                  style: TextStyle(
                                    fontSize: 10.sp,
                                    fontWeight: isSelected
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                    color: isSelected
                                        ? AppTheme.primary
                                        : AppTheme.textSecondary,
                                    fontFamily: 'Poppins',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ] else ...[
                  // ── Split Payment Entries ────────────────────────────────
                  ...List.generate(_splitEntries.length, (i) {
                    final entry = _splitEntries[i];
                    return Padding(
                      padding: EdgeInsets.only(bottom: 10.h),
                      child: Row(
                        children: [
                          // Mode dropdown
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 8.w),
                            decoration: BoxDecoration(
                              border: Border.all(color: AppTheme.divider),
                              borderRadius: BorderRadius.circular(8.r),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: entry.mode,
                                isDense: true,
                                items: PaymentMode.values.map((m) {
                                  return DropdownMenuItem(
                                    value: m.name,
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(m.icon,
                                            style: TextStyle(fontSize: 14.sp)),
                                        SizedBox(width: 4.w),
                                        Text(m.label,
                                            style: TextStyle(
                                                fontSize: 12.sp,
                                                fontFamily: 'Poppins')),
                                      ],
                                    ),
                                  );
                                }).toList(),
                                onChanged: (v) {
                                  if (v != null) {
                                    setState(() => entry.mode = v);
                                  }
                                },
                              ),
                            ),
                          ),
                          SizedBox(width: 8.w),
                          // Amount field
                          Expanded(
                            child: TextField(
                              controller: entry.controller,
                              keyboardType: const TextInputType.numberWithOptions(
                                  decimal: true),
                              onChanged: (_) => setState(() {}),
                              decoration: InputDecoration(
                                hintText: '0.00',
                                prefixText: '₹ ',
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8.r)),
                                contentPadding: EdgeInsets.symmetric(
                                    horizontal: 10.w, vertical: 10.h),
                                isDense: true,
                              ),
                            ),
                          ),
                          SizedBox(width: 6.w),
                          // Delete button (only if more than one entry)
                          if (_splitEntries.length > 1)
                            GestureDetector(
                              onTap: () {
                                setState(() {
                                  _splitEntries[i].dispose();
                                  _splitEntries.removeAt(i);
                                });
                              },
                              child: Icon(Icons.delete_outline,
                                  color: AppTheme.danger, size: 22.sp),
                            )
                          else
                            SizedBox(width: 22.sp),
                        ],
                      ),
                    );
                  }),
                  // Add payment method button
                  TextButton.icon(
                    onPressed: () {
                      setState(() {
                        _splitEntries.add(
                            _SplitEntry(mode: PaymentMode.cash.name));
                      });
                    },
                    icon: const Icon(Icons.add_circle_outline),
                    label: const Text('Add Payment Method'),
                    style: TextButton.styleFrom(
                        foregroundColor: AppTheme.primary),
                  ),
                  SizedBox(height: 4.h),
                  // Remaining balance indicator
                  Builder(builder: (context) {
                    final remaining =
                        cart.totalAmount - _splitTotal;
                    final isBalanced = remaining.abs() <= 1.0;
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          isBalanced
                              ? '✅ Balanced'
                              : remaining > 0
                                  ? 'Remaining: ${CurrencyFormatter.format(remaining)}'
                                  : 'Excess: ${CurrencyFormatter.format(-remaining)}',
                          style: TextStyle(
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w600,
                            color: isBalanced
                                ? AppTheme.accent
                                : AppTheme.danger,
                            fontFamily: 'Poppins',
                          ),
                        ),
                        Text(
                          'Total: ${CurrencyFormatter.format(cart.totalAmount)}',
                          style: AppTheme.caption,
                        ),
                      ],
                    );
                  }),
                ],
                SizedBox(height: 20.h),

                // ── Total Summary ──────────────────────────────────────────
                Container(
                  padding: EdgeInsets.all(14.w),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(12.r),
                    border: Border.all(color: AppTheme.divider),
                  ),
                  child: Column(
                    children: [
                      _summaryRow('Subtotal',
                          CurrencyFormatter.format(cart.subtotal)),
                      if (cart.gstTotal > 0) ...[
                        SizedBox(height: 4.h),
                        _summaryRow(
                            'GST', CurrencyFormatter.format(cart.gstTotal)),
                      ],
                      if (cart.discountAmount > 0) ...[
                        SizedBox(height: 4.h),
                        _summaryRow(
                          'Discount',
                          '-${CurrencyFormatter.format(cart.discountAmount)}',
                          valueColor: AppTheme.accent,
                        ),
                      ],
                      Divider(height: 14.h, color: AppTheme.divider),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Total Payable', style: AppTheme.heading3),
                          Text(
                            CurrencyFormatter.format(cart.totalAmount),
                            style: AppTheme.price,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 20.h),

                // ── Confirm Button ─────────────────────────────────────────
                SizedBox(
                  width: double.infinity,
                  height: 52.h,
                  child: ElevatedButton(
                    // ✅ Disable while saving or split not balanced
                    onPressed: isSaving || (_isSplitMode && !_isSplitBalanced)
                        ? null
                        : () {
                      if (_isSplitMode) {
                        final splits = _splitEntries
                            .map((e) =>
                                SplitPayment(mode: e.mode, amount: e.amount))
                            .toList();
                        context
                            .read<BillingBloc>()
                            .add(SetSplitPayments(splits));
                      } else {
                        // Clear any previous split payments when using single mode
                        context
                            .read<BillingBloc>()
                            .add(SetSplitPayments(const []));
                      }
                      context.read<BillingBloc>().add(SaveBill());
                    },
                    style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14.r)),
                    ),
                    child: isSaving
                        ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 20.w,
                          height: 20.h,
                          child: const CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        ),
                        SizedBox(width: 10.w),
                        Text(
                          'Saving...',
                          style: TextStyle(
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                              fontFamily: 'Poppins'),
                        ),
                      ],
                    )
                        : Text(
                      'Confirm & Pay ${CurrencyFormatter.format(cart.totalAmount)}',
                      style: TextStyle(
                          fontSize: 15.sp,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'Poppins'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _summaryRow(String label, String value, {Color? valueColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: AppTheme.body.copyWith(color: AppTheme.textSecondary)),
        Text(value,
            style: AppTheme.body.copyWith(color: valueColor)),
      ],
    );
  }
}