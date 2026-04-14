/// GST Calculation Utility
/// Supports: 0%, 5%, 12%, 18%, 28% GST slabs
/// Handles inclusive (MRP includes GST) and exclusive (GST added on top)

class GstCalculator {
  // Standard GST slabs
  static const List<double> gstSlabs = [0.0, 5.0, 12.0, 18.0, 28.0];

  /// Calculate GST breakdown for a single item
  static GstResult calculate({
    required double baseAmount,   // amount before GST (if exclusive) or MRP (if inclusive)
    required double gstRate,      // e.g. 18.0 for 18%
    required bool isInclusive,    // true = price includes GST, false = GST added on top
    bool isInterState = false,    // true = IGST, false = CGST+SGST
  }) {
    if (gstRate <= 0) {
      return GstResult(
        taxableAmount: baseAmount,
        gstAmount: 0, cgst: 0, sgst: 0, igst: 0,
        totalAmount: baseAmount,
        gstRate: 0,
      );
    }

    double taxableAmount;
    double gstAmount;

    if (isInclusive) {
      // Price includes GST: taxable = price / (1 + rate/100)
      taxableAmount = baseAmount / (1 + gstRate / 100);
      gstAmount = baseAmount - taxableAmount;
    } else {
      // Price excludes GST: GST added on top
      taxableAmount = baseAmount;
      gstAmount = baseAmount * gstRate / 100;
    }

    double cgst = 0, sgst = 0, igst = 0;
    if (isInterState) {
      igst = gstAmount;
    } else {
      cgst = gstAmount / 2;
      sgst = gstAmount / 2;
    }

    return GstResult(
      taxableAmount: _round(taxableAmount),
      gstAmount: _round(gstAmount),
      cgst: _round(cgst),
      sgst: _round(sgst),
      igst: _round(igst),
      totalAmount: _round(taxableAmount + gstAmount),
      gstRate: gstRate,
    );
  }

  /// Calculate GST for a cart of items
  static CartGstResult calculateCart({
    required List<CartGstItem> items,
    bool isInterState = false,
  }) {
    double totalTaxable = 0;
    double totalGst = 0;
    double totalCgst = 0;
    double totalSgst = 0;
    double totalIgst = 0;

    final breakdown = <double, GstSlabBreakdown>{};

    for (final item in items) {
      final result = calculate(
        baseAmount: item.amount,
        gstRate: item.gstRate,
        isInclusive: item.isInclusive,
        isInterState: isInterState,
      );

      totalTaxable += result.taxableAmount;
      totalGst += result.gstAmount;
      totalCgst += result.cgst;
      totalSgst += result.sgst;
      totalIgst += result.igst;

      // Group by slab for invoice breakdown
      final slab = item.gstRate;
      if (breakdown.containsKey(slab)) {
        breakdown[slab] = breakdown[slab]!.add(result.taxableAmount, result.gstAmount);
      } else {
        breakdown[slab] = GstSlabBreakdown(
          rate: slab,
          taxableAmount: result.taxableAmount,
          gstAmount: result.gstAmount,
        );
      }
    }

    return CartGstResult(
      totalTaxable: _round(totalTaxable),
      totalGst: _round(totalGst),
      totalCgst: _round(totalCgst),
      totalSgst: _round(totalSgst),
      totalIgst: _round(totalIgst),
      slabBreakdown: breakdown.values.toList(),
    );
  }

  static double _round(double v) => double.parse(v.toStringAsFixed(2));
}

class GstResult {
  final double taxableAmount;
  final double gstAmount;
  final double cgst;
  final double sgst;
  final double igst;
  final double totalAmount;
  final double gstRate;

  const GstResult({
    required this.taxableAmount,
    required this.gstAmount,
    required this.cgst,
    required this.sgst,
    required this.igst,
    required this.totalAmount,
    required this.gstRate,
  });
}

class CartGstItem {
  final double amount;
  final double gstRate;
  final bool isInclusive;
  const CartGstItem({required this.amount, required this.gstRate, this.isInclusive = true});
}

class CartGstResult {
  final double totalTaxable;
  final double totalGst;
  final double totalCgst;
  final double totalSgst;
  final double totalIgst;
  final List<GstSlabBreakdown> slabBreakdown;

  const CartGstResult({
    required this.totalTaxable,
    required this.totalGst,
    required this.totalCgst,
    required this.totalSgst,
    required this.totalIgst,
    required this.slabBreakdown,
  });
}

class GstSlabBreakdown {
  final double rate;
  final double taxableAmount;
  final double gstAmount;
  const GstSlabBreakdown({required this.rate, required this.taxableAmount, required this.gstAmount});

  GstSlabBreakdown add(double taxable, double gst) => GstSlabBreakdown(
      rate: rate, taxableAmount: taxableAmount + taxable, gstAmount: gstAmount + gst);
}