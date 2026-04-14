import 'package:intl/intl.dart';

class CurrencyFormatter {
  static final NumberFormat _formatter = NumberFormat('#,##,##0.00', 'en_IN');
  static final NumberFormat _shortFormatter = NumberFormat('#,##,##0', 'en_IN');

  static String format(double amount) {
    return '₹${_formatter.format(amount)}';
  }

  static String short(double amount) {
    if (amount >= 1000) {
      return '₹${(amount / 1000).toStringAsFixed(1)}K';
    }
    return '₹${_shortFormatter.format(amount)}';
  }

  static String formatCompact(double amount) {
    if (amount >= 100000) return '₹${(amount / 100000).toStringAsFixed(1)}L';
    if (amount >= 1000) return '₹${(amount / 1000).toStringAsFixed(1)}K';
    return '₹${amount.toStringAsFixed(0)}';
  }
}