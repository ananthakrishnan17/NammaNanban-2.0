import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../../core/database/database_helper.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/utils/currency_formatter.dart';
import '../../../../billing/presentation/pages/bill_view_screen.dart';
import '../../../data/repositories/report_repository.dart';
import '../../widgets/date_range_filter.dart';
import '../../widgets/report_summary_card.dart';

class GstReportPage extends StatefulWidget {
  const GstReportPage({super.key});

  @override
  State<GstReportPage> createState() => _GstReportPageState();
}

class _GstReportPageState extends State<GstReportPage> {
  late final ReportRepository _repo;
  late DateTime _from, _to;
  List<Map<String, dynamic>> _rows = [];
  bool _isLoading = false;
  String? _error;
  String _shopGstin = '';

  @override
  void initState() {
    super.initState();
    _repo = ReportRepository(DatabaseHelper.instance);
    final now = DateTime.now();
    _from = DateTime(now.year, now.month, 1);
    _to = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
    _loadPrefs();
    _load();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _shopGstin = prefs.getString('shop_gstin') ?? '';
      });
    }
  }

  Future<void> _load() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final data = await _repo.getGstReport(from: _from, to: _to);
      setState(() => _rows = data);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Group rows by bill_id → bill map
  List<Map<String, dynamic>> get _bills {
    final seen = <int>{};
    final result = <Map<String, dynamic>>[];
    for (final r in _rows) {
      final id = r['bill_id'] as int;
      if (!seen.contains(id)) {
        seen.add(id);
        result.add(r);
      }
    }
    return result;
  }

  // Compute summary from rows
  Map<String, double> get _summary {
    final bills = _bills;
    double taxableValue = 0, cgst = 0, sgst = 0, gst = 0, invoiceValue = 0;
    for (final b in bills) {
      invoiceValue += (b['total_amount'] as num).toDouble();
      gst += (b['gst_total'] as num? ?? 0).toDouble();
      cgst += (b['cgst_total'] as num? ?? 0).toDouble();
      sgst += (b['sgst_total'] as num? ?? 0).toDouble();
    }
    taxableValue = invoiceValue - gst;
    return {
      'total_bills': bills.length.toDouble(),
      'total_taxable_value': taxableValue,
      'total_cgst': cgst,
      'total_sgst': sgst,
      'total_gst': gst,
      'total_invoice_value': invoiceValue,
    };
  }

  Future<void> _exportJson() async {
    try {
      final summary = _summary;
      final bills = _bills;

      // Group items per bill
      final billItems = <int, List<Map<String, dynamic>>>{};
      for (final r in _rows) {
        final id = r['bill_id'] as int;
        billItems.putIfAbsent(id, () => []).add(r);
      }

      final invoices = bills.map((b) {
        final id = b['bill_id'] as int;
        final items = billItems[id] ?? [];
        final createdAt = DateTime.parse(b['created_at'] as String);

        double invTaxable = 0, invCgst = 0, invSgst = 0, invGst = 0, invTotal = 0;
        invTotal = (b['total_amount'] as num).toDouble();
        invGst = (b['gst_total'] as num? ?? 0).toDouble();
        invCgst = (b['cgst_total'] as num? ?? 0).toDouble();
        invSgst = (b['sgst_total'] as num? ?? 0).toDouble();
        invTaxable = invTotal - invGst;
        final discount = (b['discount_amount'] as num? ?? 0).toDouble();

        return {
          'invoice_number': b['bill_number'],
          'invoice_date': DateFormat('dd/MM/yyyy').format(createdAt),
          'invoice_type': b['bill_type'] ?? 'retail',
          'customer_name': b['customer_name'] ?? 'Walk-in',
          'customer_gstin': b['customer_gstin'],
          'payment_mode': b['payment_mode'] ?? 'cash',
          'items': items.map((item) {
            final qty = (item['quantity'] as num).toDouble();
            final unitPrice = (item['unit_price'] as num).toDouble();
            final gstRate = (item['gst_rate'] as num? ?? 0).toDouble();
            final gstAmt = (item['gst_amount'] as num? ?? 0).toDouble();
            final totalPrice = (item['total_price'] as num).toDouble();
            final taxableItem = totalPrice - gstAmt;
            final halfGst = gstAmt / 2;
            return {
              'description': item['product_name'],
              'quantity': qty,
              'unit': item['unit'] ?? '',
              'unit_price': unitPrice,
              'taxable_value': taxableItem,
              'gst_rate': gstRate,
              'cgst_rate': gstRate / 2,
              'sgst_rate': gstRate / 2,
              'cgst_amount': halfGst,
              'sgst_amount': halfGst,
              'total_gst': gstAmt,
              'total_amount': totalPrice,
            };
          }).toList(),
          'invoice_totals': {
            'taxable_value': invTaxable,
            'total_cgst': invCgst,
            'total_sgst': invSgst,
            'total_gst': invGst,
            'discount': discount,
            'total_invoice_value': invTotal,
          },
        };
      }).toList();

      final period = DateFormat('MM-yyyy').format(_from);
      final data = {
        'gstin': _shopGstin,
        'period': period,
        'generated_at': DateTime.now().toIso8601String(),
        'summary': {
          'total_bills': bills.length,
          'total_taxable_value': summary['total_taxable_value'],
          'total_cgst': summary['total_cgst'],
          'total_sgst': summary['total_sgst'],
          'total_gst': summary['total_gst'],
          'total_invoice_value': summary['total_invoice_value'],
        },
        'invoices': invoices,
      };

      final jsonStr = const JsonEncoder.withIndent('  ').convert(data);
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/gst_report_$period.json');
      await file.writeAsString(jsonStr);

      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'application/json')],
        subject: 'GST Report $period',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export failed: $e'), backgroundColor: AppTheme.danger));
    }
  }

  @override
  Widget build(BuildContext context) {
    final summary = _summary;
    final bills = _bills;

    return Scaffold(
      appBar: AppBar(
        title: const Text('GST Report'),
        actions: [
          if (bills.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.file_download_outlined),
              tooltip: 'Export JSON',
              onPressed: _exportJson,
            ),
        ],
      ),
      body: Column(children: [
        Container(
          color: Colors.white,
          padding: EdgeInsets.all(16.w),
          child: DateRangeFilter(
              from: _from, to: _to,
              onChanged: (f, t) { setState(() { _from = f; _to = t; }); _load(); }),
        ),
        if (bills.isNotEmpty)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
            child: Row(children: [
              ReportSummaryCard(
                  label: 'Total Bills', value: bills.length.toString(),
                  color: AppTheme.primary, emoji: '🧾'),
              SizedBox(width: 10.w),
              ReportSummaryCard(
                  label: 'Taxable Value',
                  value: CurrencyFormatter.format(summary['total_taxable_value']!),
                  color: AppTheme.secondary, emoji: '📋'),
              SizedBox(width: 10.w),
              ReportSummaryCard(
                  label: 'Total CGST',
                  value: CurrencyFormatter.format(summary['total_cgst']!),
                  color: AppTheme.accent, emoji: '📊'),
              SizedBox(width: 10.w),
              ReportSummaryCard(
                  label: 'Total SGST',
                  value: CurrencyFormatter.format(summary['total_sgst']!),
                  color: AppTheme.accent, emoji: '📊'),
              SizedBox(width: 10.w),
              ReportSummaryCard(
                  label: 'Total GST',
                  value: CurrencyFormatter.format(summary['total_gst']!),
                  color: AppTheme.warning, emoji: '💰'),
            ]),
          ),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? Center(child: Text('Error: $_error'))
                  : bills.isEmpty
                      ? Center(child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('📊', style: TextStyle(fontSize: 48.sp)),
                            SizedBox(height: 12.h),
                            Text('No GST data in this period', style: AppTheme.heading3),
                          ]))
                      : ListView.separated(
                          padding: EdgeInsets.all(16.w),
                          itemCount: bills.length,
                          separatorBuilder: (_, __) => SizedBox(height: 8.h),
                          itemBuilder: (_, i) {
                            final b = bills[i];
                            final date = DateTime.parse(b['created_at'] as String);
                            final gstTotal = (b['gst_total'] as num? ?? 0).toDouble();
                            final total = (b['total_amount'] as num).toDouble();
                            return GestureDetector(
                              onTap: () async {
                                try {
                                  final bill = await _repo.getBillById(b['bill_id'] as int);
                                  if (!mounted) return;
                                  Navigator.push(context,
                                      MaterialPageRoute(builder: (_) => BillViewScreen(bill: bill)));
                                } catch (e) {
                                  if (!mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Failed to load bill: $e')));
                                }
                              },
                              child: Container(
                                padding: EdgeInsets.all(14.w),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12.r),
                                  border: Border.all(color: AppTheme.divider),
                                ),
                                child: Row(children: [
                                  Expanded(child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Bill #${b['bill_number']}',
                                          style: AppTheme.body.copyWith(fontWeight: FontWeight.w600)),
                                      SizedBox(height: 2.h),
                                      Text('${b['customer_name'] ?? 'Walk-in'}  •  ${b['payment_mode'] ?? ''}',
                                          style: AppTheme.caption),
                                      Text(DateFormat('dd MMM yyyy  h:mm a').format(date),
                                          style: AppTheme.caption),
                                      if (gstTotal > 0)
                                        Text('GST: ${CurrencyFormatter.format(gstTotal)}',
                                            style: AppTheme.caption.copyWith(color: AppTheme.warning)),
                                    ],
                                  )),
                                  Text(CurrencyFormatter.format(total),
                                      style: AppTheme.body.copyWith(
                                          fontWeight: FontWeight.w700, fontSize: 14.sp)),
                                ]),
                              ),
                            );
                          }),
        ),
      ]),
    );
  }
}
