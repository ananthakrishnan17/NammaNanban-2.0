import 'package:equatable/equatable.dart';
import '../../../products/domain/entities/product.dart';



import 'package:equatable/equatable.dart';

enum BillType { retail, wholesale }
extension BillTypeExt on BillType {
  String get value => name;
  String get label => name == 'retail' ? 'Retail' : 'Wholesale';
  String get emoji => name == 'retail' ? '🛒' : '📦';
}

class CartItem extends Equatable {
  final int productId;
  final String productName;
  final String unit;
  final double sellingPrice;
  final double wholesalePrice;
  final double purchasePrice;
  final double gstRate;
  final bool gstInclusive;
  final String rateType; // 'fixed' | 'open'
  final double quantity;
  final double? overridePrice; // for open rate

  const CartItem({
    required this.productId, required this.productName, required this.unit,
    required this.sellingPrice, required this.wholesalePrice,
    required this.purchasePrice, this.gstRate = 0, this.gstInclusive = true,
    this.rateType = 'fixed', required this.quantity, this.overridePrice,
  });

  double effectivePrice(BillType billType) {
    if (overridePrice != null) return overridePrice!;
    return billType == BillType.wholesale ? wholesalePrice : sellingPrice;
  }

  double totalFor(BillType billType) => effectivePrice(billType) * quantity;
  double profitFor(BillType billType) => (effectivePrice(billType) - purchasePrice) * quantity;
  double gstAmountFor(BillType billType) {
    if (gstRate <= 0) return 0;
    final t = totalFor(billType);
    return gstInclusive ? t - (t / (1 + gstRate / 100)) : t * gstRate / 100;
  }
  bool get isOpenRate => rateType == 'open';

  CartItem copyWith({double? quantity, double? overridePrice}) => CartItem(
    productId: productId, productName: productName, unit: unit,
    sellingPrice: sellingPrice, wholesalePrice: wholesalePrice, purchasePrice: purchasePrice,
    gstRate: gstRate, gstInclusive: gstInclusive, rateType: rateType,
    quantity: quantity ?? this.quantity, overridePrice: overridePrice ?? this.overridePrice,
  );

  @override List<Object?> get props => [productId, quantity, overridePrice];
}

class BillItem extends Equatable {
  final int? id;
  final int billId;
  final int productId;
  final String productName;
  final double quantity;
  final String unit;
  final double unitPrice;
  final double purchasePrice;
  final double discountAmount;
  final double gstRate;
  final double gstAmount;
  final double totalPrice;

  const BillItem({this.id, required this.billId, required this.productId,
    required this.productName, required this.quantity, required this.unit,
    required this.unitPrice, required this.purchasePrice, this.discountAmount = 0,
    this.gstRate = 0, this.gstAmount = 0, required this.totalPrice});

  double get profit => (unitPrice - purchasePrice) * quantity;
  @override List<Object?> get props => [id, billId, productId];
}

class Bill extends Equatable {
  final int? id;
  final String billNumber;
  final String billType;
  final List<BillItem> items;
  final double totalAmount;
  final double totalProfit;
  final double discountAmount;
  final double gstTotal;
  final double cgstTotal;
  final double sgstTotal;
  final String paymentMode;
  final int? customerId;
  final String? customerName;
  final String? customerAddress;
  final String? customerGstin;
  final String? notes;
  final DateTime createdAt;

  const Bill({this.id, required this.billNumber, this.billType = 'retail',
    required this.items, required this.totalAmount, required this.totalProfit,
    this.discountAmount = 0.0, this.gstTotal = 0.0, this.cgstTotal = 0.0,
    this.sgstTotal = 0.0, this.paymentMode = 'cash', this.customerId,
    this.customerName, this.customerAddress, this.customerGstin,
    this.notes, required this.createdAt});

  double get finalAmount => totalAmount - discountAmount;
  @override List<Object?> get props => [id, billNumber, createdAt];
}

enum PaymentMode { cash, upi, card, credit }
extension PaymentModeExt on PaymentMode {
  String get label { switch (this) { case PaymentMode.cash: return 'Cash'; case PaymentMode.upi: return 'UPI'; case PaymentMode.card: return 'Card'; case PaymentMode.credit: return 'Credit'; } }
  String get icon { switch (this) { case PaymentMode.cash: return '💵'; case PaymentMode.upi: return '📱'; case PaymentMode.card: return '💳'; case PaymentMode.credit: return '📋'; } }
}


// ─── Bill Model (DB) ──────────────────────────────────────────────────────────
class BillModel extends Bill {
  const BillModel({
    super.id,
    required super.billNumber,
    required super.items,
    required super.totalAmount,
    required super.totalProfit,
    super.discountAmount,
    super.paymentMode,
    super.customerName,
    super.notes,
    required super.createdAt,
  });

  factory BillModel.fromMap(Map<String, dynamic> map, List<BillItem> items) {
    return BillModel(
      id: map['id'] as int?,
      billNumber: map['bill_number'] as String,
      items: items,
      totalAmount: (map['total_amount'] as num).toDouble(),
      totalProfit: (map['total_profit'] as num).toDouble(),
      discountAmount: (map['discount_amount'] as num?)?.toDouble() ?? 0.0,
      paymentMode: map['payment_mode'] as String? ?? 'cash',
      customerName: map['customer_name'] as String?,
      notes: map['notes'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'bill_number': billNumber,
      'total_amount': totalAmount,
      'total_profit': totalProfit,
      'discount_amount': discountAmount,
      'payment_mode': paymentMode,
      'customer_name': customerName,
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

