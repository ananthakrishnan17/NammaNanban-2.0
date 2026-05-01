import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/bill_template.dart';

/// Persists and loads [BillTemplateConfig] using [SharedPreferences].
///
/// All keys are namespaced under `bill_template_` to avoid clashes with
/// existing preferences such as `shop_name`, `shop_phone`, etc.
class PrinterSettingsRepository {
  static final PrinterSettingsRepository instance =
      PrinterSettingsRepository._();
  PrinterSettingsRepository._();

  static const String _kTemplate = 'bill_template_id';
  static const String _kPaperSize = 'bill_template_paper_size';
  static const String _kShowLogo = 'bill_template_show_logo';
  static const String _kShowGst = 'bill_template_show_gst';
  static const String _kShowHsn = 'bill_template_show_hsn';
  static const String _kShowDiscount = 'bill_template_show_discount';
  static const String _kFooterText = 'bill_template_footer_text';
  static const String _kAutoPrint = 'bill_template_auto_print';
  static const String _kCopies = 'bill_template_copies';

  /// Loads the saved config, returning defaults if nothing has been saved yet.
  Future<BillTemplateConfig> loadConfig() async {
    final prefs = await SharedPreferences.getInstance();
    final templateId = prefs.getString(_kTemplate);
    BillTemplate template = BillTemplate.quick58mm;
    if (templateId != null) {
      try {
        template = BillTemplate.values.firstWhere(
          (t) => t.id == templateId,
          orElse: () => BillTemplate.quick58mm,
        );
      } catch (_) {}
    }
    return BillTemplateConfig(
      template: template,
      paperSize: prefs.getString(_kPaperSize) ?? template.defaultPaperSize,
      showLogo: prefs.getBool(_kShowLogo) ?? true,
      showGst: prefs.getBool(_kShowGst) ?? true,
      showHsn: prefs.getBool(_kShowHsn) ?? false,
      showDiscount: prefs.getBool(_kShowDiscount) ?? true,
      footerText: prefs.getString(_kFooterText) ?? 'Thank you for your visit!',
      autoPrint: prefs.getBool(_kAutoPrint) ?? false,
      copies: prefs.getInt(_kCopies) ?? 1,
    );
  }

  /// Persists [config] to [SharedPreferences].
  Future<void> saveConfig(BillTemplateConfig config) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kTemplate, config.template.id);
    await prefs.setString(_kPaperSize, config.paperSize);
    await prefs.setBool(_kShowLogo, config.showLogo);
    await prefs.setBool(_kShowGst, config.showGst);
    await prefs.setBool(_kShowHsn, config.showHsn);
    await prefs.setBool(_kShowDiscount, config.showDiscount);
    await prefs.setString(_kFooterText, config.footerText);
    await prefs.setBool(_kAutoPrint, config.autoPrint);
    await prefs.setInt(_kCopies, config.copies);
  }
}
