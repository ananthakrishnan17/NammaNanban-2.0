import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import '../../../../core/database/database_helper.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../billing/domain/entities/bill.dart';

// ─── Sale Return Entity ────────────────────────────────────────────────────────
class SaleReturnItem {
  final int productId;
  final String productName;
  final String unit;
  double quantity;
  final double unitPrice;

  SaleReturnItem({required this.productId, required this.productName,
    required this.unit, required this.quantity, required this.unitPrice});

  double get totalPrice => quantity * unitPrice;
}

class SaleReturn {
  final int? id;
  final String returnNumber;
  final int? originalBillId;
  final String? originalBillNumber;
  final String returnType; // 'return' or 'exchange'
  final String? customerName;
  final List<SaleReturnItem> items;
  final double totalReturnAmount;
  final String refundMode;
  final String? reason;
  final DateTime createdAt;

  const SaleReturn({this.id, required this.returnNumber, this.originalBillId,
    this.originalBillNumber, required this.returnType, this.customerName,
    required this.items, required this.totalReturnAmount,
    this.refundMode = 'cash', this.reason, required this.createdAt});
}

// ─── Repository ────────────────────────────────────────────────────────────────
class SaleReturnRepository {
  final DatabaseHelper _db;
  int _counter = 0;
  SaleReturnRepository(this._db);

  Future<SaleReturn> saveSaleReturn({
    required List<SaleReturnItem> items,
    required String returnType,
    int? originalBillId, String? originalBillNumber,
    String? customerName, String refundMode = 'cash', String? reason,
  }) async {
    final db = await _db.database;
    final now = DateTime.now();
    _counter++;
    final returnNumber = 'RET-${now.year}${now.month.toString().padLeft(2,'0')}${now.day.toString().padLeft(2,'0')}-${_counter.toString().padLeft(3,'0')}';
    final total = items.fold(0.0, (s, i) => s + i.totalPrice);

    return await db.transaction((txn) async {
      final retId = await txn.insert('sale_returns', {
        'return_number': returnNumber, 'original_bill_id': originalBillId,
        'original_bill_number': originalBillNumber, 'return_type': returnType,
        'customer_name': customerName, 'total_return_amount': total,
        'refund_mode': refundMode, 'reason': reason, 'created_at': now.toIso8601String(),
      });

      for (final item in items) {
        await txn.insert('sale_return_items', {
          'return_id': retId, 'product_id': item.productId,
          'product_name': item.productName, 'quantity': item.quantity,
          'unit': item.unit, 'unit_price': item.unitPrice, 'total_price': item.totalPrice,
        });
        // Add stock back
        await txn.rawUpdate('UPDATE products SET stock_quantity = stock_quantity + ?, updated_at = ? WHERE id = ?',
            [item.quantity, now.toIso8601String(), item.productId]);
      }

      return SaleReturn(id: retId, returnNumber: returnNumber,
          originalBillId: originalBillId, originalBillNumber: originalBillNumber,
          returnType: returnType, customerName: customerName, items: items,
          totalReturnAmount: total, refundMode: refundMode, reason: reason, createdAt: now);
    });
  }

  Future<List<Map<String, dynamic>>> getRecentReturns({int limit = 30}) async {
    final db = await _db.database;
    return await db.query('sale_returns', orderBy: 'created_at DESC', limit: limit);
  }
}

// ─── Sale Return Page ──────────────────────────────────────────────────────────
class SaleReturnPage extends StatefulWidget {
  const SaleReturnPage({super.key});
  @override State<SaleReturnPage> createState() => _SaleReturnPageState();
}

class _SaleReturnPageState extends State<SaleReturnPage> with SingleTickerProviderStateMixin {
  late TabController _tabs;
  late final SaleReturnRepository _repo;
  String _returnType = 'return';
  String? _originalBillNumber;
  String? _customerName;
  String _refundMode = 'cash';
  final List<SaleReturnItem> _items = [];
  final _billNumCtrl = TextEditingController();
  final _customerCtrl = TextEditingController();
  final _reasonCtrl = TextEditingController();
  bool _isSaving = false;
  List<Map<String, dynamic>> _history = [];

  @override void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _repo = SaleReturnRepository(DatabaseHelper.instance);
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final h = await _repo.getRecentReturns();
    setState(() => _history = h);
  }

  double get _total => _items.fold(0.0, (s, i) => s + i.totalPrice);

  @override void dispose() { _tabs.dispose(); _billNumCtrl.dispose(); _customerCtrl.dispose(); _reasonCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sale Return / Exchange'),
        bottom: TabBar(
          controller: _tabs,
          labelColor: AppTheme.primary, unselectedLabelColor: AppTheme.textSecondary, indicatorColor: AppTheme.primary,
          tabs: const [Tab(text: 'New Return'), Tab(text: 'History')],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [_buildNewReturn(), _buildHistory()],
      ),
    );
  }

  Widget _buildNewReturn() {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(14.w),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Return Type
              _label('Return Type'),
              Row(children: [
                Expanded(child: _typeBtn('return', 'Return', '↩️')),
                SizedBox(width: 10.w),
                Expanded(child: _typeBtn('exchange', 'Exchange', '🔄')),
              ]),
              SizedBox(height: 14.h),

              _label('Original Bill Number (optional)'),
              TextField(controller: _billNumCtrl, onChanged: (v) => setState(() => _originalBillNumber = v.isEmpty ? null : v),
                  decoration: const InputDecoration(hintText: 'e.g. 20241201-0001', prefixIcon: Icon(Icons.receipt))),
              SizedBox(height: 10.h),

              _label('Customer Name (optional)'),
              TextField(controller: _customerCtrl, onChanged: (v) => setState(() => _customerName = v.isEmpty ? null : v),
                  decoration: const InputDecoration(hintText: 'Customer name', prefixIcon: Icon(Icons.person))),
              SizedBox(height: 14.h),

              // Items to return
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                _label('Items to Return'),
                TextButton.icon(onPressed: _addReturnItemSheet, icon: const Icon(Icons.add, size: 18), label: const Text('Add Item')),
              ]),
              if (_items.isEmpty)
                Container(height: 80.h, decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(12.r), border: Border.all(color: AppTheme.divider)),
                    child: Center(child: Text('Add items being returned', style: AppTheme.caption)))
              else
                ..._items.asMap().entries.map((e) => Container(
                  margin: EdgeInsets.only(bottom: 8.h), padding: EdgeInsets.all(12.w),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12.r), border: Border.all(color: AppTheme.divider)),
                  child: Row(children: [
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(e.value.productName, style: AppTheme.heading3),
                      Text('${e.value.quantity} ${e.value.unit} × ${CurrencyFormatter.format(e.value.unitPrice)}', style: AppTheme.caption),
                      Text(CurrencyFormatter.format(e.value.totalPrice), style: AppTheme.price.copyWith(fontSize: 13.sp)),
                    ])),
                    IconButton(icon: const Icon(Icons.delete_outline, color: AppTheme.danger), onPressed: () => setState(() => _items.removeAt(e.key))),
                  ]),
                )),
              SizedBox(height: 14.h),

              // Refund Mode
              _label('Refund Mode'),
              Row(
                children: ['cash', 'upi', 'card'].map((m) {
                  final sel = _refundMode == m;
                  return Expanded(child: GestureDetector(
                    onTap: () => setState(() => _refundMode = m),
                    child: Container(
                      margin: EdgeInsets.only(right: 6.w),
                      padding: EdgeInsets.symmetric(vertical: 10.h),
                      decoration: BoxDecoration(
                        color: sel ? AppTheme.primary.withOpacity(0.1) : AppTheme.surface,
                        borderRadius: BorderRadius.circular(8.r),
                        border: Border.all(color: sel ? AppTheme.primary : AppTheme.divider),
                      ),
                      child: Text(m.toUpperCase(), textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 11.sp, color: sel ? AppTheme.primary : AppTheme.textSecondary, fontWeight: FontWeight.w600, fontFamily: 'Poppins')),
                    ),
                  ));
                }).toList(),
              ),
              SizedBox(height: 10.h),
              TextField(controller: _reasonCtrl, decoration: const InputDecoration(labelText: 'Reason (optional)', prefixIcon: Icon(Icons.info_outline))),
              SizedBox(height: 80.h),
            ]),
          ),
        ),
        if (_items.isNotEmpty)
          Container(
            padding: EdgeInsets.all(16.w),
            decoration: BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: AppTheme.divider))),
            child: Column(children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('Refund Amount', style: AppTheme.heading3),
                Text(CurrencyFormatter.format(_total), style: AppTheme.price),
              ]),
              SizedBox(height: 12.h),
              ElevatedButton(
                onPressed: _isSaving ? null : _saveReturn,
                style: ElevatedButton.styleFrom(backgroundColor: _returnType == 'exchange' ? AppTheme.warning : AppTheme.danger),
                child: _isSaving ? const CircularProgressIndicator(color: Colors.white)
                    : Text('${_returnType == 'exchange' ? '🔄 Exchange' : '↩️ Return'} — ${CurrencyFormatter.format(_total)}'),
              ),
            ]),
          ),
      ],
    );
  }

  Widget _buildHistory() {
    if (_history.isEmpty) return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Text('📋', style: TextStyle(fontSize: 48.sp)), SizedBox(height: 12.h), Text('No returns yet', style: AppTheme.heading3),
    ]));
    return ListView.separated(
      padding: EdgeInsets.all(14.w), itemCount: _history.length,
      separatorBuilder: (_, __) => SizedBox(height: 8.h),
      itemBuilder: (_, i) {
        final r = _history[i];
        return Container(
          padding: EdgeInsets.all(14.w),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14.r), border: Border.all(color: AppTheme.divider)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(r['return_number'] as String, style: AppTheme.heading3)),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                decoration: BoxDecoration(
                  color: (r['return_type'] == 'exchange' ? AppTheme.warning : AppTheme.danger).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6.r),
                ),
                child: Text((r['return_type'] as String).toUpperCase(),
                    style: TextStyle(fontSize: 10.sp, color: r['return_type'] == 'exchange' ? AppTheme.warning : AppTheme.danger, fontWeight: FontWeight.w700)),
              ),
            ]),
            SizedBox(height: 4.h),
            Text(DateFormat('dd MMM yyyy, h:mm a').format(DateTime.parse(r['created_at'] as String)), style: AppTheme.caption),
            if (r['customer_name'] != null) Text('👤 ${r['customer_name']}', style: AppTheme.caption),
            if (r['reason'] != null) Text('Reason: ${r['reason']}', style: AppTheme.caption),
            SizedBox(height: 6.h),
            Text(CurrencyFormatter.format((r['total_return_amount'] as num).toDouble()),
                style: AppTheme.price.copyWith(fontSize: 16.sp, color: AppTheme.danger)),
          ]),
        );
      },
    );
  }

  Widget _typeBtn(String type, String label, String emoji) {
    final sel = _returnType == type;
    return GestureDetector(
      onTap: () => setState(() => _returnType = type),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(vertical: 14.h),
        decoration: BoxDecoration(
          color: sel ? (type == 'exchange' ? AppTheme.warning : AppTheme.danger).withOpacity(0.1) : AppTheme.surface,
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: sel ? (type == 'exchange' ? AppTheme.warning : AppTheme.danger) : AppTheme.divider, width: sel ? 1.5 : 1),
        ),
        child: Column(children: [
          Text(emoji, style: TextStyle(fontSize: 22.sp)),
          SizedBox(height: 4.h),
          Text(label, style: TextStyle(fontSize: 13.sp, fontWeight: sel ? FontWeight.w700 : FontWeight.w400,
              color: sel ? (type == 'exchange' ? AppTheme.warning : AppTheme.danger) : AppTheme.textSecondary, fontFamily: 'Poppins')),
        ]),
      ),
    );
  }

  Widget _label(String t) => Padding(padding: EdgeInsets.only(bottom: 6.h), child: Text(t, style: AppTheme.heading3.copyWith(color: AppTheme.primary)));

  void _addReturnItemSheet() {
    final nameCtrl = TextEditingController();
    final qtyCtrl = TextEditingController(text: '1');
    final priceCtrl = TextEditingController();
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: EdgeInsets.only(left: 20.w, right: 20.w, top: 20.h, bottom: MediaQuery.of(context).viewInsets.bottom + 20.h),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24.r))),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Add Return Item', style: AppTheme.heading2), SizedBox(height: 16.h),
          TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Product Name *')),
          SizedBox(height: 10.h),
          Row(children: [
            Expanded(child: TextField(controller: qtyCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Quantity'))),
            SizedBox(width: 10.w),
            Expanded(child: TextField(controller: priceCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Unit Price (₹)'))),
          ]),
          SizedBox(height: 16.h),
          ElevatedButton(
            onPressed: () {
              if (nameCtrl.text.trim().isEmpty || priceCtrl.text.isEmpty) return;
              setState(() => _items.add(SaleReturnItem(
                  productId: 0, productName: nameCtrl.text.trim(), unit: 'piece',
                  quantity: double.tryParse(qtyCtrl.text) ?? 1,
                  unitPrice: double.tryParse(priceCtrl.text) ?? 0)));
              Navigator.pop(context);
            },
            child: const Text('Add Item'),
          ),
        ]),
      ),
    );
  }

  Future<void> _saveReturn() async {
    if (_items.isEmpty) return;
    setState(() => _isSaving = true);
    await _repo.saveSaleReturn(items: _items, returnType: _returnType,
        originalBillNumber: _originalBillNumber, customerName: _customerName,
        refundMode: _refundMode, reason: _reasonCtrl.text.isEmpty ? null : _reasonCtrl.text);
    await _loadHistory();
    setState(() { _isSaving = false; _items.clear(); _billNumCtrl.clear(); _customerCtrl.clear(); _reasonCtrl.clear(); });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('${_returnType == 'exchange' ? 'Exchange' : 'Return'} saved! Stock restored.'),
        backgroundColor: AppTheme.accent,
      ));
      _tabs.animateTo(1);
    }
  }
}