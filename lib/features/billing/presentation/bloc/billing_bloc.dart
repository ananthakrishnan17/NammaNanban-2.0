import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import '../../domain/entities/bill.dart';
import '../../data/repositories/billing_repository_impl.dart';
import '../../../masters/domain/entities/masters.dart';

abstract class BillingEvent extends Equatable { @override List<Object?> get props => []; }
class AddToCart extends BillingEvent { final CartItem item; AddToCart(this.item); @override List<Object?> get props => [item.productId]; }
class RemoveFromCart extends BillingEvent { final int productId; RemoveFromCart(this.productId); @override List<Object?> get props => [productId]; }
class UpdateCartItemQty extends BillingEvent { final int productId; final double quantity; UpdateCartItemQty({required this.productId, required this.quantity}); @override List<Object?> get props => [productId, quantity]; }
class UpdateOpenRatePrice extends BillingEvent { final int productId; final double price; UpdateOpenRatePrice({required this.productId, required this.price}); @override List<Object?> get props => [productId, price]; }
class ClearCart extends BillingEvent {}
class ApplyDiscount extends BillingEvent { final double amount; ApplyDiscount(this.amount); @override List<Object?> get props => [amount]; }
class SetPaymentMode extends BillingEvent { final String mode; SetPaymentMode(this.mode); @override List<Object?> get props => [mode]; }
class SetBillType extends BillingEvent { final BillType billType; SetBillType(this.billType); @override List<Object?> get props => [billType]; }
class SetCustomer extends BillingEvent { final Customer? customer; SetCustomer(this.customer); @override List<Object?> get props => [customer?.id]; }
class SetCustomerName extends BillingEvent { final String name; SetCustomerName(this.name); @override List<Object?> get props => [name]; }
class SaveBill extends BillingEvent {}
class RestoreHeldCartItems extends BillingEvent {
  final List<CartItem> items; final String billType;
  final String? customerName; final double discountAmount;
  RestoreHeldCartItems({required this.items, this.billType = 'retail', this.customerName, this.discountAmount = 0});
}

class CartState extends Equatable {
  final List<CartItem> items;
  final double discountAmount;
  final String paymentMode;
  final BillType billType;
  final Customer? selectedCustomer;
  final String? customerName;
  final bool isSaving;
  final Bill? lastSavedBill;
  final String? errorMessage;

  const CartState({this.items = const [], this.discountAmount = 0.0, this.paymentMode = 'cash',
    this.billType = BillType.retail, this.selectedCustomer, this.customerName,
    this.isSaving = false, this.lastSavedBill, this.errorMessage});

  double get subtotal => items.fold(0.0, (s, i) => s + i.totalFor(billType));
  double get totalAmount => subtotal - discountAmount;
  double get totalProfit => items.fold(0.0, (s, i) => s + i.profitFor(billType));
  double get gstTotal => items.fold(0.0, (s, i) => s + i.gstAmountFor(billType));
  int get itemCount => items.fold(0, (s, i) => s + i.quantity.toInt());
  bool get isEmpty => items.isEmpty;

  CartState copyWith({List<CartItem>? items, double? discountAmount, String? paymentMode,
    BillType? billType, Customer? selectedCustomer, String? customerName,
    bool? isSaving, Bill? lastSavedBill, String? errorMessage}) => CartState(
      items: items ?? this.items, discountAmount: discountAmount ?? this.discountAmount,
      paymentMode: paymentMode ?? this.paymentMode, billType: billType ?? this.billType,
      selectedCustomer: selectedCustomer ?? this.selectedCustomer,
      customerName: customerName ?? this.customerName, isSaving: isSaving ?? this.isSaving,
      lastSavedBill: lastSavedBill ?? this.lastSavedBill, errorMessage: errorMessage);

  @override List<Object?> get props => [items, discountAmount, paymentMode, billType, selectedCustomer, isSaving, lastSavedBill, errorMessage];
}

class BillingBloc extends Bloc<BillingEvent, CartState> {
  final BillingRepository _repository;
  BillingBloc(this._repository) : super(const CartState()) {
    on<AddToCart>(_onAdd);
    on<RemoveFromCart>(_onRemove);
    on<UpdateCartItemQty>(_onUpdateQty);
    on<UpdateOpenRatePrice>(_onUpdateOpenRate);
    on<ClearCart>((e, emit) => emit(const CartState()));
    on<ApplyDiscount>((e, emit) => emit(state.copyWith(discountAmount: e.amount)));
    on<SetPaymentMode>((e, emit) => emit(state.copyWith(paymentMode: e.mode)));
    on<SetBillType>((e, emit) => emit(state.copyWith(billType: e.billType)));
    on<SetCustomer>((e, emit) => emit(state.copyWith(selectedCustomer: e.customer, customerName: e.customer?.name)));
    on<SetCustomerName>((e, emit) => emit(state.copyWith(customerName: e.name)));
    on<SaveBill>(_onSave);
    on<RestoreHeldCartItems>(_onRestoreHeld);
  }

  void _onAdd(AddToCart e, Emitter<CartState> emit) {
    final idx = state.items.indexWhere((i) => i.productId == e.item.productId);
    final updated = List<CartItem>.from(state.items);
    if (idx >= 0) updated[idx] = updated[idx].copyWith(quantity: updated[idx].quantity + 1);
    else updated.add(e.item);
    emit(state.copyWith(items: updated));
  }

  void _onRemove(RemoveFromCart e, Emitter<CartState> emit) =>
      emit(state.copyWith(items: state.items.where((i) => i.productId != e.productId).toList()));

  void _onUpdateQty(UpdateCartItemQty e, Emitter<CartState> emit) {
    if (e.quantity <= 0) { add(RemoveFromCart(e.productId)); return; }
    emit(state.copyWith(items: state.items.map((i) => i.productId == e.productId ? i.copyWith(quantity: e.quantity) : i).toList()));
  }

  void _onUpdateOpenRate(UpdateOpenRatePrice e, Emitter<CartState> emit) =>
      emit(state.copyWith(items: state.items.map((i) => i.productId == e.productId ? i.copyWith(overridePrice: e.price) : i).toList()));

  Future<void> _onSave(SaveBill e, Emitter<CartState> emit) async {
    if (state.items.isEmpty) return;
    emit(state.copyWith(isSaving: true));
    try {
      final bill = await _repository.saveBill(
        items: state.items, billType: state.billType.value,
        discountAmount: state.discountAmount, paymentMode: state.paymentMode,
        customerId: state.selectedCustomer?.id,
        customerName: state.selectedCustomer?.name ?? state.customerName,
        customerAddress: state.selectedCustomer?.address,
        customerGstin: state.selectedCustomer?.gstNumber,
      );
      emit(CartState(lastSavedBill: bill));
    } catch (err) { emit(state.copyWith(isSaving: false, errorMessage: err.toString())); }
  }

  void _onRestoreHeld(RestoreHeldCartItems e, Emitter<CartState> emit) => emit(CartState(
      items: e.items,
      billType: e.billType == 'wholesale' ? BillType.wholesale : BillType.retail,
      customerName: e.customerName, discountAmount: e.discountAmount));
}