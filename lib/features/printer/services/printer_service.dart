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

      // Save last connected device
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

  // ── Print Bill ──────────────────────────────────────────────────────────────
  Future<bool> printBill(Bill bill) async {
    if (!isConnected) return false;

    try {
      final prefs = await SharedPreferences.getInstance();
      final shopName = prefs.getString('shop_name') ?? 'My Shop';
      final shopAddress = prefs.getString('shop_address') ?? '';
      final shopPhone = prefs.getString('shop_phone') ?? '';
      final thankYouMsg = prefs.getString('thank_you_msg') ?? 'Thank you for your visit!';

      // Header
      _printer.printCustom(shopName, 3, 1);          // Large, Center
      if (shopAddress.isNotEmpty) {
        _printer.printCustom(shopAddress, 1, 1);     // Small, Center
      }
      if (shopPhone.isNotEmpty) {
        _printer.printCustom('Ph: $shopPhone', 1, 1);
      }
      _printer.printNewLine();
      //_printer.print32Char('--------------------------------', '');
      _printer.printNewLine();

      // Bill info
      _printer.printLeftRight('Bill No:', bill.billNumber, 1);
      _printer.printLeftRight(
          'Date:', _formatDateTime(bill.createdAt), 1);
      _printer.printLeftRight('Payment:', bill.paymentMode.toUpperCase(), 1);
      if (bill.customerName != null && bill.customerName!.isNotEmpty) {
        _printer.printLeftRight('Customer:', bill.customerName!, 1);
      }
      _printer.printNewLine();
      _printer.printCustom('--------------------------------', 0,1);

      // Column header
      _printer.printCustom('Item            Qty  Price   Total', 1, 0);
      _printer.printCustom('--------------------------------', 0,1);

      // Items
      for (final item in bill.items) {
        final name = item.productName.length > 16
            ? item.productName.substring(0, 16)
            : item.productName.padRight(16);
        final qty = item.quantity.toStringAsFixed(item.quantity % 1 == 0 ? 0 : 1).padLeft(4);
        final price = CurrencyFormatter.short(item.unitPrice).padLeft(7);
        final total = CurrencyFormatter.short(item.totalPrice).padLeft(7);
        _printer.printCustom('$name$qty$price$total', 1, 0);
      }

      _printer.printCustom('--------------------------------', 0,1);
      _printer.printNewLine();

      // Totals
      if (bill.discountAmount > 0) {
        _printer.printLeftRight(
            'Discount:', '-${CurrencyFormatter.format(bill.discountAmount)}', 1);
      }
      _printer.printCustom(
          'TOTAL: ${CurrencyFormatter.format(bill.totalAmount)}', 2, 1);

      _printer.printNewLine();
    //  _printer.printCustom('================================', '');
      _printer.printNewLine();
      _printer.printCustom(thankYouMsg, 1, 1);
      _printer.printNewLine();
      _printer.printNewLine();
      _printer.printNewLine();

      // Cut paper
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
      _printer.printNewLine();
      _printer.paperCut();
      return true;
    } catch (e) {
      return false;
    }
  }

  String _formatDateTime(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

// ─── Printer Settings Page ────────────────────────────────────────────────────
// See: lib/features/printer/presentation/pages/printer_settings_page.dart
