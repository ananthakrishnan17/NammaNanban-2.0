import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class PdfExportHelper {
  static Future<void> exportAndShare({
    required String title,
    required List<String> headers,
    required List<List<String>> rows,
    Map<String, String>? summary,
  }) async {
    final doc = pw.Document();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        header: (ctx) => pw.Text(title,
            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
        build: (ctx) {
          final widgets = <pw.Widget>[];

          if (summary != null && summary.isNotEmpty) {
            widgets.add(pw.SizedBox(height: 12));
            widgets.add(pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.orange),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: summary.entries
                    .map((e) => pw.Text('${e.key}: ${e.value}',
                        style: const pw.TextStyle(fontSize: 10)))
                    .toList(),
              ),
            ));
            widgets.add(pw.SizedBox(height: 12));
          }

          if (rows.isEmpty) {
            widgets.add(pw.Text('No data available.',
                style: const pw.TextStyle(fontSize: 12)));
          } else {
            widgets.add(
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey400),
                columnWidths: {
                  for (int i = 0; i < headers.length; i++)
                    i: const pw.FlexColumnWidth()
                },
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.orange100),
                    children: headers
                        .map((h) => pw.Padding(
                              padding: const pw.EdgeInsets.all(6),
                              child: pw.Text(h,
                                  style: pw.TextStyle(
                                      fontSize: 9,
                                      fontWeight: pw.FontWeight.bold)),
                            ))
                        .toList(),
                  ),
                  ...rows.map((row) => pw.TableRow(
                        children: row
                            .map((cell) => pw.Padding(
                                  padding: const pw.EdgeInsets.all(6),
                                  child: pw.Text(cell,
                                      style: const pw.TextStyle(fontSize: 9)),
                                ))
                            .toList(),
                      )),
                ],
              ),
            );
          }
          return widgets;
        },
      ),
    );

    await Printing.sharePdf(
        bytes: await doc.save(), filename: '${title.replaceAll(' ', '_')}.pdf');
  }
}
