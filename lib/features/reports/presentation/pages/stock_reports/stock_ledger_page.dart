import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';

import '../../../../../core/database/database_helper.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/utils/currency_formatter.dart';

/// Stock Ledger — per-product running balance card showing every stock movement
/// (purchases, sales, sale returns, adjustments) with in/out/balance columns.
class StockLedgerPage extends StatefulWidget {
  const StockLedgerPage({super.key});

  @override
  State<StockLedgerPage> createState() => _StockLedgerPageState();
}

class _StockLedgerPageState extends State<StockLedgerPage> {
  List<Map<String, dynamic>> _products = [];
  Map<String, dynamic>? _selectedProduct;
  List<Map<String, dynamic>> _entries = [];
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    try {
      final db = await DatabaseHelper.instance.database;
      final rows = await db.rawQuery(
          'SELECT id, name, stock_quantity FROM products WHERE is_active=1 ORDER BY name ASC');
      setState(() => _products = rows);
    } catch (_) {}
  }

  Future<void> _loadLedger() async {
    if (_selectedProduct == null) return;
    setState(() { _isLoading = true; _error = null; });
    try {
      final db = await DatabaseHelper.instance.database;
      final productId = _selectedProduct!['id'] as int;

      // Sales (stock out)
      final sales = await db.rawQuery('''
        SELECT b.created_at as date, 'Sale #' || b.bill_number as description,
               0.0 as qty_in, bi.quantity * COALESCE(bi.conversion_qty, 1.0) as qty_out
        FROM bill_items bi
        JOIN bills b ON b.id = bi.bill_id
        WHERE bi.product_id = ? AND (b.status IS NULL OR b.status != 'cancelled')
      ''', [productId]);

      // Purchases (stock in)
      final purchases = await db.rawQuery('''
        SELECT p.created_at as date, 'Purchase #' || p.purchase_number as description,
               pi.quantity as qty_in, 0.0 as qty_out
        FROM purchase_items pi
        JOIN purchases p ON p.id = pi.purchase_id
        WHERE pi.product_id = ?
      ''', [productId]);

      // Sale returns (stock in)
      final returns = await db.rawQuery('''
        SELECT sr.created_at as date, 'Return #' || sr.return_number as description,
               COALESCE(sri.base_qty_restored, sri.quantity) as qty_in, 0.0 as qty_out
        FROM sale_return_items sri
        JOIN sale_returns sr ON sr.id = sri.return_id
        WHERE sri.product_id = ?
      ''', [productId]);

      // Stock adjustments
      final adjustments = await db.rawQuery('''
        SELECT created_at as date,
               COALESCE(reason, 'Adjustment') as description,
               CASE WHEN adjustment_type = 'add' THEN quantity ELSE 0.0 END as qty_in,
               CASE WHEN adjustment_type = 'reduce' THEN quantity ELSE 0.0 END as qty_out
        FROM stock_adjustments
        WHERE product_id = ?
      ''', [productId]);

      final all = [...sales, ...purchases, ...returns, ...adjustments];
      all.sort((a, b) => (a['date'] as String).compareTo(b['date'] as String));

      // Running balance
      double balance = 0;
      final withBalance = all.map((r) {
        final qIn = (r['qty_in'] as num?)?.toDouble() ?? 0;
        final qOut = (r['qty_out'] as num?)?.toDouble() ?? 0;
        balance += qIn - qOut;
        return {...r, 'balance': balance};
      }).toList();

      setState(() => _entries = withBalance);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(title: const Text('Stock Ledger')),
      body: Column(
        children: [
          // Product selector
          Container(
            color: Colors.white,
            padding: EdgeInsets.fromLTRB(16.w, 10.h, 16.w, 10.h),
            child: DropdownButtonFormField<Map<String, dynamic>>(
              value: _selectedProduct,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: 'Select Product',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10.r)),
                contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
              ),
              items: _products.map((p) => DropdownMenuItem(
                value: p,
                child: Text(p['name'] as String,
                    overflow: TextOverflow.ellipsis),
              )).toList(),
              onChanged: (v) {
                setState(() { _selectedProduct = v; _entries = []; });
                _loadLedger();
              },
            ),
          ),

          if (_selectedProduct != null)
            Container(
              color: AppTheme.primary.withOpacity(0.06),
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 6.h),
              child: Row(children: [
                Text('Current Stock: ', style: AppTheme.caption),
                Text(
                  _formatQty(_selectedProduct!['stock_quantity'] as num? ?? 0),
                  style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w700,
                      color: AppTheme.primary, fontFamily: 'Poppins'),
                ),
              ]),
            ),

          // Table header
          if (_entries.isNotEmpty)
            Container(
              color: AppTheme.primary,
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
              child: Row(children: [
                Expanded(flex: 4, child: Text('Date / Description',
                    style: TextStyle(color: Colors.white, fontSize: 11.sp, fontWeight: FontWeight.w600))),
                _hdr('Stock In'),
                _hdr('Stock Out'),
                _hdr('Balance'),
              ]),
            ),

          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(child: Text(_error!, style: TextStyle(color: AppTheme.danger)))
                    : _selectedProduct == null
                        ? Center(child: Text('Select a product to view its stock ledger.',
                            style: AppTheme.caption, textAlign: TextAlign.center))
                        : _entries.isEmpty
                            ? Center(child: Text('No movements found.', style: AppTheme.caption))
                            : ListView.separated(
                                itemCount: _entries.length,
                                separatorBuilder: (_, __) => Divider(height: 1, color: AppTheme.divider),
                                itemBuilder: (_, i) {
                                  final e = _entries[i];
                                  final qIn = (e['qty_in'] as num?)?.toDouble() ?? 0;
                                  final qOut = (e['qty_out'] as num?)?.toDouble() ?? 0;
                                  final bal = (e['balance'] as num?)?.toDouble() ?? 0;
                                  return Container(
                                    color: i.isEven ? Colors.white : AppTheme.surface,
                                    padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                                    child: Row(children: [
                                      Expanded(flex: 4, child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(e['description'] as String? ?? '',
                                              style: AppTheme.body.copyWith(fontSize: 12.sp)),
                                          Text(_fmtDate(e['date'] as String),
                                              style: AppTheme.caption.copyWith(fontSize: 10.sp)),
                                        ],
                                      )),
                                      _cell(qIn > 0 ? '+${_formatQty(qIn)}' : '-',
                                          qIn > 0 ? AppTheme.accent : AppTheme.textSecondary),
                                      _cell(qOut > 0 ? '-${_formatQty(qOut)}' : '-',
                                          qOut > 0 ? AppTheme.danger : AppTheme.textSecondary),
                                      _cell(_formatQty(bal), AppTheme.textPrimary, bold: true),
                                    ]),
                                  );
                                },
                              ),
          ),
        ],
      ),
    );
  }

  Widget _hdr(String t) => Expanded(
    flex: 2,
    child: Text(t, textAlign: TextAlign.right,
        style: TextStyle(color: Colors.white, fontSize: 11.sp, fontWeight: FontWeight.w600)),
  );

  Widget _cell(String t, Color color, {bool bold = false}) => Expanded(
    flex: 2,
    child: Text(t, textAlign: TextAlign.right,
        style: TextStyle(fontSize: 12.sp, color: color,
            fontWeight: bold ? FontWeight.w700 : FontWeight.w400, fontFamily: 'Poppins')),
  );

  String _formatQty(num q) {
    final d = q.toDouble();
    return d == d.truncateToDouble() ? d.toInt().toString() : d.toStringAsFixed(2);
  }

  String _fmtDate(String iso) {
    try {
      return DateFormat('dd/MM/yy HH:mm').format(DateTime.parse(iso));
    } catch (_) { return iso; }
  }
}
