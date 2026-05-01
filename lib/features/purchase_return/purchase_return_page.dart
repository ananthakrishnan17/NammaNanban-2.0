import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';

import '../../../core/database/database_helper.dart';
import '../../../core/ledger/ledger_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/currency_formatter.dart';


/// Purchase Return page.
///
/// Lets the user select a purchase by number, choose items/quantities
/// to return, and records a purchase return (restores payable, reduces stock).
/// Uses [erp_transactions] type='purchase_return'.
class PurchaseReturnPage extends StatefulWidget {
  const PurchaseReturnPage({super.key});

  @override
  State<PurchaseReturnPage> createState() => _PurchaseReturnPageState();
}

class _PurchaseReturnPageState extends State<PurchaseReturnPage> {
  final _purchaseNumberCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  List<Map<String, dynamic>> _purchaseItems = [];
  Map<String, dynamic>? _purchase;
  Map<int, double> _returnQty = {};
  bool _isSearching = false;
  bool _isSaving = false;
  String? _error;

  double get _returnTotal => _purchaseItems.fold(0.0, (s, item) {
        final idx = _purchaseItems.indexOf(item);
        final qty = _returnQty[idx] ?? 0;
        final unitCost = (item['unit_cost'] as num?)?.toDouble() ?? 0;
        return s + qty * unitCost;
      });

  Future<void> _searchPurchase() async {
    final num = _purchaseNumberCtrl.text.trim();
    if (num.isEmpty) return;
    setState(() { _isSearching = true; _error = null; _purchase = null; _purchaseItems = []; _returnQty = {}; });
    try {
      final db = await DatabaseHelper.instance.database;
      final rows = await db.query('purchases', where: "purchase_number = ?", whereArgs: [num]);
      if (rows.isEmpty) {
        setState(() => _error = 'Purchase "$num" not found');
        return;
      }
      final p = rows.first;
      final items = await db.query('purchase_items', where: 'purchase_id = ?', whereArgs: [p['id']]);
      setState(() {
        _purchase = p;
        _purchaseItems = items;
        _returnQty = {for (var i = 0; i < items.length; i++) i: 0.0};
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _isSearching = false);
    }
  }

  Future<void> _saveReturn() async {
    if (_returnTotal <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Select at least one item to return'),
          backgroundColor: Colors.red));
      return;
    }
    setState(() => _isSaving = true);
    try {
      final db = await DatabaseHelper.instance.database;
      final now = DateTime.now().toIso8601String();
      final returnNumber = 'PRET-${DateTime.now().millisecondsSinceEpoch}';

      await db.transaction((txn) async {
        // Deduct stock for returned items
        for (var i = 0; i < _purchaseItems.length; i++) {
          final qty = _returnQty[i] ?? 0;
          if (qty > 0) {
            await txn.rawUpdate(
              'UPDATE products SET stock_quantity = stock_quantity - ?, updated_at = ? WHERE id = ?',
              [qty, now, _purchaseItems[i]['product_id']],
            );
          }
        }
      });

      // Write double-entry ledger
      final licenseId = await LedgerService.resolveLicenseId(DatabaseHelper.instance);
      await db.transaction((txn) async {
        await LedgerService.instance.recordPurchaseReturn(
          txn: txn,
          returnAmount: _returnTotal,
          licenseId: licenseId,
          tags: {
            'return_number': returnNumber,
            'original_purchase_number': _purchase!['purchase_number'],
            'supplier_name': _purchase!['supplier_name'],
            'notes': _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
          },
        );
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('✅ Purchase return $returnNumber saved!'),
          backgroundColor: AppTheme.accent,
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.only(bottom: 24.h, left: 16.w, right: 16.w),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
        ));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    } finally {
      setState(() => _isSaving = false);
    }
  }

  @override
  void dispose() {
    _purchaseNumberCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(title: const Text('Purchase Return')),
      body: Column(children: [
        // Search bar
        Container(
          color: Colors.white,
          padding: EdgeInsets.all(16.w),
          child: Row(children: [
            Expanded(
              child: TextField(
                controller: _purchaseNumberCtrl,
                decoration: InputDecoration(
                  labelText: 'Purchase Number',
                  hintText: 'e.g. PUR-20241201-001',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10.r)),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
                ),
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _searchPurchase(),
              ),
            ),
            SizedBox(width: 8.w),
            ElevatedButton(
              onPressed: _isSearching ? null : _searchPurchase,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
              ),
              child: _isSearching
                  ? const SizedBox(width: 20, height: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Find', style: TextStyle(color: Colors.white)),
            ),
          ]),
        ),

        if (_error != null)
          Container(
            color: AppTheme.danger.withOpacity(0.08),
            padding: EdgeInsets.all(12.w),
            child: Row(children: [
              Icon(Icons.error_outline, color: AppTheme.danger, size: 18.sp),
              SizedBox(width: 8.w),
              Expanded(child: Text(_error!, style: AppTheme.caption.copyWith(color: AppTheme.danger))),
            ]),
          ),

        if (_purchase != null) ...[
          Container(
            color: AppTheme.primary.withOpacity(0.06),
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
            child: Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${_purchase!['purchase_number']}',
                    style: AppTheme.body.copyWith(fontWeight: FontWeight.w700)),
                Text(
                  '${_purchase!['supplier_name'] ?? 'No Supplier'}  •  '
                  '${DateFormat('dd MMM yyyy').format(DateTime.parse(_purchase!['purchase_date'] as String))}',
                  style: AppTheme.caption,
                ),
              ])),
              Text(CurrencyFormatter.format((_purchase!['total_amount'] as num).toDouble()),
                  style: AppTheme.price),
            ]),
          ),
        ],

        Expanded(
          child: _purchaseItems.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.assignment_return, size: 48.sp, color: AppTheme.textSecondary),
                      SizedBox(height: 10.h),
                      Text('Enter a purchase number to start', style: AppTheme.caption),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: EdgeInsets.all(16.w),
                  itemCount: _purchaseItems.length,
                  separatorBuilder: (_, __) => SizedBox(height: 10.h),
                  itemBuilder: (_, i) {
                    final item = _purchaseItems[i];
                    final maxQty = (item['quantity'] as num).toDouble();
                    final returnQty = _returnQty[i] ?? 0;
                    return Container(
                      padding: EdgeInsets.all(12.w),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12.r),
                        border: Border.all(
                            color: returnQty > 0 ? AppTheme.danger.withOpacity(0.4) : AppTheme.divider),
                      ),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          Expanded(child: Text(item['product_name'] as String,
                              style: AppTheme.body.copyWith(fontWeight: FontWeight.w600))),
                          Text(
                            '${item['unit']} × ${CurrencyFormatter.format((item['unit_cost'] as num).toDouble())}',
                            style: AppTheme.caption,
                          ),
                        ]),
                        Text('Purchased: $maxQty', style: AppTheme.caption),
                        SizedBox(height: 8.h),
                        Row(children: [
                          Text('Return qty: ', style: AppTheme.caption),
                          SizedBox(width: 8.w),
                          SizedBox(
                            width: 80.w,
                            child: TextFormField(
                              initialValue: returnQty > 0 ? returnQty.toString() : '',
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: InputDecoration(
                                isDense: true,
                                contentPadding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 8.h),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.r)),
                              ),
                              onChanged: (v) {
                                final parsed = double.tryParse(v) ?? 0;
                                setState(() => _returnQty[i] = parsed.clamp(0, maxQty));
                              },
                            ),
                          ),
                          SizedBox(width: 8.w),
                          Text('/ $maxQty ${item['unit']}', style: AppTheme.caption),
                          const Spacer(),
                          if (returnQty > 0)
                            Text(
                              CurrencyFormatter.format(returnQty * (item['unit_cost'] as num).toDouble()),
                              style: AppTheme.body.copyWith(
                                  color: AppTheme.danger, fontWeight: FontWeight.w700),
                            ),
                        ]),
                      ]),
                    );
                  },
                ),
        ),

        if (_purchaseItems.isNotEmpty)
          Container(
            padding: EdgeInsets.all(16.w),
            color: Colors.white,
            child: Column(children: [
              TextField(
                controller: _notesCtrl,
                maxLines: 1,
                decoration: InputDecoration(
                  labelText: 'Notes (optional)',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10.r)),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
                ),
              ),
              SizedBox(height: 10.h),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('Return Total', style: AppTheme.heading3),
                Text(CurrencyFormatter.format(_returnTotal),
                    style: AppTheme.price.copyWith(color: AppTheme.danger)),
              ]),
              SizedBox(height: 10.h),
              SizedBox(
                width: double.infinity,
                height: 48.h,
                child: ElevatedButton(
                  onPressed: (_isSaving || _returnTotal <= 0) ? null : _saveReturn,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.danger,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                  ),
                  child: _isSaving
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text('Confirm Return — ${CurrencyFormatter.format(_returnTotal)}',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                ),
              ),
            ]),
          ),
      ]),
    );
  }
}
