import 'package:equatable/equatable.dart';

class Product extends Equatable {
  final int? id;
  final String name;
  final int? categoryId;
  final String? categoryName;
  final int? brandId;
  final String? brandName;
  final int? uomId;
  final String? uomShortName;
  final double purchasePrice;
  final double sellingPrice;
  final double wholesalePrice;
  final double stockQuantity;
  final String unit;
  final double lowStockThreshold;
  final double gstRate;
  final bool gstInclusive;
  final String rateType; // 'fixed' | 'open'
  final String? barcode;
  final String? hsnCode;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
  // Wholesale/Retail fields (v9)
  final String wholesaleUnit;
  final String retailUnit;
  final double wholesaleToRetailQty;
  final double retailPrice;

  const Product({
    this.id, required this.name, this.categoryId, this.categoryName,
    this.brandId, this.brandName, this.uomId, this.uomShortName,
    required this.purchasePrice, required this.sellingPrice,
    this.wholesalePrice = 0.0, required this.stockQuantity, this.unit = 'piece',
    this.lowStockThreshold = 5.0, this.gstRate = 0.0, this.gstInclusive = true,
    this.rateType = 'fixed', this.barcode, this.hsnCode, this.isActive = true,
    required this.createdAt, required this.updatedAt,
    this.wholesaleUnit = 'bag', this.retailUnit = 'kg',
    this.wholesaleToRetailQty = 1.0, this.retailPrice = 0.0,
  });

  bool get isLowStock => stockQuantity > 0 && stockQuantity <= lowStockThreshold;
  bool get isOutOfStock => stockQuantity <= 0;
  double get profit => sellingPrice - purchasePrice;
  double get profitMargin => sellingPrice > 0 ? (profit / sellingPrice) * 100 : 0;
  bool get isOpenRate => rateType == 'open';
  bool get hasGst => gstRate > 0;
  String get displayUnit => uomShortName ?? unit;

  Product copyWith({
    int? id, String? name, int? categoryId, String? categoryName,
    int? brandId, String? brandName, int? uomId, String? uomShortName,
    double? purchasePrice, double? sellingPrice, double? wholesalePrice,
    double? stockQuantity, String? unit, double? lowStockThreshold,
    double? gstRate, bool? gstInclusive, String? rateType,
    String? barcode, String? hsnCode, bool? isActive,
    DateTime? createdAt, DateTime? updatedAt,
    String? wholesaleUnit, String? retailUnit,
    double? wholesaleToRetailQty, double? retailPrice,
  }) => Product(
    id: id ?? this.id, name: name ?? this.name,
    categoryId: categoryId ?? this.categoryId, categoryName: categoryName ?? this.categoryName,
    brandId: brandId ?? this.brandId, brandName: brandName ?? this.brandName,
    uomId: uomId ?? this.uomId, uomShortName: uomShortName ?? this.uomShortName,
    purchasePrice: purchasePrice ?? this.purchasePrice,
    sellingPrice: sellingPrice ?? this.sellingPrice,
    wholesalePrice: wholesalePrice ?? this.wholesalePrice,
    stockQuantity: stockQuantity ?? this.stockQuantity, unit: unit ?? this.unit,
    lowStockThreshold: lowStockThreshold ?? this.lowStockThreshold,
    gstRate: gstRate ?? this.gstRate, gstInclusive: gstInclusive ?? this.gstInclusive,
    rateType: rateType ?? this.rateType, barcode: barcode ?? this.barcode,
    hsnCode: hsnCode ?? this.hsnCode, isActive: isActive ?? this.isActive,
    createdAt: createdAt ?? this.createdAt, updatedAt: updatedAt ?? DateTime.now(),
    wholesaleUnit: wholesaleUnit ?? this.wholesaleUnit,
    retailUnit: retailUnit ?? this.retailUnit,
    wholesaleToRetailQty: wholesaleToRetailQty ?? this.wholesaleToRetailQty,
    retailPrice: retailPrice ?? this.retailPrice,
  );

  @override List<Object?> get props => [id, name, categoryId, brandId, purchasePrice, sellingPrice, stockQuantity];
}

class ProductModel extends Product {
  const ProductModel({
    super.id, required super.name, super.categoryId, super.categoryName,
    super.brandId, super.brandName, super.uomId, super.uomShortName,
    required super.purchasePrice, required super.sellingPrice, super.wholesalePrice,
    required super.stockQuantity, super.unit, super.lowStockThreshold,
    super.gstRate, super.gstInclusive, super.rateType, super.barcode, super.hsnCode,
    super.isActive, required super.createdAt, required super.updatedAt,
    super.wholesaleUnit, super.retailUnit, super.wholesaleToRetailQty, super.retailPrice,
  });

  factory ProductModel.fromMap(Map<String, dynamic> m) => ProductModel(
    id: m['id'], name: m['name'], categoryId: m['category_id'],
    categoryName: m['category_name'], brandId: m['brand_id'], brandName: m['brand_name'],
    uomId: m['uom_id'], uomShortName: m['uom_short_name'],
    purchasePrice: (m['purchase_price'] as num).toDouble(),
    sellingPrice: (m['selling_price'] as num).toDouble(),
    wholesalePrice: (m['wholesale_price'] as num?)?.toDouble() ?? 0.0,
    stockQuantity: (m['stock_quantity'] as num).toDouble(),
    unit: m['unit'] ?? 'piece',
    lowStockThreshold: (m['low_stock_threshold'] as num?)?.toDouble() ?? 5.0,
    gstRate: (m['gst_rate'] as num?)?.toDouble() ?? 0.0,
    gstInclusive: (m['gst_inclusive'] as int? ?? 1) == 1,
    rateType: m['rate_type'] ?? 'fixed',
    barcode: m['barcode'], hsnCode: m['hsn_code'],
    isActive: (m['is_active'] as int? ?? 1) == 1,
    createdAt: DateTime.parse(m['created_at']),
    updatedAt: DateTime.parse(m['updated_at']),
    wholesaleUnit: m['wholesale_unit'] as String? ?? 'bag',
    retailUnit: m['retail_unit'] as String? ?? 'kg',
    wholesaleToRetailQty: (m['wholesale_to_retail_qty'] as num?)?.toDouble() ?? 1.0,
    retailPrice: (m['retail_price'] as num?)?.toDouble() ?? 0.0,
  );

  Map<String, dynamic> toMap() => {
    if (id != null) 'id': id, 'name': name, 'category_id': categoryId,
    'brand_id': brandId, 'uom_id': uomId,
    'purchase_price': purchasePrice, 'selling_price': sellingPrice,
    'wholesale_price': wholesalePrice, 'stock_quantity': stockQuantity,
    'unit': unit, 'low_stock_threshold': lowStockThreshold,
    'gst_rate': gstRate, 'gst_inclusive': gstInclusive ? 1 : 0,
    'rate_type': rateType, 'barcode': barcode, 'hsn_code': hsnCode,
    'is_active': isActive ? 1 : 0,
    'created_at': createdAt.toIso8601String(), 'updated_at': updatedAt.toIso8601String(),
    'wholesale_unit': wholesaleUnit, 'retail_unit': retailUnit,
    'wholesale_to_retail_qty': wholesaleToRetailQty, 'retail_price': retailPrice,
  };
}

class Category extends Equatable {
  final int? id;
  final String name;
  final String icon;
  final String color;

  const Category({this.id, required this.name, this.icon = '📦', this.color = '#9E9E9E'});

  factory Category.fromMap(Map<String, dynamic> m) => Category(
      id: m['id'], name: m['name'], icon: m['icon'] ?? '📦', color: m['color'] ?? '#9E9E9E');

  Map<String, dynamic> toMap() => {
    if (id != null) 'id': id, 'name': name, 'icon': icon, 'color': color,
    'created_at': DateTime.now().toIso8601String()};

  @override List<Object?> get props => [id, name];
}

class ProductUnits {
  static const List<String> all = ['piece','kg','gram','litre','ml','dozen','pack','box','bottle','cup','plate','bowl','glass','set','metre'];
}