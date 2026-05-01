import 'dart:io';

import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';

import '../../../../core/utils/currency_formatter.dart';
import '../../billing/domain/entities/bill.dart';
import '../domain/entities/bill_template.dart';

/// Renders a [Bill] to either a thermal ESC/POS stream or a PDF document,
/// based on the active [BillTemplateConfig].
///
/// Thermal templates (1–4) write directly to [BlueThermalPrinter].
/// PDF template (5) builds a [pw.Document] and surfaces it via the
/// [printing] plugin or shares it via [share_plus].
class BillTemplateRenderer {
  BillTemplateRenderer._();

  // ── Column widths (characters) ─────────────────────────────────────────────
  static const int _w58 = 32; // 58mm printer character width
  static const int _w80 = 48; // 80mm printer character width

  // ══════════════════════════════════════════════════════════════════════════
  // Thermal print entry point
  // ══════════════════════════════════════════════════════════════════════════

  /// Sends the bill to the [printer] using the style dictated by [config].
  /// Returns `true` on success.
  static Future<bool> printThermal({
    required BlueThermalPrinter printer,
    required Bill bill,
    required BillTemplateConfig config,
    required String shopName,
    required String shopAddress,
    required String shopPhone,
    String? shopGstin,
    String? cashierName,
  }) async {
    try {
      final int copies = config.copies.clamp(1, 5);
      for (int c = 0; c < copies; c++) {
        switch (config.template) {
          case BillTemplate.quick58mm:
            await _printQuick58mm(
              printer: printer,
              bill: bill,
              config: config,
              shopName: shopName,
              shopAddress: shopAddress,
              shopPhone: shopPhone,
            );
          case BillTemplate.premium80mm:
            await _printPremium80mm(
              printer: printer,
              bill: bill,
              config: config,
              shopName: shopName,
              shopAddress: shopAddress,
              shopPhone: shopPhone,
              cashierName: cashierName,
            );
          case BillTemplate.gstInvoice:
            await _printGstInvoice(
              printer: printer,
              bill: bill,
              config: config,
              shopName: shopName,
              shopAddress: shopAddress,
              shopPhone: shopPhone,
              shopGstin: shopGstin,
            );
          case BillTemplate.restaurantKot:
            await _printRestaurantKot(
              printer: printer,
              bill: bill,
              config: config,
              shopName: shopName,
            );
          case BillTemplate.a4Pdf:
            // A4 template should not reach the thermal path.
            break;
        }
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // Template 1 — Quick 58mm Receipt
  // ══════════════════════════════════════════════════════════════════════════
  static Future<void> _printQuick58mm({
    required BlueThermalPrinter printer,
    required Bill bill,
    required BillTemplateConfig config,
    required String shopName,
    required String shopAddress,
    required String shopPhone,
  }) async {
    const int w = _w58;
    final div = '-' * w;

    printer.printCustom(shopName, 3, 1);
    if (shopAddress.isNotEmpty) printer.printCustom(shopAddress, 1, 1);
    if (shopPhone.isNotEmpty) printer.printCustom('Ph: $shopPhone', 1, 1);
    printer.printNewLine();
    printer.printCustom(div, 1, 1);

    printer.printLeftRight('Bill No:', bill.billNumber, 1);
    printer.printLeftRight('Date:', _fmtDt(bill.createdAt), 1);
    if (bill.customerName != null && bill.customerName!.isNotEmpty) {
      printer.printLeftRight('Customer:', bill.customerName!, 1);
    }
    printer.printLeftRight(
      'Payment:',
      bill.paymentMode == 'split'
          ? 'Split'
          : bill.paymentMode.toUpperCase(),
      1,
    );
    if (bill.paymentMode == 'split' && bill.splitPaymentSummary != null) {
      printer.printCustom(bill.splitPaymentSummary!, 1, 1);
    }
    printer.printNewLine();
    printer.printCustom(div, 1, 1);

    // Header: Item(14) Qty(4) Price(7) Total(7)
    printer.printCustom(
      _col('Item', 14) +
          _col('Qty', 4, right: true) +
          _col('Price', 7, right: true) +
          _col('Total', 7, right: true),
      1,
      0,
    );
    printer.printCustom(div, 1, 1);

    for (final item in bill.items) {
      final qtyStr = _fmtQty(item.quantity);
      printer.printCustom(
        _col(item.productName, 14) +
            _col(qtyStr, 4, right: true) +
            _col(CurrencyFormatter.short(item.unitPrice), 7, right: true) +
            _col(CurrencyFormatter.short(item.totalPrice), 7, right: true),
        1,
        0,
      );
      if (item.productName.length > 14) {
        printer.printCustom('  ${item.productName.substring(14)}', 1, 0);
      }
      if (config.showGst && item.gstRate > 0 && item.gstAmount > 0) {
        printer.printCustom(
          _col('  GST ${item.gstRate.toStringAsFixed(0)}%', 18) +
              _col(CurrencyFormatter.short(item.gstAmount), 14, right: true),
          1,
          0,
        );
      }
    }
    printer.printCustom(div, 1, 1);

    if (config.showDiscount && bill.discountAmount > 0) {
      printer.printLeftRight(
        'Subtotal:',
        CurrencyFormatter.format(bill.totalAmount + bill.discountAmount),
        1,
      );
      printer.printLeftRight(
        'Discount:',
        '-${CurrencyFormatter.format(bill.discountAmount)}',
        1,
      );
    }
    if (config.showGst && bill.gstTotal > 0) {
      printer.printLeftRight(
          'CGST:', CurrencyFormatter.format(bill.cgstTotal), 1);
      printer.printLeftRight(
          'SGST:', CurrencyFormatter.format(bill.sgstTotal), 1);
    }

    printer.printCustom(
      'TOTAL: ${CurrencyFormatter.format(bill.totalAmount)}',
      2,
      1,
    );

    printer.printNewLine();
    printer.printCustom(div, 1, 1);
    printer.printNewLine();
    if (config.footerText.isNotEmpty) {
      printer.printCustom(config.footerText, 1, 1);
    }
    printer.printNewLine();
    printer.printNewLine();
    printer.printNewLine();
    printer.paperCut();
  }

  // ══════════════════════════════════════════════════════════════════════════
  // Template 2 — Premium 80mm Receipt
  // ══════════════════════════════════════════════════════════════════════════
  static Future<void> _printPremium80mm({
    required BlueThermalPrinter printer,
    required Bill bill,
    required BillTemplateConfig config,
    required String shopName,
    required String shopAddress,
    required String shopPhone,
    String? cashierName,
  }) async {
    const int w = _w80;
    final div = '=' * w;
    final thin = '-' * w;

    printer.printCustom(shopName, 3, 1);
    if (shopAddress.isNotEmpty) printer.printCustom(shopAddress, 1, 1);
    if (shopPhone.isNotEmpty) printer.printCustom('Ph: $shopPhone', 1, 1);
    printer.printNewLine();
    printer.printCustom(div, 1, 1);

    printer.printLeftRight('Invoice No :', bill.billNumber, 1);
    printer.printLeftRight(
        'Date       :', _fmtDt(bill.createdAt), 1);
    printer.printLeftRight(
      'Payment    :',
      bill.paymentMode == 'split'
          ? 'Split'
          : bill.paymentMode.toUpperCase(),
      1,
    );
    if (bill.paymentMode == 'split' && bill.splitPaymentSummary != null) {
      printer.printCustom('  ${bill.splitPaymentSummary}', 1, 0);
    }
    if (bill.customerName != null && bill.customerName!.isNotEmpty) {
      printer.printLeftRight('Customer   :', bill.customerName!, 1);
    }
    if (bill.customerGstin != null && bill.customerGstin!.isNotEmpty) {
      printer.printLeftRight('GSTIN      :', bill.customerGstin!, 1);
    }
    if (cashierName != null && cashierName.isNotEmpty) {
      printer.printLeftRight('Cashier    :', cashierName, 1);
    }
    printer.printNewLine();
    printer.printCustom(div, 1, 1);

    // Header: Item(22) Qty(5) Price(9) Total(9) on 80mm = 45 chars
    printer.printCustom(
      _col('Item', 22) +
          _col('Qty', 5, right: true) +
          _col('Price', 9, right: true) +
          _col('Total', 9, right: true),
      1,
      0,
    );
    printer.printCustom(thin, 1, 1);

    for (final item in bill.items) {
      final qtyStr = _fmtQty(item.quantity);
      printer.printCustom(
        _col(item.productName, 22) +
            _col(qtyStr, 5, right: true) +
            _col(CurrencyFormatter.short(item.unitPrice), 9, right: true) +
            _col(CurrencyFormatter.short(item.totalPrice), 9, right: true),
        1,
        0,
      );
      if (item.productName.length > 22) {
        printer.printCustom('  ${item.productName.substring(22)}', 1, 0);
      }
      if (config.showHsn) {
        // HSN code not in BillItem entity — omit per-item HSN for now
      }
      if (config.showGst && item.gstRate > 0 && item.gstAmount > 0) {
        printer.printCustom(
          '  ${_col("GST ${item.gstRate.toStringAsFixed(0)}%", 20)}'
          '${_col(CurrencyFormatter.short(item.gstAmount), 25, right: true)}',
          1,
          0,
        );
      }
    }
    printer.printCustom(div, 1, 1);

    final subtotal = config.showDiscount && bill.discountAmount > 0
        ? bill.totalAmount + bill.discountAmount
        : bill.totalAmount;
    printer.printLeftRight(
        'Subtotal:', CurrencyFormatter.format(subtotal), 1);
    if (config.showDiscount && bill.discountAmount > 0) {
      printer.printLeftRight(
          'Discount:', '-${CurrencyFormatter.format(bill.discountAmount)}', 1);
    }
    if (config.showGst && bill.gstTotal > 0) {
      printer.printLeftRight(
          'CGST:', CurrencyFormatter.format(bill.cgstTotal), 1);
      printer.printLeftRight(
          'SGST:', CurrencyFormatter.format(bill.sgstTotal), 1);
      if (bill.igstTotal > 0) {
        printer.printLeftRight(
            'IGST:', CurrencyFormatter.format(bill.igstTotal), 1);
      }
      printer.printLeftRight(
          'GST Total:', CurrencyFormatter.format(bill.gstTotal), 1);
    }
    printer.printCustom(
      'GRAND TOTAL: ${CurrencyFormatter.format(bill.totalAmount)}',
      2,
      1,
    );

    printer.printNewLine();
    printer.printCustom(div, 1, 1);
    printer.printNewLine();
    if (config.footerText.isNotEmpty) {
      printer.printCustom(config.footerText, 1, 1);
    }
    printer.printNewLine();
    printer.printNewLine();
    printer.printNewLine();
    printer.paperCut();
  }

  // ══════════════════════════════════════════════════════════════════════════
  // Template 3 — GST Detailed Invoice
  // ══════════════════════════════════════════════════════════════════════════
  static Future<void> _printGstInvoice({
    required BlueThermalPrinter printer,
    required Bill bill,
    required BillTemplateConfig config,
    required String shopName,
    required String shopAddress,
    required String shopPhone,
    String? shopGstin,
  }) async {
    const int w = _w80;
    final div = '=' * w;
    final thin = '-' * w;

    printer.printCustom('TAX INVOICE', 2, 1);
    printer.printNewLine();
    printer.printCustom(shopName, 3, 1);
    if (shopAddress.isNotEmpty) printer.printCustom(shopAddress, 1, 1);
    if (shopPhone.isNotEmpty) printer.printCustom('Ph: $shopPhone', 1, 1);
    if (shopGstin != null && shopGstin.isNotEmpty) {
      printer.printCustom('GSTIN: $shopGstin', 1, 1);
    }
    printer.printNewLine();
    printer.printCustom(div, 1, 1);

    printer.printLeftRight('Invoice No :', bill.billNumber, 1);
    printer.printLeftRight('Date       :', _fmtDt(bill.createdAt), 1);
    printer.printLeftRight(
      'Payment    :',
      bill.paymentMode == 'split'
          ? 'Split'
          : bill.paymentMode.toUpperCase(),
      1,
    );
    if (bill.customerName != null && bill.customerName!.isNotEmpty) {
      printer.printCustom(thin, 1, 1);
      printer.printCustom('Bill To:', 1, 0);
      printer.printCustom(bill.customerName!, 1, 0);
      if (bill.customerAddress != null && bill.customerAddress!.isNotEmpty) {
        printer.printCustom(bill.customerAddress!, 1, 0);
      }
      if (bill.customerGstin != null && bill.customerGstin!.isNotEmpty) {
        printer.printCustom('GSTIN: ${bill.customerGstin}', 1, 0);
      }
    }
    printer.printNewLine();
    printer.printCustom(div, 1, 1);

    // Header: Item(18) Taxable(9) GST%(5) CGST(8) SGST(8) = 48
    printer.printCustom(
      _col('Item', 18) +
          _col('Taxable', 9, right: true) +
          _col('GST%', 5, right: true) +
          _col('CGST', 8, right: true) +
          _col('SGST', 8, right: true),
      1,
      0,
    );
    printer.printCustom(thin, 1, 1);

    for (final item in bill.items) {
      // Taxable amount = total price excl. GST
      final gstAmt = item.gstAmount;
      final taxable = item.totalPrice - gstAmt;
      final halfGst = gstAmt / 2;

      printer.printCustom(
        _col(item.productName, 18) +
            _col(CurrencyFormatter.short(taxable), 9, right: true) +
            _col('${item.gstRate.toStringAsFixed(0)}%', 5, right: true) +
            _col(CurrencyFormatter.short(halfGst), 8, right: true) +
            _col(CurrencyFormatter.short(halfGst), 8, right: true),
        1,
        0,
      );
      if (item.productName.length > 18) {
        printer.printCustom('  ${item.productName.substring(18)}', 1, 0);
      }
    }
    printer.printCustom(div, 1, 1);

    final taxable = bill.totalAmount - bill.gstTotal;
    printer.printLeftRight(
        'Taxable Amount:', CurrencyFormatter.format(taxable), 1);
    printer.printLeftRight(
        'CGST:', CurrencyFormatter.format(bill.cgstTotal), 1);
    printer.printLeftRight(
        'SGST:', CurrencyFormatter.format(bill.sgstTotal), 1);
    if (bill.igstTotal > 0) {
      printer.printLeftRight(
          'IGST:', CurrencyFormatter.format(bill.igstTotal), 1);
    }
    printer.printLeftRight(
        'Total Tax:', CurrencyFormatter.format(bill.gstTotal), 1);
    if (config.showDiscount && bill.discountAmount > 0) {
      printer.printLeftRight(
          'Discount:', '-${CurrencyFormatter.format(bill.discountAmount)}', 1);
    }
    printer.printCustom(
      'GRAND TOTAL: ${CurrencyFormatter.format(bill.totalAmount)}',
      2,
      1,
    );

    printer.printNewLine();
    printer.printCustom(div, 1, 1);
    printer.printNewLine();
    if (config.footerText.isNotEmpty) {
      printer.printCustom(config.footerText, 1, 1);
    }
    printer.printCustom('(Signature)', 1, 2); // right-align
    printer.printNewLine();
    printer.printNewLine();
    printer.printNewLine();
    printer.paperCut();
  }

  // ══════════════════════════════════════════════════════════════════════════
  // Template 4 — Restaurant / KOT Style
  // ══════════════════════════════════════════════════════════════════════════
  static Future<void> _printRestaurantKot({
    required BlueThermalPrinter printer,
    required Bill bill,
    required BillTemplateConfig config,
    required String shopName,
  }) async {
    const int w = _w80;
    final div = '*' * w;

    printer.printCustom(shopName, 3, 1);
    printer.printCustom(div, 1, 1);
    printer.printCustom('ORDER BILL', 2, 1);
    printer.printNewLine();
    printer.printLeftRight('Token No :', bill.billNumber, 1);
    printer.printLeftRight('Time     :', _fmtDt(bill.createdAt), 1);
    if (bill.customerName != null && bill.customerName!.isNotEmpty) {
      printer.printLeftRight('Name     :', bill.customerName!, 1);
    }
    printer.printCustom(div, 1, 1);

    for (final item in bill.items) {
      // Large item names on full width
      printer.printCustom(item.productName, 2, 0);
      printer.printLeftRight(
        '  x ${_fmtQty(item.quantity)} ${item.unit}',
        CurrencyFormatter.format(item.totalPrice),
        1,
      );
      printer.printNewLine();
    }

    printer.printCustom(div, 1, 1);
    if (config.showDiscount && bill.discountAmount > 0) {
      printer.printLeftRight(
          'Discount:', '-${CurrencyFormatter.format(bill.discountAmount)}', 1);
    }
    printer.printCustom(
      'TOTAL: ${CurrencyFormatter.format(bill.totalAmount)}',
      2,
      1,
    );
    printer.printLeftRight(
      'Payment:',
      bill.paymentMode == 'split'
          ? 'Split'
          : bill.paymentMode.toUpperCase(),
      1,
    );
    printer.printNewLine();
    printer.printCustom(div, 1, 1);
    printer.printNewLine();
    if (config.footerText.isNotEmpty) {
      printer.printCustom(config.footerText, 1, 1);
    }
    printer.printNewLine();
    printer.printNewLine();
    printer.printNewLine();
    printer.paperCut();
  }

  // ══════════════════════════════════════════════════════════════════════════
  // Template 5 — A4 / WhatsApp PDF Invoice
  // ══════════════════════════════════════════════════════════════════════════

  /// Builds and shares a PDF invoice.  Returns `true` on success.
  static Future<bool> sharePdf({
    required Bill bill,
    required BillTemplateConfig config,
    required String shopName,
    required String shopAddress,
    required String shopPhone,
    String? shopGstin,
  }) async {
    try {
      final doc = await buildPdfDocument(
        bill: bill,
        config: config,
        shopName: shopName,
        shopAddress: shopAddress,
        shopPhone: shopPhone,
        shopGstin: shopGstin,
      );
      final bytes = await doc.save();
      final dir = await getTemporaryDirectory();
      final file = File(
          '${dir.path}/Invoice_${bill.billNumber.replaceAll(RegExp(r'[/:]'), '-')}.pdf');
      await file.writeAsBytes(bytes);
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Invoice #${bill.billNumber} from $shopName',
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Sends the PDF directly to a system / AirPrint printer.
  static Future<bool> printPdf({
    required Bill bill,
    required BillTemplateConfig config,
    required String shopName,
    required String shopAddress,
    required String shopPhone,
    String? shopGstin,
  }) async {
    try {
      final doc = await buildPdfDocument(
        bill: bill,
        config: config,
        shopName: shopName,
        shopAddress: shopAddress,
        shopPhone: shopPhone,
        shopGstin: shopGstin,
      );
      await Printing.layoutPdf(onLayout: (_) async => doc.save());
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Builds the [pw.Document] for Template 5.
  static Future<pw.Document> buildPdfDocument({
    required Bill bill,
    required BillTemplateConfig config,
    required String shopName,
    required String shopAddress,
    required String shopPhone,
    String? shopGstin,
  }) async {
    final doc = pw.Document();

    // Try to load a font that supports Tamil/Devanagari — fall back to Helvetica
    pw.Font? baseFont;
    try {
      final fontData = await rootBundle.load('assets/fonts/Poppins-Regular.ttf');
      baseFont = pw.Font.ttf(fontData);
    } catch (_) {}

    final textStyle = pw.TextStyle(font: baseFont, fontSize: 10);
    final boldStyle =
        pw.TextStyle(font: baseFont, fontSize: 10, fontWeight: pw.FontWeight.bold);
    final headStyle =
        pw.TextStyle(font: baseFont, fontSize: 14, fontWeight: pw.FontWeight.bold);

    final dateStr =
        DateFormat('dd MMM yyyy, hh:mm a').format(bill.createdAt);

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (ctx) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // ── Header ─────────────────────────────────────────────────
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(shopName, style: headStyle),
                      if (shopAddress.isNotEmpty)
                        pw.Text(shopAddress, style: textStyle),
                      if (shopPhone.isNotEmpty)
                        pw.Text('Ph: $shopPhone', style: textStyle),
                      if (shopGstin != null && shopGstin.isNotEmpty)
                        pw.Text('GSTIN: $shopGstin', style: textStyle),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('TAX INVOICE', style: headStyle),
                      pw.Text('Bill No: ${bill.billNumber}',
                          style: boldStyle),
                      pw.Text('Date: $dateStr', style: textStyle),
                      pw.Text(
                        'Payment: ${bill.paymentMode == "split" ? "Split" : bill.paymentMode.toUpperCase()}',
                        style: textStyle,
                      ),
                    ],
                  ),
                ],
              ),

              pw.Divider(height: 16),

              // ── Customer Section ────────────────────────────────────────
              if (bill.customerName != null &&
                  bill.customerName!.isNotEmpty) ...[
                pw.Text('Bill To:', style: boldStyle),
                pw.Text(bill.customerName!, style: textStyle),
                if (bill.customerAddress != null &&
                    bill.customerAddress!.isNotEmpty)
                  pw.Text(bill.customerAddress!, style: textStyle),
                if (bill.customerGstin != null &&
                    bill.customerGstin!.isNotEmpty)
                  pw.Text('GSTIN: ${bill.customerGstin}', style: textStyle),
                pw.SizedBox(height: 8),
              ],

              // ── Items Table ─────────────────────────────────────────────
              pw.TableHelper.fromTextArray(
                headers: [
                  '#',
                  'Item',
                  'Qty',
                  'Unit',
                  'Rate',
                  if (config.showGst) 'GST%',
                  if (config.showGst) 'GST Amt',
                  'Total',
                ],
                data: [
                  for (int i = 0; i < bill.items.length; i++)
                    _pdfItemRow(bill.items[i], i + 1, config),
                ],
                headerStyle: boldStyle,
                cellStyle: textStyle,
                headerDecoration:
                    const pw.BoxDecoration(color: PdfColors.grey300),
                cellAlignment: pw.Alignment.centerRight,
                columnWidths: config.showGst
                    ? {
                        0: const pw.FixedColumnWidth(20),
                        1: const pw.FlexColumnWidth(3),
                        2: const pw.FixedColumnWidth(35),
                        3: const pw.FixedColumnWidth(35),
                        4: const pw.FixedColumnWidth(50),
                        5: const pw.FixedColumnWidth(30),
                        6: const pw.FixedColumnWidth(50),
                        7: const pw.FixedColumnWidth(60),
                      }
                    : {
                        0: const pw.FixedColumnWidth(20),
                        1: const pw.FlexColumnWidth(3),
                        2: const pw.FixedColumnWidth(35),
                        3: const pw.FixedColumnWidth(35),
                        4: const pw.FixedColumnWidth(60),
                        5: const pw.FixedColumnWidth(70),
                      },
                border: pw.TableBorder.all(width: 0.5),
              ),

              pw.SizedBox(height: 8),

              // ── Totals ──────────────────────────────────────────────────
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      if (config.showDiscount && bill.discountAmount > 0) ...[
                        _pdfTotalRow(
                          'Subtotal:',
                          CurrencyFormatter.format(
                              bill.totalAmount + bill.discountAmount),
                          textStyle,
                        ),
                        _pdfTotalRow(
                          'Discount:',
                          '-${CurrencyFormatter.format(bill.discountAmount)}',
                          textStyle,
                        ),
                      ],
                      if (config.showGst && bill.gstTotal > 0) ...[
                        _pdfTotalRow(
                            'CGST:',
                            CurrencyFormatter.format(bill.cgstTotal),
                            textStyle),
                        _pdfTotalRow(
                            'SGST:',
                            CurrencyFormatter.format(bill.sgstTotal),
                            textStyle),
                        if (bill.igstTotal > 0)
                          _pdfTotalRow(
                              'IGST:',
                              CurrencyFormatter.format(bill.igstTotal),
                              textStyle),
                        _pdfTotalRow(
                            'Total Tax:',
                            CurrencyFormatter.format(bill.gstTotal),
                            textStyle),
                      ],
                      pw.Divider(height: 6),
                      _pdfTotalRow(
                        'GRAND TOTAL:',
                        CurrencyFormatter.format(bill.totalAmount),
                        boldStyle,
                      ),
                    ],
                  ),
                ],
              ),

              pw.Spacer(),

              // ── Footer ──────────────────────────────────────────────────
              pw.Divider(),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(config.footerText, style: textStyle),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.SizedBox(height: 24),
                      pw.Text('_____________________', style: textStyle),
                      pw.Text('Authorised Signatory', style: textStyle),
                    ],
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );

    return doc;
  }

  // ── PDF helpers ────────────────────────────────────────────────────────────

  static List<String> _pdfItemRow(
      BillItem item, int idx, BillTemplateConfig config) {
    return [
      '$idx',
      item.productName,
      _fmtQty(item.quantity),
      item.unit,
      CurrencyFormatter.format(item.unitPrice),
      if (config.showGst) '${item.gstRate.toStringAsFixed(0)}%',
      if (config.showGst) CurrencyFormatter.format(item.gstAmount),
      CurrencyFormatter.format(item.totalPrice),
    ];
  }

  static pw.Widget _pdfTotalRow(
      String label, String value, pw.TextStyle style) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.end,
      children: [
        pw.SizedBox(
          width: 120,
          child: pw.Text(label, style: style, textAlign: pw.TextAlign.right),
        ),
        pw.SizedBox(width: 8),
        pw.SizedBox(
          width: 80,
          child: pw.Text(value, style: style, textAlign: pw.TextAlign.right),
        ),
      ],
    );
  }

  // ── Shared helpers ─────────────────────────────────────────────────────────

  /// Fixed-width column helper for thermal output.
  static String _col(String text, int width, {bool right = false}) {
    if (text.length > width) text = text.substring(0, width);
    return right ? text.padLeft(width) : text.padRight(width);
  }

  static String _fmtDt(DateTime dt) =>
      '${dt.day.toString().padLeft(2, '0')}/'
      '${dt.month.toString().padLeft(2, '0')}/'
      '${dt.year} '
      '${dt.hour.toString().padLeft(2, '0')}:'
      '${dt.minute.toString().padLeft(2, '0')}';

  static String _fmtQty(double qty) =>
      qty % 1 == 0 ? qty.toInt().toString() : qty.toStringAsFixed(1);
}
