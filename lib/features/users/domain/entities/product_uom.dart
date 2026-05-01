import 'package:equatable/equatable.dart';
import '../../../../../../../core/database/database_helper.dart';

// ─── ProductUom Entity ─────────────────────────────────────────────────────────
/// One row = one UOM that this product can be purchased or sold in.
///
/// [unitRole] distinguishes usage:
///   'sale'     – shown in the billing UOM picker (retail / wholesale)
///   'purchase' – used for recording stock-in; not shown at billing
///
/// [conversionQty] is the multiplier to the product's base stock unit.
///   e.g. product base = kg, bag conversionQty = 22 → 1 bag adds 22 kg to stock.
class ProductUom extends Equatable {
  final int? id;
  final int productId;
  final int uomId;
  final String uomName;
  final String uomShortName;
  final double conversionQty; // how many base units = 1 of this UOM
  final double sellingPrice;
  final double wholesalePrice;
  final double purchasePrice;
  final bool isDefault;
  final String unitRole; // 'sale' | 'purchase'

  const ProductUom({
    this.id,
    required this.productId,
    required this.uomId,
    required this.uomName,
    required this.uomShortName,
    this.conversionQty = 1.0,
    required this.sellingPrice,
    this.wholesalePrice = 0.0,
    this.purchasePrice = 0.0,
    this.isDefault = false,
    this.unitRole = 'sale',
  });

  factory ProductUom.fromMap(Map<String, dynamic> m) => ProductUom(
    id: m['id'] as int?,
    productId: m['product_id'] as int,
    uomId: m['uom_id'] as int,
    uomName: m['uom_name'] as String,
    uomShortName: m['uom_short_name'] as String,
    conversionQty: (m['conversion_qty'] as num?)?.toDouble() ?? 1.0,
    sellingPrice: (m['selling_price'] as num).toDouble(),
    wholesalePrice: (m['wholesale_price'] as num?)?.toDouble() ?? 0.0,
    purchasePrice: (m['purchase_price'] as num?)?.toDouble() ?? 0.0,
    isDefault: (m['is_default'] as int? ?? 0) == 1,
    unitRole: m['unit_role'] as String? ?? 'sale',
  );

  Map<String, dynamic> toMap() => {
    if (id != null) 'id': id,
    'product_id': productId,
    'uom_id': uomId,
    'uom_name': uomName,
    'uom_short_name': uomShortName,
    'conversion_qty': conversionQty,
    'selling_price': sellingPrice,
    'wholesale_price': wholesalePrice,
    'purchase_price': purchasePrice,
    'is_default': isDefault ? 1 : 0,
    'unit_role': unitRole,
  };

  double effectivePrice(bool isWholesale) =>
      isWholesale && wholesalePrice > 0 ? wholesalePrice : sellingPrice;

  String get displayLabel =>
      conversionQty == 1 ? uomShortName : '$uomShortName (×${conversionQty.toInt()})';

  ProductUom copyWith({
    double? sellingPrice, double? wholesalePrice,
    double? purchasePrice, bool? isDefault, double? conversionQty,
    String? unitRole,
  }) => ProductUom(
    id: id, productId: productId, uomId: uomId,
    uomName: uomName, uomShortName: uomShortName,
    conversionQty: conversionQty ?? this.conversionQty,
    sellingPrice: sellingPrice ?? this.sellingPrice,
    wholesalePrice: wholesalePrice ?? this.wholesalePrice,
    purchasePrice: purchasePrice ?? this.purchasePrice,
    isDefault: isDefault ?? this.isDefault,
    unitRole: unitRole ?? this.unitRole,
  );

  @override List<Object?> get props => [id, productId, uomId, conversionQty, unitRole];
}

// ─── Repository ────────────────────────────────────────────────────────────────
class ProductUomRepository {
  final DatabaseHelper _db;
  ProductUomRepository(this._db);

  /// Returns **sale** UOMs only — used by billing UOM picker.
  Future<List<ProductUom>> getUomsForProduct(int productId) async {
    final db = await _db.database;
    final rows = await db.query('product_uoms',
        where: "product_id = ? AND unit_role = 'sale'",
        whereArgs: [productId],
        orderBy: 'is_default DESC, conversion_qty ASC');
    return rows.map((r) => ProductUom.fromMap(r)).toList();
  }

  /// Returns **purchase** UOMs only — used by add/edit product page.
  Future<List<ProductUom>> getPurchaseUomsForProduct(int productId) async {
    final db = await _db.database;
    final rows = await db.query('product_uoms',
        where: "product_id = ? AND unit_role = 'purchase'",
        whereArgs: [productId],
        orderBy: 'is_default DESC, conversion_qty ASC');
    return rows.map((r) => ProductUom.fromMap(r)).toList();
  }

  Future<int> addUom(ProductUom uom) async {
    final db = await _db.database;
    if (uom.isDefault) {
      await db.update('product_uoms', {'is_default': 0},
          where: "product_id = ? AND unit_role = ?", whereArgs: [uom.productId, uom.unitRole]);
    }
    return await db.insert('product_uoms', uom.toMap());
  }

  Future<bool> updateUom(ProductUom uom) async {
    final db = await _db.database;
    if (uom.isDefault) {
      await db.update('product_uoms', {'is_default': 0},
          where: 'product_id = ? AND id != ? AND unit_role = ?',
          whereArgs: [uom.productId, uom.id, uom.unitRole]);
    }
    return (await db.update('product_uoms', uom.toMap(),
        where: 'id = ?', whereArgs: [uom.id])) > 0;
  }

  Future<bool> deleteUom(int id) async {
    final db = await _db.database;
    return (await db.delete('product_uoms', where: 'id = ?', whereArgs: [id])) > 0;
  }

  /// Saves [uoms] for a product, scoped to [unitRole].
  ///
  /// Only rows with matching [unitRole] are deleted and re-inserted,
  /// leaving the other role's rows untouched.
  Future<void> saveAllUoms(int productId, List<ProductUom> uoms,
      [String unitRole = 'sale']) async {
    // Guard against invalid role values
    assert(unitRole == 'sale' || unitRole == 'purchase',
        "unitRole must be 'sale' or 'purchase'");
    final safeRole = (unitRole == 'purchase') ? 'purchase' : 'sale';
    final db = await _db.database;
    await db.delete('product_uoms',
        where: 'product_id = ? AND unit_role = ?', whereArgs: [productId, safeRole]);
    for (int i = 0; i < uoms.length; i++) {
      final row = uoms[i]
          .copyWith(isDefault: i == 0, unitRole: safeRole)
          .toMap()
        ..['product_id'] = productId;
      await db.insert('product_uoms', row);
    }
  }
}