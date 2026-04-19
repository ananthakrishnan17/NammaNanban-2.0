class StockDisplayHelper {
  /// Given stock in retail units (e.g., 80 kg) and conversion (22 kg/bag),
  /// returns a display string like "3 bags 14 kg"
  static String formatMixedStock({
    required double stockRetailQty,
    required double wholesaleToRetailQty,
    required String wholesaleUnit,
    required String retailUnit,
  }) {
    if (wholesaleToRetailQty <= 1.0) {
      return '${stockRetailQty.toStringAsFixed(1)} $retailUnit';
    }
    final wholeBags = (stockRetailQty / wholesaleToRetailQty).floor();
    final remainingRetail = stockRetailQty - (wholeBags * wholesaleToRetailQty);
    if (wholeBags == 0) return '${remainingRetail.toStringAsFixed(1)} $retailUnit';
    if (remainingRetail < 0.01) return '$wholeBags ${wholesaleUnit}s';
    return '$wholeBags ${wholesaleUnit}s ${remainingRetail.toStringAsFixed(1)} $retailUnit';
  }
}
