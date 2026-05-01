/// Bill template definitions for NammaNanban POS.
///
/// Five built-in templates cover the most common print scenarios:
///   1. Quick 58mm  — compact thermal receipt
///   2. Premium 80mm — clean 80mm thermal with GST summary
///   3. GST Invoice  — full GSTIN / HSN breakup on thermal
///   4. Restaurant / KOT — token-style kitchen bill
///   5. A4 PDF       — full-page invoice for PDF / WhatsApp share

enum BillTemplate {
  quick58mm,
  premium80mm,
  gstInvoice,
  restaurantKot,
  a4Pdf,
}

extension BillTemplateExt on BillTemplate {
  String get id => name;

  String get label {
    switch (this) {
      case BillTemplate.quick58mm:
        return 'Quick 58mm Receipt';
      case BillTemplate.premium80mm:
        return 'Premium 80mm Receipt';
      case BillTemplate.gstInvoice:
        return 'GST Detailed Invoice';
      case BillTemplate.restaurantKot:
        return 'Restaurant / KOT';
      case BillTemplate.a4Pdf:
        return 'A4 / WhatsApp PDF';
    }
  }

  String get description {
    switch (this) {
      case BillTemplate.quick58mm:
        return 'Compact layout for 58mm thermal printers';
      case BillTemplate.premium80mm:
        return 'Clean premium layout with GST & cashier info';
      case BillTemplate.gstInvoice:
        return 'Full GSTIN, HSN & CGST/SGST/IGST breakup';
      case BillTemplate.restaurantKot:
        return 'Token/order style for kitchen & restaurant';
      case BillTemplate.a4Pdf:
        return 'Full invoice for PDF sharing via WhatsApp';
    }
  }

  String get emoji {
    switch (this) {
      case BillTemplate.quick58mm:
        return '🧾';
      case BillTemplate.premium80mm:
        return '⭐';
      case BillTemplate.gstInvoice:
        return '📋';
      case BillTemplate.restaurantKot:
        return '🍽️';
      case BillTemplate.a4Pdf:
        return '📄';
    }
  }

  /// Paper size best suited for this template.
  String get defaultPaperSize {
    switch (this) {
      case BillTemplate.quick58mm:
        return '58mm';
      case BillTemplate.premium80mm:
        return '80mm';
      case BillTemplate.gstInvoice:
        return '80mm';
      case BillTemplate.restaurantKot:
        return '80mm';
      case BillTemplate.a4Pdf:
        return 'A4';
    }
  }

  bool get isPdf => this == BillTemplate.a4Pdf;
}

/// Persisted configuration for the bill template system.
class BillTemplateConfig {
  final BillTemplate template;
  final String paperSize; // '58mm' | '80mm' | 'A4'
  final bool showLogo;
  final bool showGst;
  final bool showHsn;
  final bool showDiscount;
  final String footerText;
  final bool autoPrint;
  final int copies;

  const BillTemplateConfig({
    this.template = BillTemplate.quick58mm,
    this.paperSize = '58mm',
    this.showLogo = true,
    this.showGst = true,
    this.showHsn = false,
    this.showDiscount = true,
    this.footerText = 'Thank you for your visit!',
    this.autoPrint = false,
    this.copies = 1,
  });

  BillTemplateConfig copyWith({
    BillTemplate? template,
    String? paperSize,
    bool? showLogo,
    bool? showGst,
    bool? showHsn,
    bool? showDiscount,
    String? footerText,
    bool? autoPrint,
    int? copies,
  }) =>
      BillTemplateConfig(
        template: template ?? this.template,
        paperSize: paperSize ?? this.paperSize,
        showLogo: showLogo ?? this.showLogo,
        showGst: showGst ?? this.showGst,
        showHsn: showHsn ?? this.showHsn,
        showDiscount: showDiscount ?? this.showDiscount,
        footerText: footerText ?? this.footerText,
        autoPrint: autoPrint ?? this.autoPrint,
        copies: copies ?? this.copies,
      );

  Map<String, dynamic> toMap() => {
        'template': template.id,
        'paper_size': paperSize,
        'show_logo': showLogo,
        'show_gst': showGst,
        'show_hsn': showHsn,
        'show_discount': showDiscount,
        'footer_text': footerText,
        'auto_print': autoPrint,
        'copies': copies,
      };

  factory BillTemplateConfig.fromMap(Map<String, dynamic> map) {
    BillTemplate tmpl = BillTemplate.quick58mm;
    try {
      tmpl = BillTemplate.values.firstWhere(
        (t) => t.id == (map['template'] as String? ?? ''),
        orElse: () => BillTemplate.quick58mm,
      );
    } catch (_) {}
    return BillTemplateConfig(
      template: tmpl,
      paperSize: map['paper_size'] as String? ?? '58mm',
      showLogo: (map['show_logo'] as bool?) ?? true,
      showGst: (map['show_gst'] as bool?) ?? true,
      showHsn: (map['show_hsn'] as bool?) ?? false,
      showDiscount: (map['show_discount'] as bool?) ?? true,
      footerText:
          map['footer_text'] as String? ?? 'Thank you for your visit!',
      autoPrint: (map['auto_print'] as bool?) ?? false,
      copies: (map['copies'] as int?) ?? 1,
    );
  }
}
