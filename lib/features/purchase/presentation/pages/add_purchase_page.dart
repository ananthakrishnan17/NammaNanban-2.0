import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';

import '../../../../core/database/database_helper.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../masters/domain/entities/masters.dart';
import '../../../masters/presentation/bloc/masters_bloc.dart';
import '../../../products/domain/entities/bom_ingredient.dart';
import '../../../products/domain/entities/product.dart';
import '../../../products/presentation/bloc/product_bloc.dart';
import '../../domain/entities/purchase.dart';

class AddPurchasePage extends StatefulWidget {
  const AddPurchasePage({super.key});
  @override State<AddPurchasePage> createState() => _AddPurchasePageState();
}

class _AddPurchasePageState extends State<AddPurchasePage> {
  final List<PurchaseCartItem> _items = [];
  Supplier? _selectedSupplier;
  String _paymentMode = 'cash';
  DateTime _purchaseDate = DateTime.now();
  // ✅ NEW: Invoice fields
  double _invoiceAmount = 0;
  String? _invoiceNumber;
  final _invoiceAmtCtrl = TextEditingController();
  final _invoiceNumCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  bool _isSaving = false;

  double get _total => _items.fold(0.0, (s, i) => s + i.totalCost);
  double get _gstTotal => _items.fold(0.0, (s, i) => s + i.gstAmount);
  // Difference: invoice amount vs computed total
  double get _invoiceDiff => _invoiceAmount > 0 ? _invoiceAmount - _total : 0;

  @override void dispose() {
    _invoiceAmtCtrl.dispose(); _invoiceNumCtrl.dispose(); _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Purchase Entry'),
        actions: [
          TextButton(
            onPressed: _isSaving || _items.isEmpty ? null : _savePurchase,
            child: Text('Save', style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w600, fontSize: 16.sp)),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(14.w),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                // Supplier
                _sectionLabel('Supplier'),
                BlocBuilder<MastersBloc, MastersState>(
                  builder: (ctx, state) {
                    return DropdownButtonFormField<Supplier>(
                      value: _selectedSupplier,
                      decoration: const InputDecoration(labelText: 'Select Supplier (optional)', prefixIcon: Icon(Icons.local_shipping)),
                      items: [
                        const DropdownMenuItem(value: null, child: Text('No Supplier / Walk-in')),
                        ...state.suppliers.map((s) => DropdownMenuItem(value: s, child: Text(s.name))),
                      ],
                      onChanged: (v) => setState(() => _selectedSupplier = v),
                    );
                  },
                ),
                SizedBox(height: 12.h),

                // Purchase Date
                _sectionLabel('Purchase Date'),
                GestureDetector(
                  onTap: () async {
                    final d = await showDatePicker(context: context, initialDate: _purchaseDate,
                        firstDate: DateTime(2020), lastDate: DateTime.now());
                    if (d != null) setState(() => _purchaseDate = d);
                  },
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 14.h),
                    decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(12.r), border: Border.all(color: AppTheme.divider)),
                    child: Row(children: [
                      const Icon(Icons.calendar_today, color: AppTheme.textSecondary),
                      SizedBox(width: 10.w),
                      Text(DateFormat('dd MMM yyyy').format(_purchaseDate), style: AppTheme.body),
                    ]),
                  ),
                ),
                SizedBox(height: 16.h),

                // Items
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  _sectionLabel('Items'),
                  TextButton.icon(
                    onPressed: () => _addItemSheet(context),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add Item'),
                  ),
                ]),
                if (_items.isEmpty)
                  Container(
                    padding: EdgeInsets.all(20.w),
                    decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(12.r), border: Border.all(color: AppTheme.divider, style: BorderStyle.solid)),
                    child: Center(child: Column(children: [
                      Text('📦', style: TextStyle(fontSize: 32.sp)),
                      SizedBox(height: 8.h),
                      Text('Tap "Add Item" to add products', style: AppTheme.caption),
                    ])),
                  )
                else
                  ..._items.asMap().entries.map((e) => _itemTile(e.key, e.value)),

                SizedBox(height: 12.h),
                // Yield Forecast
                BlocBuilder<ProductBloc, ProductState>(
                  builder: (ctx, pState) {
                    if (pState is! ProductsLoaded || _items.isEmpty) return const SizedBox();
                    return _YieldForecastCard(
                        purchasedItems: _items, allProducts: pState.products);
                  },
                ),
                SizedBox(height: 12.h),
                // Payment mode
                _sectionLabel('Payment Mode'),
                Row(
                  children: ['cash', 'upi', 'card', 'credit'].map((m) {
                    final isSelected = _paymentMode == m;
                    return Expanded(child: GestureDetector(
                      onTap: () => setState(() => _paymentMode = m),
                      child: Container(
                        margin: EdgeInsets.only(right: 6.w),
                        padding: EdgeInsets.symmetric(vertical: 10.h),
                        decoration: BoxDecoration(
                          color: isSelected ? AppTheme.primary.withOpacity(0.1) : AppTheme.surface,
                          borderRadius: BorderRadius.circular(8.r),
                          border: Border.all(color: isSelected ? AppTheme.primary : AppTheme.divider),
                        ),
                        child: Text(m.toUpperCase(), textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 10.sp, color: isSelected ? AppTheme.primary : AppTheme.textSecondary,
                                fontWeight: FontWeight.w600, fontFamily: 'Poppins')),
                      ),
                    ));
                  }).toList(),
                ),
                SizedBox(height: 12.h),

                // ✅ Invoice Number + Invoice Amount
                Row(children: [
                  Expanded(child: TextField(
                    controller: _invoiceNumCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Invoice No. (optional)',
                      prefixIcon: Icon(Icons.receipt_long),
                    ),
                    onChanged: (v) => _invoiceNumber = v.isEmpty ? null : v,
                  )),
                  SizedBox(width: 10.w),
                  Expanded(child: TextField(
                    controller: _invoiceAmtCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Invoice Amount ₹',
                      prefixText: '₹ ',
                      prefixIcon: const Icon(Icons.currency_rupee),
                      helperText: _invoiceAmount > 0 && _items.isNotEmpty
                          ? _invoiceDiff.abs() < 0.01
                          ? '✅ Matches computed total'
                          : _invoiceDiff > 0
                          ? '⚠️ Invoice ₹${_invoiceDiff.toStringAsFixed(2)} more'
                          : '⚠️ Invoice ₹${(-_invoiceDiff).toStringAsFixed(2)} less'
                          : null,
                      helperStyle: TextStyle(
                        color: _invoiceDiff.abs() < 0.01 ? AppTheme.accent : AppTheme.warning,
                        fontSize: 10.sp,
                      ),
                    ),
                    onChanged: (v) => setState(() => _invoiceAmount = double.tryParse(v) ?? 0),
                  )),
                ]),
                SizedBox(height: 10.h),

                TextField(controller: _notesCtrl, decoration: const InputDecoration(labelText: 'Notes (optional)', prefixIcon: Icon(Icons.note))),
                SizedBox(height: 80.h),
              ]),
            ),
          ),

          // Bottom summary
          if (_items.isNotEmpty)
            Container(
              padding: EdgeInsets.all(16.w),
              decoration: BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: AppTheme.divider)),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -4))]),
              child: Column(children: [
                if (_gstTotal > 0) Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text('GST Total', style: AppTheme.caption),
                  Text(CurrencyFormatter.format(_gstTotal), style: AppTheme.body),
                ]),
                SizedBox(height: 4.h),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text('Computed Total', style: AppTheme.heading3),
                  Text(CurrencyFormatter.format(_total), style: AppTheme.price),
                ]),
                // ✅ Show invoice amount if entered
                if (_invoiceAmount > 0) ...[
                  SizedBox(height: 4.h),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Text('Invoice Amount', style: AppTheme.body),
                    Text(CurrencyFormatter.format(_invoiceAmount),
                        style: AppTheme.body.copyWith(fontWeight: FontWeight.w700,
                            color: _invoiceDiff.abs() < 0.01 ? AppTheme.accent : AppTheme.warning)),
                  ]),
                  if (_invoiceDiff.abs() >= 0.01) ...[
                    SizedBox(height: 3.h),
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Text(_invoiceDiff > 0 ? 'Extra in invoice' : 'Short in invoice', style: AppTheme.caption.copyWith(color: AppTheme.warning)),
                      Text('₹${_invoiceDiff.abs().toStringAsFixed(2)}', style: AppTheme.caption.copyWith(color: AppTheme.warning, fontWeight: FontWeight.w600)),
                    ]),
                  ],
                ],
                SizedBox(height: 12.h),
                ElevatedButton(
                  onPressed: _isSaving ? null : _savePurchase,
                  child: _isSaving ? const CircularProgressIndicator(color: Colors.white) : Text('Save Purchase — ${CurrencyFormatter.format(_total)}'),
                ),
              ]),
            ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String label) => Padding(
    padding: EdgeInsets.only(bottom: 6.h),
    child: Text(label, style: AppTheme.heading3.copyWith(color: AppTheme.primary)),
  );

  Widget _itemTile(int index, PurchaseCartItem item) {
    return Container(
      margin: EdgeInsets.only(bottom: 8.h),
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12.r), border: Border.all(color: AppTheme.divider)),
      child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(item.productName, style: AppTheme.heading3),
          Text('${item.quantity} ${item.unit} × ${CurrencyFormatter.format(item.unitCost)} | GST ${item.gstRate}%', style: AppTheme.caption),
          Text(CurrencyFormatter.format(item.totalCost), style: AppTheme.price.copyWith(fontSize: 14.sp)),
        ])),
        IconButton(icon: const Icon(Icons.delete_outline, color: AppTheme.danger), onPressed: () => setState(() => _items.removeAt(index))),
      ]),
    );
  }

  void _addItemSheet(BuildContext context) {
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (_) => BlocBuilder<ProductBloc, ProductState>(
        builder: (ctx, state) {
          if (state is! ProductsLoaded) return const SizedBox();
          return _ProductPickerForPurchase(
            products: state.products,
            onItemAdded: (item) { setState(() => _items.add(item)); Navigator.pop(context); },
          );
        },
      ),
    );
  }

  Future<void> _savePurchase() async {
    setState(() => _isSaving = true);
    context.read<PurchaseBloc>().add(SavePurchaseEvent(
      items: _items, supplierId: _selectedSupplier?.id,
      supplierName: _selectedSupplier?.name, paymentMode: _paymentMode,
      notes: _notesCtrl.text.isEmpty ? null : _notesCtrl.text, purchaseDate: _purchaseDate,
    ));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Purchase saved! Stock updated.'), backgroundColor: AppTheme.accent));
      Navigator.pop(context);
    }
  }
}

// ─── Product picker sheet for purchase ────────────────────────────────────────
class _ProductPickerForPurchase extends StatefulWidget {
  final List<Product> products;
  final void Function(PurchaseCartItem) onItemAdded;
  const _ProductPickerForPurchase({required this.products, required this.onItemAdded});
  @override State<_ProductPickerForPurchase> createState() => _ProductPickerForPurchaseState();
}

class _ProductPickerForPurchaseState extends State<_ProductPickerForPurchase> {
  Product? _selected;
  final _qtyCtrl = TextEditingController(text: '1');
  final _costCtrl = TextEditingController();
  final _batchNumCtrl = TextEditingController();
  double _gstRate = 0;
  String _searchQ = '';
  List<Map<String, dynamic>> _purchaseUoms = [];
  Map<String, dynamic>? _selectedUom;
  // Optional expiry date for FEFO batch tracking
  DateTime? _expiryDate;

  @override
  void dispose() {
    _qtyCtrl.dispose();
    _costCtrl.dispose();
    _batchNumCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadPurchaseUoms(int productId) async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.rawQuery(
        "SELECT * FROM product_uoms WHERE product_id = ? AND unit_role = 'purchase'",
        [productId]);
    setState(() {
      _purchaseUoms = rows;
      _selectedUom = rows.isNotEmpty ? rows.first : null;
      if (_selectedUom != null) {
        _costCtrl.text = (_selectedUom!['purchase_price'] as num?)
                ?.toStringAsFixed(2) ??
            _selected!.purchasePrice.toStringAsFixed(2);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final filtered = widget.products.where((p) => p.name.toLowerCase().contains(_searchQ.toLowerCase())).toList();
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24.r))),
      child: Column(children: [
        SizedBox(height: 12.h),
        Container(width: 40.w, height: 4.h, decoration: BoxDecoration(color: AppTheme.divider, borderRadius: BorderRadius.circular(2.r))),
        SizedBox(height: 12.h),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.w),
          child: TextField(
            onChanged: (v) => setState(() => _searchQ = v),
            decoration: const InputDecoration(hintText: 'Search product...', prefixIcon: Icon(Icons.search)),
          ),
        ),
        SizedBox(height: 8.h),
        Expanded(child: _selected == null
            ? ListView.builder(
          itemCount: filtered.length,
          itemBuilder: (_, i) => ListTile(
            title: Text(filtered[i].name, style: AppTheme.body),
            subtitle: Text('Buy: ₹${filtered[i].purchasePrice} | Stock: ${filtered[i].stockQuantity} ${filtered[i].unit}', style: AppTheme.caption),
            onTap: () {
              setState(() {
                _selected = filtered[i];
                _costCtrl.text = filtered[i].purchasePrice.toStringAsFixed(2);
                _gstRate = filtered[i].gstRate;
                _purchaseUoms = [];
                _selectedUom = null;
                _expiryDate = null;
                _batchNumCtrl.clear();
              });
              _loadPurchaseUoms(filtered[i].id!);
            },
          ),
        )
            : Padding(
          padding: EdgeInsets.all(16.w),
          child: SingleChildScrollView(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(_selected!.name, style: AppTheme.heading2)),
              TextButton(onPressed: () => setState(() => _selected = null), child: const Text('Change')),
            ]),
            if (_selected!.wholesaleToRetailQty > 1.0) ...[
              SizedBox(height: 6.h),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Text(
                  '1 ${_selected!.wholesaleUnit} = ${_selected!.wholesaleToRetailQty.toStringAsFixed(1)} ${_selected!.retailUnit}',
                  style: AppTheme.caption.copyWith(color: AppTheme.primary, fontWeight: FontWeight.w600),
                ),
              ),
            ],
            // Purchase UOM picker
            if (_purchaseUoms.isNotEmpty) ...[
              SizedBox(height: 10.h),
              DropdownButtonFormField<Map<String, dynamic>>(
                value: _selectedUom,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Purchase UOM',
                  prefixIcon: Icon(Icons.straighten),
                ),
                items: _purchaseUoms.map((u) => DropdownMenuItem(
                  value: u,
                  child: Text(
                    '${u['uom_name']} (${u['conversion_qty']}x base) — ₹${(u['purchase_price'] as num?)?.toStringAsFixed(2) ?? '-'}',
                    overflow: TextOverflow.ellipsis,
                  ),
                )).toList(),
                onChanged: (v) => setState(() {
                  _selectedUom = v;
                  if (v != null) {
                    _costCtrl.text = ((v['purchase_price'] as num?)?.toDouble() ?? 0).toStringAsFixed(2);
                  }
                }),
              ),
            ],
            SizedBox(height: 12.h),
            Row(children: [
              Expanded(child: TextField(
                controller: _qtyCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Quantity',
                  suffixText: _selected!.wholesaleToRetailQty > 1.0 ? _selected!.wholesaleUnit : _selected!.unit,
                ),
              )),
              SizedBox(width: 10.w),
              Expanded(child: TextField(controller: _costCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Unit Cost (₹)'))),
            ]),
            SizedBox(height: 10.h),
            DropdownButtonFormField<double>(
              value: _gstRate,
              decoration: const InputDecoration(labelText: 'GST Rate'),
              items: [0.0, 5.0, 12.0, 18.0, 28.0].map((r) => DropdownMenuItem(value: r, child: Text('${r.toStringAsFixed(0)}%'))).toList(),
              onChanged: (v) => setState(() => _gstRate = v ?? 0),
            ),
            SizedBox(height: 10.h),
            // ── Batch tracking fields (optional) ──────────────────────────
            // These create a batches row so billing can apply FEFO later.
            TextField(
              controller: _batchNumCtrl,
              decoration: const InputDecoration(
                labelText: 'Batch No. (optional)',
                prefixIcon: Icon(Icons.tag),
              ),
            ),
            SizedBox(height: 10.h),
            // Expiry date picker — tap to open calendar
            GestureDetector(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _expiryDate ?? DateTime.now().add(const Duration(days: 180)),
                  firstDate: DateTime.now(),
                  lastDate: DateTime(2100),
                );
                if (picked != null) setState(() => _expiryDate = picked);
              },
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 14.h),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(8.r),
                  border: Border.all(color: AppTheme.divider),
                ),
                child: Row(children: [
                  const Icon(Icons.calendar_today, color: AppTheme.textSecondary, size: 18),
                  SizedBox(width: 10.w),
                  Text(
                    _expiryDate == null
                        ? 'Expiry Date (optional)'
                        : 'Expires: ${DateFormat('dd MMM yyyy').format(_expiryDate!)}',
                    style: _expiryDate == null ? AppTheme.caption : AppTheme.body,
                  ),
                  const Spacer(),
                  if (_expiryDate != null)
                    GestureDetector(
                      onTap: () => setState(() => _expiryDate = null),
                      child: const Icon(Icons.clear, size: 16, color: AppTheme.textSecondary),
                    ),
                ]),
              ),
            ),
            SizedBox(height: 16.h),
            ElevatedButton(
              onPressed: () {
                final qty = double.tryParse(_qtyCtrl.text) ?? 1;
                final cost = double.tryParse(_costCtrl.text) ?? _selected!.purchasePrice;
                final uomUnit = _selectedUom != null
                    ? _selectedUom!['uom_name'] as String
                    : (_selected!.wholesaleToRetailQty > 1.0 ? _selected!.wholesaleUnit : _selected!.unit);
                final batchNumTrimmed = _batchNumCtrl.text.trim();
                final batchNum = batchNumTrimmed.isEmpty ? null : batchNumTrimmed;
                widget.onItemAdded(PurchaseCartItem(
                    productId: _selected!.id!, productName: _selected!.name,
                    unit: uomUnit, quantity: qty, unitCost: cost, gstRate: _gstRate,
                    batchNumber: batchNum, expiryDate: _expiryDate));
              },
              child: const Text('Add to Purchase'),
            ),
          ]),
          ),
        ),
        ),
      ]),
    );
  }
}

// ─── Yield Forecast Card ──────────────────────────────────────────────────────
/// Shows which composite_recipe products can be made from the current purchase,
/// given the existing stock and the items being purchased.
class _YieldForecastCard extends StatelessWidget {
  final List<PurchaseCartItem> purchasedItems;
  final List<Product> allProducts;

  const _YieldForecastCard({
    required this.purchasedItems,
    required this.allProducts,
  });

  @override
  Widget build(BuildContext context) {
    // Build a map: productId → available qty (existing stock + what's being purchased)
    final available = <int, double>{};
    for (final p in allProducts) {
      if (p.id != null) available[p.id!] = p.stockQuantity;
    }
    for (final cart in purchasedItems) {
      available[cart.productId] = (available[cart.productId] ?? 0) + cart.quantity;
    }

    // Compute yield for each composite_recipe product
    final recipes = allProducts.where((p) => p.isCompositeRecipe).toList();
    if (recipes.isEmpty) return const SizedBox();

    final forecasts = <_RecipeForecast>[];
    for (final recipe in recipes) {
      final bom = recipe.bomIngredients;
      if (bom.isEmpty) continue;

      double maxYield = double.infinity;
      String? limitingName;

      for (final ing in bom) {
        if (ing.productId == null) continue;
        final avail = available[ing.productId!] ?? 0;
        final possible = ing.quantity > 0 ? avail / ing.quantity : 0.0;
        if (possible < maxYield) {
          maxYield = possible;
          limitingName = ing.productName;
        }
      }

      if (maxYield == double.infinity) maxYield = 0;
      forecasts.add(_RecipeForecast(
        name: recipe.name,
        maxYield: maxYield.floorToDouble(),
        limitingIngredient: limitingName,
        unit: recipe.unit,
      ));
    }

    if (forecasts.isEmpty) return const SizedBox();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: EdgeInsets.all(14.w),
          child: Row(children: [
            const Text('🔮', style: TextStyle(fontSize: 18)),
            SizedBox(width: 8.w),
            Text('Yield Forecast', style: AppTheme.heading3.copyWith(color: AppTheme.primary)),
          ]),
        ),
        Divider(height: 1, color: AppTheme.divider),
        ...forecasts.map((f) => Padding(
          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
          child: Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(f.name, style: AppTheme.body.copyWith(fontWeight: FontWeight.w600)),
              if (f.limitingIngredient != null)
                Row(children: [
                  Icon(Icons.warning_amber_rounded, size: 13.sp, color: AppTheme.warning),
                  SizedBox(width: 4.w),
                  Expanded(child: Text('Limited by: ${f.limitingIngredient}',
                      style: AppTheme.caption.copyWith(color: AppTheme.warning),
                      overflow: TextOverflow.ellipsis)),
                ]),
            ])),
            SizedBox(width: 12.w),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
              decoration: BoxDecoration(
                color: f.maxYield > 0
                    ? AppTheme.accent.withOpacity(0.1)
                    : AppTheme.danger.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8.r),
              ),
              child: Text(
                '${f.maxYield.toStringAsFixed(0)} ${f.unit}',
                style: AppTheme.body.copyWith(
                  color: f.maxYield > 0 ? AppTheme.accent : AppTheme.danger,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ]),
        )),
        SizedBox(height: 4.h),
      ]),
    );
  }
}

class _RecipeForecast {
  final String name;
  final double maxYield;
  final String? limitingIngredient;
  final String unit;
  const _RecipeForecast({
    required this.name,
    required this.maxYield,
    required this.limitingIngredient,
    required this.unit,
  });
}