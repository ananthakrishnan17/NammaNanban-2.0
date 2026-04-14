import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../products/presentation/bloc/product_bloc.dart';
import '../../../printer/services/printer_service.dart';
import '../bloc/billing_bloc.dart';
import '../../domain/entities/bill.dart';

class PaymentBottomSheet extends StatefulWidget {
  final CartState cart;
  const PaymentBottomSheet({super.key, required this.cart});

  @override
  State<PaymentBottomSheet> createState() => _PaymentBottomSheetState();
}

class _PaymentBottomSheetState extends State<PaymentBottomSheet> {
  String _selectedMode = 'cash';
  double _cashGiven = 0;
  bool _printBill = true;
  bool _isSaving = false;

  final List<Map<String, String>> _paymentModes = [
    {'mode': 'cash', 'label': 'Cash', 'icon': '💵'},
    {'mode': 'upi', 'label': 'UPI', 'icon': '📱'},
    {'mode': 'card', 'label': 'Card', 'icon': '💳'},
  ];

  @override
  void initState() {
    super.initState();
    _cashGiven = widget.cart.totalAmount;
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.cart.totalAmount;
    final change = _cashGiven - total;

    return BlocListener<BillingBloc, CartState>(
      listener: (context, state) {
        final cart = state as CartState;
        if (cart.lastSavedBill != null && !_isSaving) {
          Navigator.pop(context);
          if (_printBill) {
            PrinterService.instance.printBill(cart.lastSavedBill!);
          }
          _showSuccessDialog(context, cart.lastSavedBill!);
        }
      },
      child: Container(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
        ),
        child: SingleChildScrollView(
          padding: EdgeInsets.all(20.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40.w, height: 4.h,
                  decoration: BoxDecoration(
                    color: AppTheme.divider,
                    borderRadius: BorderRadius.circular(2.r),
                  ),
                ),
              ),
              SizedBox(height: 16.h),

              Text('Complete Payment', style: AppTheme.heading2),
              SizedBox(height: 4.h),
              Text('${widget.cart.items.length} items', style: AppTheme.caption),
              SizedBox(height: 20.h),

              // Total Amount
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(16.w),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(14.r),
                ),
                child: Column(
                  children: [
                    Text('Total Amount', style: AppTheme.caption),
                    SizedBox(height: 4.h),
                    Text(
                      CurrencyFormatter.format(total),
                      style: TextStyle(
                        fontSize: 32.sp,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primary,
                        fontFamily: 'Poppins',
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 20.h),

              // Payment Mode
              Text('Payment Mode', style: AppTheme.heading3),
              SizedBox(height: 10.h),
              Row(
                children: _paymentModes.map((mode) {
                  final isSelected = _selectedMode == mode['mode'];
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedMode = mode['mode']!),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: EdgeInsets.only(right: 8.w),
                        padding: EdgeInsets.symmetric(vertical: 12.h),
                        decoration: BoxDecoration(
                          color: isSelected ? AppTheme.primary : AppTheme.surface,
                          borderRadius: BorderRadius.circular(12.r),
                          border: Border.all(
                            color: isSelected ? AppTheme.primary : AppTheme.divider,
                          ),
                        ),
                        child: Column(
                          children: [
                            Text(mode['icon']!, style: TextStyle(fontSize: 20.sp)),
                            SizedBox(height: 4.h),
                            Text(
                              mode['label']!,
                              style: TextStyle(
                                fontSize: 12.sp,
                                fontWeight: FontWeight.w600,
                                color: isSelected ? Colors.white : AppTheme.textPrimary,
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
              SizedBox(height: 16.h),

              // Cash given and change (only for cash)
              if (_selectedMode == 'cash') ...[
                Text('Cash Given', style: AppTheme.heading3),
                SizedBox(height: 8.h),
                // Quick cash buttons
                Wrap(
                  spacing: 8.w,
                  children: [10, 20, 50, 100, 200, 500].map((amount) {
                    return ActionChip(
                      label: Text('₹$amount'),
                      onPressed: () => setState(() => _cashGiven = amount.toDouble()),
                      backgroundColor: _cashGiven == amount.toDouble()
                          ? AppTheme.primary.withOpacity(0.15)
                          : AppTheme.surface,
                    );
                  }).toList(),
                ),
                SizedBox(height: 8.h),
                TextField(
                  keyboardType: TextInputType.number,
                  onChanged: (v) => setState(() => _cashGiven = double.tryParse(v) ?? 0),
                  decoration: const InputDecoration(
                    hintText: 'Enter cash amount',
                    prefixText: '₹ ',
                  ),
                  controller: TextEditingController(text: _cashGiven.toStringAsFixed(0)),
                ),
                if (_cashGiven >= total) ...[
                  SizedBox(height: 12.h),
                  Container(
                    padding: EdgeInsets.all(12.w),
                    decoration: BoxDecoration(
                      color: AppTheme.accent.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10.r),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Change to Return', style: AppTheme.body),
                        Text(
                          CurrencyFormatter.format(change),
                          style: TextStyle(
                            fontSize: 18.sp,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.accent,
                            fontFamily: 'Poppins',
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                SizedBox(height: 16.h),
              ],

              // Print option
              Row(
                children: [
                  Checkbox(
                    value: _printBill,
                    onChanged: (v) => setState(() => _printBill = v ?? true),
                    activeColor: AppTheme.primary,
                  ),
                  Text('Print Bill', style: AppTheme.body),
                  SizedBox(width: 8.w),
                  Icon(Icons.print, size: 16.sp, color: AppTheme.textSecondary),
                ],
              ),
              SizedBox(height: 16.h),

              // Confirm Button
              ElevatedButton(
                onPressed: _isSaving ? null : _confirmPayment,
                child: _isSaving
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text('Confirm Payment - ${CurrencyFormatter.format(total)}'),
              ),
              SizedBox(height: 8.h),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmPayment() {
    setState(() => _isSaving = true);
    context.read<BillingBloc>().add(SetPaymentMode(_selectedMode));
    context.read<BillingBloc>().add(
      SaveBill(),
    );
  }

  void _showSuccessDialog(BuildContext context, Bill bill) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, color: AppTheme.accent, size: 60),
            SizedBox(height: 12.h),
            Text('Payment Successful!', style: AppTheme.heading2),
            SizedBox(height: 4.h),
            Text('Bill #${bill.billNumber}', style: AppTheme.caption),
            SizedBox(height: 8.h),
            Text(
              CurrencyFormatter.format(bill.totalAmount),
              style: AppTheme.price.copyWith(fontSize: 24.sp),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Done')),
        ],
      ),
    );
  }
}
