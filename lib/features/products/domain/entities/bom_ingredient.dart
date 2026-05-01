import 'dart:convert';

/// Represents one ingredient line in a Bill of Materials (recipe).
class BomIngredient {
  final int? productId;
  final String productName;
  final double quantity;
  final String unit;
  final double unitCost;

  const BomIngredient({
    this.productId,
    required this.productName,
    required this.quantity,
    required this.unit,
    required this.unitCost,
  });

  double get totalCost => quantity * unitCost;

  Map<String, dynamic> toJson() => {
        'product_id': productId,
        'product_name': productName,
        'quantity': quantity,
        'unit': unit,
        'unit_cost': unitCost,
      };

  factory BomIngredient.fromJson(Map<String, dynamic> j) => BomIngredient(
        productId: j['product_id'] as int?,
        productName: j['product_name'] as String? ?? '',
        quantity: (j['quantity'] as num?)?.toDouble() ?? 0,
        unit: j['unit'] as String? ?? 'piece',
        unitCost: (j['unit_cost'] as num?)?.toDouble() ?? 0,
      );

  BomIngredient copyWith({
    int? productId,
    String? productName,
    double? quantity,
    String? unit,
    double? unitCost,
  }) =>
      BomIngredient(
        productId: productId ?? this.productId,
        productName: productName ?? this.productName,
        quantity: quantity ?? this.quantity,
        unit: unit ?? this.unit,
        unitCost: unitCost ?? this.unitCost,
      );

  /// Deserialises a list from the `attributes` JSON field.
  /// Expected shape: {"bom": [...]}
  static List<BomIngredient> listFromJson(String? jsonStr) {
    if (jsonStr == null || jsonStr.isEmpty) return [];
    try {
      final decoded = json.decode(jsonStr);
      if (decoded is! Map) return [];
      final list = decoded['bom'] as List?;
      if (list == null) return [];
      return list
          .map((e) => BomIngredient.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Serialises a list into the `attributes` JSON field.
  static String listToAttributesJson(List<BomIngredient> items) =>
      json.encode({'bom': items.map((e) => e.toJson()).toList()});
}
