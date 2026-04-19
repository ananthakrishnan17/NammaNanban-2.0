import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/database/database_helper.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../printer/services/printer_service.dart';
import '../../data/repositories/billing_repository_impl.dart';
import '../../domain/entities/bill.dart';

class BillViewScreen extends StatefulWidget {
  final Bill bill;
  final bool isAdmin;
  const BillViewScreen({super.key, required this.bill, this.isAdmin = false});

  @override
  State<BillViewScreen> createState() => _BillViewScreenState();
}

class _BillViewScreenState extends State<BillViewScreen> {
  String _shopName = '';
  String _shopPhone = '';
  String? _logoPath;
  bool _logoExists = false;
  late final BillingRepositoryImpl _billingRepo;

  @override
  void initState() {
    super.initState();
    _billingRepo = BillingRepositoryImpl(DatabaseHelper.instance);
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      final logoPath = prefs.getString('logo_path');
      setState(() {
        _shopName = prefs.getString('shop_name') ?? 'My Shop';
        _shopPhone = prefs.getString('shop_phone') ?? '';
        _logoPath = logoPath;
        _logoExists = logoPath != null && logoPath.isNotEmpty && File(logoPath).existsSync();
      });
    }
  }

  Future<void> _onPrint() async {
    final printed = await PrinterService.instance.printBill(widget.bill);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(printed ? '✅ Printed successfully!' : '⚠️ Printer not connected'),
      backgroundColor: printed ? AppTheme.accent : AppTheme.warning,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 3),
      margin: EdgeInsets.only(bottom: 24.h, left: 16.w, right: 16.w),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
    ));
  }

  Future<void> _onDelete() async {
    final bill = widget.bill;
    if (bill.id == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Bill?'),
        content: Text('Are you sure you want to delete Bill #${bill.billNumber}? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger, foregroundColor: Colors.white),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _billingRepo.deleteBill(bill.id!);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Bill #${bill.billNumber} deleted'),
        backgroundColor: AppTheme.danger,
        behavior: SnackBarBehavior.floating,
      ));
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete: $e'), backgroundColor: AppTheme.danger));
    }
  }

  @override
  Widget build(BuildContext context) {
    final bill = widget.bill;
    final dateStr = DateFormat('dd MMM yyyy, hh:mm a').format(bill.createdAt);
    final billTypeLabel = bill.billType == 'wholesale' ? 'Wholesale' : 'Retail';
    final subtotal = bill.items.fold(0.0, (s, i) => s + i.totalPrice);
    final hasDiscount = bill.discountAmount > 0;
    final hasTax = bill.gstTotal > 0;

    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        title: Text('Bill #${bill.billNumber}'),
        actions: [
          if (widget.isAdmin)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              tooltip: 'Delete Bill',
              onPressed: _onDelete,
            ),
          IconButton(
            icon: const Text('🖨️', style: TextStyle(fontSize: 22)),
            tooltip: 'Print',
            onPressed: _onPrint,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(16.w),
              child: Column(
                children: [
                  _buildReceiptCard(bill, dateStr, billTypeLabel, subtotal, hasDiscount, hasTax),
                ],
              ),
            ),
          ),
          _buildBottomActions(),
        ],
      ),
    );
  }

  Widget _buildReceiptCard(Bill bill, String dateStr, String billTypeLabel,
      double subtotal, bool hasDiscount, bool hasTax) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: AppTheme.divider),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // ── Shop Header ──────────────────────────────────────────────────
          if (_logoExists) ...[
            CircleAvatar(
              backgroundImage: FileImage(File(_logoPath!)),
              radius: 36.r,
            ),
            SizedBox(height: 8.h),
          ],
          Text(
            _shopName,
            style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w700, fontFamily: 'Poppins', color: AppTheme.textPrimary),
            textAlign: TextAlign.center,
          ),
          if (_shopPhone.isNotEmpty) ...[
            SizedBox(height: 2.h),
            Text(
              'Ph: $_shopPhone',
              style: AppTheme.caption,
              textAlign: TextAlign.center,
            ),
          ],

          SizedBox(height: 12.h),
          Divider(color: AppTheme.divider, height: 1),
          SizedBox(height: 12.h),

          // ── Bill Meta ────────────────────────────────────────────────────
          Row(children: [
            Expanded(child: _metaItem('Bill No', '#${bill.billNumber}')),
            Expanded(child: _metaItem('Type', billTypeLabel, align: TextAlign.center)),
            Expanded(child: _metaItem('Date', dateStr, align: TextAlign.right)),
          ]),

          if (bill.customerName != null && bill.customerName!.isNotEmpty) ...[
            SizedBox(height: 8.h),
            Align(
              alignment: Alignment.centerLeft,
              child: RichText(
                text: TextSpan(
                  style: AppTheme.body,
                  children: [
                    TextSpan(text: 'Customer: ', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13.sp)),
                    TextSpan(
                      text: bill.customerName!,
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.sp, color: AppTheme.textPrimary),
                    ),
                  ],
                ),
              ),
            ),
          ],

          SizedBox(height: 12.h),
          Divider(color: AppTheme.divider, height: 1),
          SizedBox(height: 8.h),

          // ── Items Table Header ───────────────────────────────────────────
          _tableHeader(),
          Divider(color: AppTheme.divider, height: 8),

          // ── Items ────────────────────────────────────────────────────────
          ...bill.items.map((item) => _itemRow(item)),

          SizedBox(height: 8.h),
          Divider(color: AppTheme.divider, height: 1),
          SizedBox(height: 8.h),

          // ── Totals ───────────────────────────────────────────────────────
          _totalRow('Subtotal', subtotal),
          if (hasDiscount) ...[
            SizedBox(height: 4.h),
            _totalRow('Discount', -bill.discountAmount, isNegative: true),
          ],
          if (hasTax) ...[
            SizedBox(height: 4.h),
            _totalRow('Tax (GST)', bill.gstTotal),
          ],
          SizedBox(height: 8.h),
          Divider(color: AppTheme.divider, height: 1),
          SizedBox(height: 6.h),
          _totalRow('Total', bill.totalAmount, isBold: true, isLarge: true),

          SizedBox(height: 12.h),
          Divider(color: AppTheme.divider, height: 1),
          SizedBox(height: 8.h),

          // ── Payment ──────────────────────────────────────────────────────
          _buildPaymentInfo(bill),
        ],
      ),
    );
  }

  Widget _buildPaymentInfo(Bill bill) {
    final hasSplit = bill.splitPaymentSummary != null && bill.splitPaymentSummary!.isNotEmpty;
    return Align(
      alignment: Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Payment', style: AppTheme.caption),
          SizedBox(height: 4.h),
          if (hasSplit)
            Text(
              bill.splitPaymentSummary!,
              style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
            )
          else
            Text(
              bill.paymentMode.toUpperCase(),
              style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w600, color: AppTheme.primary),
            ),
        ],
      ),
    );
  }

  Widget _metaItem(String label, String value, {TextAlign align = TextAlign.left}) {
    return Column(
      crossAxisAlignment: align == TextAlign.right
          ? CrossAxisAlignment.end
          : align == TextAlign.center
              ? CrossAxisAlignment.center
              : CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTheme.caption),
        SizedBox(height: 2.h),
        Text(value, style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w600, color: AppTheme.textPrimary, fontFamily: 'Poppins'), textAlign: align),
      ],
    );
  }

  Widget _tableHeader() {
    return Row(
      children: [
        Expanded(flex: 4, child: Text('Item', style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w600, color: AppTheme.textSecondary))),
        SizedBox(
          width: 50.w,
          child: Text('Qty', style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w600, color: AppTheme.textSecondary), textAlign: TextAlign.center),
        ),
        SizedBox(
          width: 60.w,
          child: Text('Price', style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w600, color: AppTheme.textSecondary), textAlign: TextAlign.right),
        ),
        SizedBox(
          width: 64.w,
          child: Text('Total', style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w600, color: AppTheme.textSecondary), textAlign: TextAlign.right),
        ),
      ],
    );
  }

  Widget _itemRow(BillItem item) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4.h),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.productName, style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w500, color: AppTheme.textPrimary, fontFamily: 'Poppins')),
                Text(item.unit, style: AppTheme.caption),
              ],
            ),
          ),
          SizedBox(
            width: 50.w,
            child: Text(
              item.quantity % 1 == 0 ? item.quantity.toInt().toString() : item.quantity.toStringAsFixed(2),
              style: TextStyle(fontSize: 13.sp, color: AppTheme.textPrimary),
              textAlign: TextAlign.center,
            ),
          ),
          SizedBox(
            width: 60.w,
            child: Text(
              CurrencyFormatter.format(item.unitPrice),
              style: TextStyle(fontSize: 12.sp, color: AppTheme.textSecondary),
              textAlign: TextAlign.right,
            ),
          ),
          SizedBox(
            width: 64.w,
            child: Text(
              CurrencyFormatter.format(item.totalPrice),
              style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  Widget _totalRow(String label, double amount, {bool isBold = false, bool isLarge = false, bool isNegative = false}) {
    final style = TextStyle(
      fontSize: isLarge ? 15.sp : 13.sp,
      fontWeight: isBold ? FontWeight.w700 : FontWeight.w400,
      color: isNegative ? AppTheme.danger : (isBold ? AppTheme.primary : AppTheme.textPrimary),
      fontFamily: 'Poppins',
    );
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: style),
        Text(
          isNegative ? '- ${CurrencyFormatter.format(amount.abs())}' : CurrencyFormatter.format(amount),
          style: style,
        ),
      ],
    );
  }

  Widget _buildBottomActions() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppTheme.divider)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, -2))],
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _onPrint,
              icon: const Text('🖨️'),
              label: const Text('Print'),
              style: OutlinedButton.styleFrom(
                padding: EdgeInsets.symmetric(vertical: 12.h),
                side: BorderSide(color: AppTheme.primary),
                foregroundColor: AppTheme.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
              ),
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Text('✅'),
              label: const Text('New Bill'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accent,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 12.h),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
