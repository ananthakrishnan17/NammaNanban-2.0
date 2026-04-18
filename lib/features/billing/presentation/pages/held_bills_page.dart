import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';

import '../../../../core/database/database_helper.dart';
import '../../../../core/theme/app_theme.dart';

import '../../../../core/utils/currency_formatter.dart';
import '../../../billing/presentation/bloc/billing_bloc.dart';


// ─── Held Bill Entities ────────────────────────────────────────────────────────
class HeldBillItem {
  final int? id;
  final int heldBillId;
  final int productId;
  final String productName;
  final double quantity;
  final String unit;
  final double unitPrice;
  final double purchasePrice;
  final double gstRate;
  final bool gstInclusive;
  final double totalPrice;

  const HeldBillItem({this.id, required this.heldBillId, required this.productId,
    required this.productName, required this.quantity, required this.unit,
    required this.unitPrice, required this.purchasePrice,
    this.gstRate = 0, this.gstInclusive = true, required this.totalPrice});

  factory HeldBillItem.fromMap(Map<String, dynamic> m) => HeldBillItem(
      id: m['id'], heldBillId: m['held_bill_id'], productId: m['product_id'],
      productName: m['product_name'], quantity: (m['quantity'] as num).toDouble(),
      unit: m['unit'], unitPrice: (m['unit_price'] as num).toDouble(),
      purchasePrice: (m['purchase_price'] as num?)?.toDouble() ?? 0,
      gstRate: (m['gst_rate'] as num?)?.toDouble() ?? 0,
      gstInclusive: (m['gst_inclusive'] as int? ?? 1) == 1,
      totalPrice: (m['total_price'] as num).toDouble());
}

class HeldBill {
  final int? id;
  final String? holdName;
  final String billType;
  final int? customerId;
  final String? customerName;
  final double discountAmount;
  final String paymentMode;
  final DateTime createdAt;
  final List<HeldBillItem> items;

  const HeldBill({this.id, this.holdName, this.billType = 'retail',
    this.customerId, this.customerName, this.discountAmount = 0,
    this.paymentMode = 'cash', required this.createdAt, required this.items});

  double get totalAmount => items.fold(0.0, (s, i) => s + i.totalPrice) - discountAmount;
  int get itemCount => items.length;

  factory HeldBill.fromMap(Map<String, dynamic> m, List<HeldBillItem> items) => HeldBill(
      id: m['id'], holdName: m['hold_name'], billType: m['bill_type'] ?? 'retail',
      customerId: m['customer_id'], customerName: m['customer_name'],
      discountAmount: (m['discount_amount'] as num?)?.toDouble() ?? 0,
      paymentMode: m['payment_mode'] ?? 'cash',
      createdAt: DateTime.parse(m['created_at']), items: items);
}

// ─── Repository ────────────────────────────────────────────────────────────────
class HeldBillRepository {
  final DatabaseHelper _db;
  HeldBillRepository(this._db);

  Future<int> holdBill(CartState cart, {String? holdName}) async {
    final db = await _db.database;
    final now = DateTime.now();
    return await db.transaction((txn) async {
      final heldId = await txn.insert('held_bills', {
        'hold_name': holdName ?? 'Bill ${now.hour}:${now.minute.toString().padLeft(2,'0')}',
        'bill_type': cart.billType.name, 'customer_id': null, 'customer_name': cart.customerName,
        'discount_amount': cart.discountAmount, 'payment_mode': cart.paymentMode,
        'created_at': now.toIso8601String(),
      });
      for (final item in cart.items) {
        await txn.insert('held_bill_items', {
          'held_bill_id': heldId, 'product_id': item.productId,
          'product_name': item.productName, 'quantity': item.quantity,
          'unit': item.unit, 'unit_price': item.sellingPrice,
          'purchase_price': item.purchasePrice,
          'gst_rate': item.gstRate,
          'gst_inclusive': item.gstInclusive ? 1 : 0,
          'total_price': item.totalFor(cart.billType),
        });
      }
      return heldId;
    });
  }

  Future<List<HeldBill>> getAllHeldBills() async {
    final db = await _db.database;
    final rows = await db.query('held_bills', orderBy: 'created_at DESC');
    final result = <HeldBill>[];
    for (final row in rows) {
      final items = await db.query('held_bill_items', where: 'held_bill_id=?', whereArgs: [row['id']]);
      result.add(HeldBill.fromMap(row, items.map((i) => HeldBillItem.fromMap(i)).toList()));
    }
    return result;
  }

  Future<void> deleteHeldBill(int id) async {
    final db = await _db.database;
    await db.delete('held_bills', where: 'id=?', whereArgs: [id]);
  }
}

// ─── Events + States + BLoC ────────────────────────────────────────────────────
abstract class HeldBillEvent extends Equatable { @override List<Object?> get props => []; }
class LoadHeldBills extends HeldBillEvent {}
class HoldCurrentBill extends HeldBillEvent {
  final CartState cart; final String? holdName;
  HoldCurrentBill(this.cart, {this.holdName});
}
class RestoreHeldBill extends HeldBillEvent { final HeldBill bill; RestoreHeldBill(this.bill); }
class DeleteHeldBill extends HeldBillEvent { final int id; DeleteHeldBill(this.id); }

class HeldBillState extends Equatable {
  final List<HeldBill> heldBills;
  final bool isLoading;
  const HeldBillState({this.heldBills = const [], this.isLoading = false});
  HeldBillState copyWith({List<HeldBill>? heldBills, bool? isLoading}) =>
      HeldBillState(heldBills: heldBills ?? this.heldBills, isLoading: isLoading ?? this.isLoading);
  @override List<Object?> get props => [heldBills, isLoading];
}

class HeldBillBloc extends Bloc<HeldBillEvent, HeldBillState> {
  final HeldBillRepository _repo;
  HeldBillBloc(this._repo) : super(const HeldBillState()) {
    on<LoadHeldBills>(_onLoad);
    on<HoldCurrentBill>(_onHold);
    on<DeleteHeldBill>(_onDelete);
  }

  Future<void> _onLoad(LoadHeldBills e, Emitter<HeldBillState> emit) async {
    emit(state.copyWith(isLoading: true));
    final bills = await _repo.getAllHeldBills();
    emit(state.copyWith(heldBills: bills, isLoading: false));
  }

  Future<void> _onHold(HoldCurrentBill e, Emitter<HeldBillState> emit) async {
    await _repo.holdBill(e.cart, holdName: e.holdName);
    add(LoadHeldBills());
  }

  Future<void> _onDelete(DeleteHeldBill e, Emitter<HeldBillState> emit) async {
    await _repo.deleteHeldBill(e.id);
    add(LoadHeldBills());
  }
}

// ─── Held Bills UI Page ───────────────────────────────────────────────────────
class HeldBillsPage extends StatelessWidget {
  final void Function(HeldBill) onRestore;
  const HeldBillsPage({super.key, required this.onRestore});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Bills On Hold')),
      body: BlocBuilder<HeldBillBloc, HeldBillState>(
        builder: (ctx, state) {
          if (state.isLoading) return const Center(child: CircularProgressIndicator());
          if (state.heldBills.isEmpty) {
            return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text('⏸️', style: TextStyle(fontSize: 56.sp)),
              SizedBox(height: 16.h),
              Text('No bills on hold', style: AppTheme.heading2),
              SizedBox(height: 8.h),
              Text('Hold a bill from the billing screen\nto continue it later', style: AppTheme.caption, textAlign: TextAlign.center),
            ]));
          }
          return ListView.separated(
            padding: EdgeInsets.all(14.w),
            itemCount: state.heldBills.length,
            separatorBuilder: (_, __) => SizedBox(height: 10.h),
            itemBuilder: (_, i) => _heldBillCard(ctx, state.heldBills[i]),
          );
        },
      ),
    );
  }

  Widget _heldBillCard(BuildContext ctx, HeldBill bill) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: AppTheme.divider),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Padding(
        padding: EdgeInsets.all(14.w),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(bill.holdName ?? 'Held Bill', style: AppTheme.heading3)),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
              decoration: BoxDecoration(color: AppTheme.warning.withOpacity(0.15), borderRadius: BorderRadius.circular(6.r)),
              child: Text(bill.billType.toUpperCase(), style: TextStyle(fontSize: 10.sp, color: AppTheme.warning, fontWeight: FontWeight.w700)),
            ),
          ]),
          SizedBox(height: 4.h),
          Text(DateFormat('dd MMM, h:mm a').format(bill.createdAt), style: AppTheme.caption),
          if (bill.customerName != null) Text('👤 ${bill.customerName}', style: AppTheme.caption),
          SizedBox(height: 8.h),
          Text('${bill.itemCount} items', style: AppTheme.caption),
          SizedBox(height: 4.h),
          // Item summary
          ...bill.items.take(3).map((item) => Text(
            '• ${item.productName}  ×${item.quantity}  ${CurrencyFormatter.format(item.totalPrice)}',
            style: AppTheme.caption,
          )),
          if (bill.items.length > 3) Text('  +${bill.items.length - 3} more...', style: AppTheme.caption.copyWith(color: AppTheme.primary)),
          Divider(height: 16.h, color: AppTheme.divider),
          Row(children: [
            Expanded(child: Text(CurrencyFormatter.format(bill.totalAmount), style: AppTheme.price.copyWith(fontSize: 18.sp))),
            OutlinedButton(
              onPressed: () { ctx.read<HeldBillBloc>().add(DeleteHeldBill(bill.id!)); Navigator.pop(ctx); },
              style: OutlinedButton.styleFrom(foregroundColor: AppTheme.danger, side: const BorderSide(color: AppTheme.danger), minimumSize: Size(60.w, 36.h), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r))),
              child: const Text('Delete'),
            ),
            SizedBox(width: 8.w),
            ElevatedButton(
              onPressed: () { onRestore(bill); Navigator.pop(ctx); },
              style: ElevatedButton.styleFrom(minimumSize: Size(80.w, 36.h), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r))),
              child: const Text('Restore'),
            ),
          ]),
        ]),
      ),
    );
  }
}