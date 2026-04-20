import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../billing/domain/entities/bill.dart';
import '../../../core/utils/currency_formatter.dart';

class PrinterService {
  static final PrinterService instance = PrinterService._();
  PrinterService._();

  final BlueThermalPrinter _printer = BlueThermalPrinter.instance;
  BluetoothDevice? _connectedDevice;
  bool get isConnected => _connectedDevice != null;

  // ── Scan & Connect ──────────────────────────────────────────────────────────
  Future<List<BluetoothDevice>> scanDevices() async {
    try {
      final List<BluetoothDevice> devices = await _printer.getBondedDevices();
      return devices;
    } catch (e) {
      return [];
    }
  }

  Future<bool> connectDevice(BluetoothDevice device) async {
    try {
      await _printer.connect(device);
      _connectedDevice = device;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('last_printer', device.address ?? '');
      return true;
    } catch (e) {
      _connectedDevice = null;
      return false;
    }
  }

  Future<void> disconnect() async {
    try {
      await _printer.disconnect();
      _connectedDevice = null;
    } catch (_) {}
  }

  // ── Fixed-width column helper ───────────────────────────────────────────────
  // FIX: இந்த method alignment issue solve பண்றது.
  // ஒவ்வொரு column-உம் exact width-ல வரும் — overflow ஆனா truncate ஆகும்.
  String _col(String text, int width, {bool rightAlign = false}) {
    // Width-ஐ விட நீளமா இருந்தா truncate பண்ணு
    if (text.length > width) text = text.substring(0, width);
    // Right align or left align
    return rightAlign ? text.padLeft(width) : text.padRight(width);
  }

  // ── Print Bill ──────────────────────────────────────────────────────────────
  Future<bool> printBill(Bill bill) async {
    if (!isConnected) return false;

    try {
      final prefs = await SharedPreferences.getInstance();
      final shopName    = prefs.getString('shop_name')    ?? 'My Shop';
      final shopAddress = prefs.getString('shop_address') ?? '';
      final shopPhone   = prefs.getString('shop_phone')   ?? '';
      final thankYouMsg = prefs.getString('thank_you_msg') ?? 'Thank you for your visit!';

      // ── Header ──────────────────────────────────────────────────────────────
      _printer.printCustom(shopName, 3, 1);         // Large, Center
      if (shopAddress.isNotEmpty) {
        _printer.printCustom(shopAddress, 1, 1);    // Small, Center
      }
      if (shopPhone.isNotEmpty) {
        _printer.printCustom('Ph: $shopPhone', 1, 1);
      }
      _printer.printNewLine();
      _printer.printCustom('--------------------------------', 1, 1);
      _printer.printNewLine();

      // ── Bill Info ────────────────────────────────────────────────────────────
      _printer.printLeftRight('Bill No:', bill.billNumber, 1);
      _printer.printLeftRight('Date:', _formatDateTime(bill.createdAt), 1);

      if (bill.paymentMode == 'split' && bill.splitPaymentSummary != null) {
        _printer.printLeftRight('Payment:', 'Split', 1);
        _printer.printCustom(bill.splitPaymentSummary!, 1, 1);
      } else {
        _printer.printLeftRight('Payment:', bill.paymentMode.toUpperCase(), 1);
      }

      if (bill.customerName != null && bill.customerName!.isNotEmpty) {
        _printer.printLeftRight('Customer:', bill.customerName!, 1);
      }

      // GSTIN இருந்தா print பண்ணு (GST bill-க்கு useful)
      if (bill.customerGstin != null && bill.customerGstin!.isNotEmpty) {
        _printer.printLeftRight('GSTIN:', bill.customerGstin!, 1);
      }

      _printer.printNewLine();
      _printer.printCustom('--------------------------------', 1, 1);

      // ── Column Header ────────────────────────────────────────────────────────
      // FIX: Header-உம் data row-உம் same column width use பண்றோம்
      // Layout: Item(14) + Qty(4) + Price(7) + Total(7) = 32 chars
      final header =
          _col('Item',  14) +
          _col('Qty',    4, rightAlign: true) +
          _col('Price',  7, rightAlign: true) +
          _col('Total',  7, rightAlign: true);
      _printer.printCustom(header, 1, 0);
      _printer.printCustom('--------------------------------', 1, 1);

      // ── Items ────────────────────────────────────────────────────────────────
      for (final item in bill.items) {
        // FIX: _col() use பண்றோம் — CurrencyFormatter.short() எவ்வளோ
        // characters return பண்ணாலும் exact 7 chars-க்கு fit ஆகும்
        final qtyStr = item.quantity
            .toStringAsFixed(item.quantity % 1 == 0 ? 0 : 1);

        final line =
            _col(item.productName,              14) +
            _col(qtyStr,                         4, rightAlign: true) +
            _col(CurrencyFormatter.short(item.unitPrice),  7, rightAlign: true) +
            _col(CurrencyFormatter.short(item.totalPrice), 7, rightAlign: true);

        _printer.printCustom(line, 1, 0);

        // Product name 14 chars-ஐ விட நீளமா இருந்தா second line-ல மீதி print பண்ணு
        // (truncate பண்றதை விட இது user-friendly)
        if (item.productName.length > 14) {
          final overflow = item.productName.substring(14);
          _printer.printCustom('  $overflow', 1, 0);
        }

        // GST amount இருந்தா sub-line-ல காட்டு
        if (item.gstRate > 0 && item.gstAmount > 0) {
          final gstLine =
              _col('  GST ${item.gstRate.toStringAsFixed(0)}%', 18) +
              _col(CurrencyFormatter.short(item.gstAmount), 14, rightAlign: true);
          _printer.printCustom(gstLine, 1, 0);
        }
      }

      _printer.printCustom('--------------------------------', 1, 1);
      _printer.printNewLine();

      // ── Totals ───────────────────────────────────────────────────────────────
      // Subtotal (discount இருந்தா மட்டும் காட்டு)
      if (bill.discountAmount > 0) {
        _printer.printLeftRight(
          'Subtotal:', CurrencyFormatter.format(bill.totalAmount + bill.discountAmount), 1);
        _printer.printLeftRight(
          'Discount:', '-${CurrencyFormatter.format(bill.discountAmount)}', 1);
      }

      // GST breakdown இருந்தா காட்டு
      if (bill.gstTotal > 0) {
        _printer.printLeftRight(
          'CGST:', CurrencyFormatter.format(bill.cgstTotal), 1);
        _printer.printLeftRight(
          'SGST:', CurrencyFormatter.format(bill.sgstTotal), 1);
      }

      // Grand Total — bold + large
      _printer.printCustom(
        'TOTAL: ${CurrencyFormatter.format(bill.totalAmount)}', 2, 1);

      _printer.printNewLine();
      _printer.printCustom('--------------------------------', 1, 1);
      _printer.printNewLine();
      _printer.printCustom(thankYouMsg, 1, 1);
      _printer.printNewLine();
      _printer.printNewLine();
      _printer.printNewLine();

      // Paper cut
      _printer.paperCut();
      return true;
    } catch (e) {
      return false;
    }
  }

  // ── Test Print ──────────────────────────────────────────────────────────────
  Future<bool> testPrint() async {
    if (!isConnected) return false;
    try {
      _printer.printCustom('=== TEST PRINT ===', 2, 1);
      _printer.printCustom('Printer is working!', 1, 1);
      _printer.printCustom(DateTime.now().toString(), 1, 1);
      _printer.printNewLine();

      // Alignment test — இந்த lines straight-ஆ வந்தா சரியா இருக்கு
      _printer.printCustom('--------------------------------', 1, 1);
      _printer.printCustom(
        _col('Item', 14) +
        _col('Qty',   4, rightAlign: true) +
        _col('Price', 7, rightAlign: true) +
        _col('Total', 7, rightAlign: true),
        1, 0,
      );
      _printer.printCustom('--------------------------------', 1, 1);
      _printer.printCustom(
        _col('Milk Packet', 14) +
        _col('2',    4, rightAlign: true) +
        _col('25',   7, rightAlign: true) +
        _col('50',   7, rightAlign: true),
        1, 0,
      );
      _printer.printCustom(
        _col('Basmati Rice 5kg', 14) +
        _col('1',    4, rightAlign: true) +
        _col('499',  7, rightAlign: true) +
        _col('499',  7, rightAlign: true),
        1, 0,
      );
      _printer.printCustom('--------------------------------', 1, 1);
      _printer.printCustom('TOTAL: 549', 2, 1);

      _printer.printNewLine();
      _printer.printNewLine();
      _printer.paperCut();
      return true;
    } catch (e) {
      return false;
    }
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────
  String _formatDateTime(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/'
        '${dt.month.toString().padLeft(2, '0')}/'
        '${dt.year} '
        '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}';
  }
}

// ─── Printer Settings Page ────────────────────────────────────────────────────
// See: lib/features/printer/presentation/pages/printer_settings_page.dart
