import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/database/database_helper.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/gst_calculator.dart';
import '../../../masters/domain/entities/masters.dart';
import '../../../masters/presentation/bloc/masters_bloc.dart';
import '../../../users/domain/entities/product_uom.dart';
import '../../../users/domain/entities/multi_uom_editor.dart';
import '../../domain/entities/product.dart';
import '../bloc/product_bloc.dart';
import '../../../../shared/widgets/searchable_dropdown_with_add.dart';

class AddEditProductPage extends StatefulWidget {
  final Product? product;
  const AddEditProductPage({super.key, this.product});
  @override State<AddEditProductPage> createState() => _AddEditProductPageState();
}

class _AddEditProductPageState extends State<AddEditProductPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameCtrl, _buyCtrl, _sellCtrl, _wsCtrl, _stockCtrl, _lowStockCtrl, _barcodeCtrl, _hsnCtrl;
  late TextEditingController _wsUnitCtrl, _retailUnitCtrl, _wsToRetailQtyCtrl, _retailPriceCtrl;
  Category? _selectedCategory;
  Brand? _selectedBrand;
  UomUnit? _selectedUom;
  double _gstRate = 0.0;
  bool _gstInclusive = true;
  String _rateType = 'fixed';
  bool _isActive = true;
  List<ProductUom> _pendingUoms = [];
  bool get isEditing => widget.product != null;

  @override void initState() {
    super.initState();
    final p = widget.product;
    _nameCtrl = TextEditingController(text: p?.name ?? '');
    _buyCtrl = TextEditingController(text: p != null ? p.purchasePrice.toStringAsFixed(2) : '');
    _sellCtrl = TextEditingController(text: p != null ? p.sellingPrice.toStringAsFixed(2) : '');
    _wsCtrl = TextEditingController(text: p != null && p.wholesalePrice > 0 ? p.wholesalePrice.toStringAsFixed(2) : '');
    _stockCtrl = TextEditingController(text: p?.stockQuantity.toString() ?? '0');
    _lowStockCtrl = TextEditingController(text: p?.lowStockThreshold.toString() ?? '5');
    _barcodeCtrl = TextEditingController(text: p?.barcode ?? '');
    _hsnCtrl = TextEditingController(text: p?.hsnCode ?? '');
    _wsUnitCtrl = TextEditingController(text: p?.wholesaleUnit ?? 'bag');
    _retailUnitCtrl = TextEditingController(text: p?.retailUnit ?? 'kg');
    _wsToRetailQtyCtrl = TextEditingController(text: p != null ? p.wholesaleToRetailQty.toString() : '1.0');
    _retailPriceCtrl = TextEditingController(text: p != null && p.retailPrice > 0 ? p.retailPrice.toStringAsFixed(2) : '');
    _gstRate = p?.gstRate ?? 0.0;
    _gstInclusive = p?.gstInclusive ?? true;
    _rateType = p?.rateType ?? 'fixed';
    _isActive = p?.isActive ?? true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<MastersBloc>().add(LoadAllMasters());
      if (isEditing && widget.product!.id != null) {
        context.read<ProductBloc>().add(LoadProductUoms(widget.product!.id!));
      }
    });
  }

  @override void dispose() {
    for (final c in [_nameCtrl,_buyCtrl,_sellCtrl,_wsCtrl,_stockCtrl,_lowStockCtrl,_barcodeCtrl,_hsnCtrl,_wsUnitCtrl,_retailUnitCtrl,_wsToRetailQtyCtrl,_retailPriceCtrl]) c.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final now = DateTime.now();
    final p = ProductModel(
      id: widget.product?.id, name: _nameCtrl.text.trim(),
      categoryId: _selectedCategory?.id, categoryName: _selectedCategory?.name,
      brandId: _selectedBrand?.id, brandName: _selectedBrand?.name,
      uomId: _selectedUom?.id, uomShortName: _selectedUom?.shortName,
      purchasePrice: double.parse(_buyCtrl.text),
      sellingPrice: double.parse(_sellCtrl.text),
      wholesalePrice: double.tryParse(_wsCtrl.text) ?? 0.0,
      stockQuantity: double.parse(_stockCtrl.text),
      unit: _selectedUom?.shortName ?? 'piece',
      lowStockThreshold: double.tryParse(_lowStockCtrl.text) ?? 5.0,
      gstRate: _gstRate, gstInclusive: _gstInclusive, rateType: _rateType,
      barcode: _barcodeCtrl.text.isEmpty ? null : _barcodeCtrl.text,
      hsnCode: _hsnCtrl.text.isEmpty ? null : _hsnCtrl.text,
      isActive: _isActive, createdAt: widget.product?.createdAt ?? now, updatedAt: now,
      wholesaleUnit: _wsUnitCtrl.text.trim().isEmpty ? 'bag' : _wsUnitCtrl.text.trim(),
      retailUnit: _retailUnitCtrl.text.trim().isEmpty ? 'kg' : _retailUnitCtrl.text.trim(),
      wholesaleToRetailQty: double.tryParse(_wsToRetailQtyCtrl.text) ?? 1.0,
      retailPrice: double.tryParse(_retailPriceCtrl.text) ?? 0.0,
    );
    if (isEditing) {
      context.read<ProductBloc>().add(UpdateProduct(p));
      if (_pendingUoms.isNotEmpty) {
        final uomRepo = ProductUomRepository(DatabaseHelper.instance);
        uomRepo.saveAllUoms(widget.product!.id!, _pendingUoms);
      }
    } else {
      context.read<ProductBloc>().add(AddProduct(p));
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Product' : 'Add Product'),
        actions: [TextButton(onPressed: _save, child: Text('Save', style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w600, fontSize: 16.sp)))],
      ),
      body: BlocBuilder<MastersBloc, MastersState>(builder: (ctx, mastersState) {
        return BlocBuilder<ProductBloc, ProductState>(builder: (ctx2, productState) {
          final categories = productState is ProductsLoaded ? productState.categories : <Category>[];
          final brands = mastersState.brands;
          final units = mastersState.units;
          return SingleChildScrollView(
            padding: EdgeInsets.all(16.w),
            child: Form(key: _formKey, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _sec('📝 Basic Information'),
              TextFormField(controller: _nameCtrl, decoration: const InputDecoration(labelText: 'Product Name *', prefixIcon: Icon(Icons.inventory_2)),
                  validator: (v) => v!.trim().isEmpty ? 'Name required' : null, textCapitalization: TextCapitalization.words),
              SizedBox(height: 10.h),

              // CATEGORY — inline quick add via ProductBloc.repository (direct DB call)
              SearchableDropdownWithAdd<Category>(
                label: 'Category', hint: 'Select or create category', icon: Icons.category,
                selectedValue: _selectedCategory, items: categories,
                itemLabel: (c) => '${c.icon} ${c.name}', itemId: (c) => c.id,
                onChanged: (c) => setState(() => _selectedCategory = c),
                addNewLabel: 'Create Category',
                onAddNew: (name) async {
                  // ✅ FIXED: Use repository getter directly — no more dynamic cast
                  final bloc = context.read<ProductBloc>();
                  final newCategory = Category(name: name, icon: '📦', color: '#FF6B35');
                  final id = await bloc.repository.addCategory(newCategory);
                  // Reload so the dropdown list refreshes
                  bloc.add(LoadProducts());
                  // Wait for reload
                  await Future.delayed(const Duration(milliseconds: 400));
                  // Return the created category with the real DB id
                  final created = Category(id: id, name: name, icon: '📦', color: '#FF6B35');
                  setState(() => _selectedCategory = created);
                  return created;
                },
              ),
              SizedBox(height: 10.h),

              // BRAND — inline quick add via MastersBloc + direct DB call
              SearchableDropdownWithAdd<Brand>(
                label: 'Brand', hint: 'Select or create brand', icon: Icons.branding_watermark,
                selectedValue: _selectedBrand, items: brands,
                itemLabel: (b) => b.name, itemId: (b) => b.id,
                onChanged: (b) => setState(() => _selectedBrand = b),
                addNewLabel: 'Create Brand',
                onAddNew: (name) async {
                  // ✅ FIXED: Use MastersBloc.repository directly for real id
                  final bloc = context.read<MastersBloc>();
                  final id = await bloc.repository.addBrand(name);
                  bloc.add(LoadAllMasters());
                  await Future.delayed(const Duration(milliseconds: 400));
                  final created = Brand(id: id, name: name, createdAt: DateTime.now());
                  setState(() => _selectedBrand = created);
                  return created;
                },
              ),
              SizedBox(height: 20.h),

              _sec('💰 Pricing'),
              Row(children: [
                Expanded(child: TextFormField(controller: _buyCtrl, keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Purchase Price *', prefixText: '₹ '),
                    validator: (v) { if (v!.isEmpty) return 'Required'; if (double.tryParse(v) == null) return 'Invalid'; return null; },
                    onChanged: (_) => setState(() {}))),
                SizedBox(width: 10.w),
                Expanded(child: TextFormField(controller: _sellCtrl, keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Retail Price *', prefixText: '₹ '),
                    validator: (v) { if (v!.isEmpty) return 'Required'; if (double.tryParse(v) == null) return 'Invalid'; return null; },
                    onChanged: (_) => setState(() {}))),
              ]),
              SizedBox(height: 10.h),
              TextFormField(controller: _wsCtrl, keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Wholesale Price (optional)', prefixText: '₹ ', prefixIcon: Icon(Icons.store)),
                  onChanged: (_) => setState(() {})),
              SizedBox(height: 8.h), _profitPreview(),
              SizedBox(height: 20.h),

              _sec('🏷️ Rate Type'),
              Row(children: [
                Expanded(child: _rateBtn('fixed', 'Fixed Rate', '🔒', 'Same price every time')),
                SizedBox(width: 10.w),
                Expanded(child: _rateBtn('open', 'Open Rate', '✏️', 'Enter price at billing')),
              ]),
              SizedBox(height: 20.h),

              _sec('📦 Stock & Unit'),
              Row(children: [
                Expanded(child: TextFormField(controller: _stockCtrl, keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Current Stock'),
                    validator: (v) => double.tryParse(v ?? '') == null ? 'Invalid' : null)),
                SizedBox(width: 10.w),
                Expanded(child: TextFormField(controller: _lowStockCtrl, keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Low Stock Alert'))),
              ]),
              SizedBox(height: 10.h),

              // UOM — inline quick add via MastersBloc.repository for real id
              SearchableDropdownWithAdd<UomUnit>(
                label: 'Unit of Measure', hint: 'Select or create unit', icon: Icons.straighten,
                selectedValue: _selectedUom, items: units,
                itemLabel: (u) => '${u.name} (${u.shortName})', itemId: (u) => u.id,
                onChanged: (u) => setState(() => _selectedUom = u),
                addNewLabel: 'Create Unit',
                onAddNew: (name) async {
                  // ✅ FIXED: Use MastersBloc.repository directly for real id
                  final bloc = context.read<MastersBloc>();
                  final shortName = name.length > 4 ? name.substring(0, 4) : name;
                  final newUnit = UomUnit(name: name, shortName: shortName, createdAt: DateTime.now());
                  final id = await bloc.repository.addUnit(newUnit);
                  bloc.add(LoadAllMasters());
                  await Future.delayed(const Duration(milliseconds: 400));
                  final created = UomUnit(id: id, name: name, shortName: shortName, createdAt: DateTime.now());
                  setState(() => _selectedUom = created);
                  return created;
                },
              ),
              SizedBox(height: 20.h),

              _sec('🧾 GST Settings'),
              Wrap(spacing: 8.w, runSpacing: 8.h, children: GstCalculator.gstSlabs.map((rate) {
                final sel = _gstRate == rate;
                return GestureDetector(
                  onTap: () => setState(() => _gstRate = rate),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
                    decoration: BoxDecoration(
                        color: sel ? AppTheme.primary : AppTheme.surface,
                        borderRadius: BorderRadius.circular(20.r),
                        border: Border.all(color: sel ? AppTheme.primary : AppTheme.divider)),
                    child: Text('${rate.toStringAsFixed(0)}% GST', style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w600, fontFamily: 'Poppins', color: sel ? Colors.white : AppTheme.textPrimary)),
                  ),
                );
              }).toList()),
              if (_gstRate > 0) ...[
                SizedBox(height: 10.h),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 4.h),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12.r), border: Border.all(color: AppTheme.divider)),
                  child: Row(children: [
                    Expanded(child: Text('GST Inclusive in Price', style: AppTheme.body)),
                    Switch(value: _gstInclusive, onChanged: (v) => setState(() { _gstInclusive = v; }), activeColor: AppTheme.primary),
                  ]),
                ),
                SizedBox(height: 8.h),
                TextFormField(controller: _hsnCtrl, decoration: const InputDecoration(labelText: 'HSN Code', prefixIcon: Icon(Icons.numbers))),
                SizedBox(height: 8.h),
                _gstPreview(),
              ],
              SizedBox(height: 20.h),

              _sec('⚖️ Wholesale / Retail Setup'),
              Container(
                padding: EdgeInsets.all(14.w),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border.all(color: AppTheme.divider),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Configure if this product is sold in bulk (bags) and retail (kg)', style: AppTheme.caption),
                  SizedBox(height: 12.h),
                  Row(children: [
                    Expanded(child: TextFormField(controller: _wsUnitCtrl,
                        decoration: const InputDecoration(labelText: 'Wholesale Unit', hintText: 'e.g. bag'))),
                    SizedBox(width: 10.w),
                    Expanded(child: TextFormField(controller: _retailUnitCtrl,
                        decoration: const InputDecoration(labelText: 'Retail Unit', hintText: 'e.g. kg'))),
                  ]),
                  SizedBox(height: 10.h),
                  TextFormField(
                    controller: _wsToRetailQtyCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Conversion: 1 ${_wsUnitCtrl.text.isEmpty ? 'wholesale unit' : _wsUnitCtrl.text} = ? ${_retailUnitCtrl.text.isEmpty ? 'retail units' : _retailUnitCtrl.text}',
                      hintText: 'e.g. 22.0',
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  SizedBox(height: 10.h),
                  TextFormField(
                    controller: _retailPriceCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Retail Price (per ${_retailUnitCtrl.text.isEmpty ? 'retail unit' : _retailUnitCtrl.text})',
                      prefixText: '₹ ',
                      hintText: 'e.g. 80.0',
                    ),
                  ),
                ]),
              ),
              SizedBox(height: 20.h),

              _sec('⚙️ Optional'),
              TextFormField(controller: _barcodeCtrl, decoration: const InputDecoration(labelText: 'Barcode', prefixIcon: Icon(Icons.qr_code_scanner))),
              SizedBox(height: 10.h),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 4.h),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12.r), border: Border.all(color: AppTheme.divider)),
                child: Row(children: [Expanded(child: Text('Active Product', style: AppTheme.body)), Switch(value: _isActive, onChanged: (v) => setState(() => _isActive = v), activeColor: AppTheme.primary)]),
              ),
              SizedBox(height: 24.h),

              // ── Sale Units (Loose Sale) ───────────────────────────────────
              _sec('📏 Sale Units (Loose Sale)'),
              if (!isEditing)
                Container(
                  padding: EdgeInsets.all(14.w),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(12.r),
                    border: Border.all(color: AppTheme.divider),
                  ),
                  child: Row(children: [
                    Icon(Icons.info_outline, color: AppTheme.textSecondary, size: 18.sp),
                    SizedBox(width: 8.w),
                    Expanded(child: Text(
                      'Save the product first to configure loose sale units.',
                      style: AppTheme.caption,
                    )),
                  ]),
                )
              else ...[
                Builder(builder: (ctx) {
                  final existingUoms = productState is ProductsLoaded
                      ? productState.productUoms
                      : const <ProductUom>[];
                  return MultiUomEditor(
                    key: ValueKey('uoms_${existingUoms.length}'),
                    productId: widget.product!.id!,
                    availableUnits: units,
                    initialUoms: existingUoms,
                    onChanged: (uoms) => setState(() => _pendingUoms = uoms),
                  );
                }),
              ],
              SizedBox(height: 24.h),

              ElevatedButton(onPressed: _save, child: Text(isEditing ? 'Update Product' : 'Add Product')),
              SizedBox(height: 40.h),
            ])),
          );
        });
      }),
    );
  }

  Widget _sec(String l) => Padding(padding: EdgeInsets.only(bottom: 10.h), child: Text(l, style: AppTheme.heading3.copyWith(color: AppTheme.primary)));

  Widget _rateBtn(String type, String title, String emoji, String desc) {
    final sel = _rateType == type;
    return GestureDetector(
      onTap: () => setState(() => _rateType = type),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.all(12.w),
        decoration: BoxDecoration(
            color: sel ? AppTheme.primary.withOpacity(0.08) : Colors.white,
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(color: sel ? AppTheme.primary : AppTheme.divider, width: sel ? 2 : 1)),
        child: Column(children: [
          Text(emoji, style: TextStyle(fontSize: 22.sp)),
          SizedBox(height: 4.h),
          Text(title, style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w600, color: sel ? AppTheme.primary : AppTheme.textPrimary, fontFamily: 'Poppins')),
          SizedBox(height: 2.h),
          Text(desc, style: AppTheme.caption.copyWith(fontSize: 9.sp), textAlign: TextAlign.center),
        ]),
      ),
    );
  }

  Widget _profitPreview() {
    final buy = double.tryParse(_buyCtrl.text) ?? 0;
    final sell = double.tryParse(_sellCtrl.text) ?? 0;
    final ws = double.tryParse(_wsCtrl.text) ?? 0;
    if (buy == 0 && sell == 0) return const SizedBox();
    final profit = sell - buy; final margin = sell > 0 ? (profit / sell) * 100 : 0.0;
    return Container(
      padding: EdgeInsets.all(10.w),
      decoration: BoxDecoration(color: profit >= 0 ? AppTheme.accent.withOpacity(0.08) : AppTheme.danger.withOpacity(0.08), borderRadius: BorderRadius.circular(10.r)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(profit >= 0 ? Icons.trending_up : Icons.trending_down, color: profit >= 0 ? AppTheme.accent : AppTheme.danger, size: 16.sp),
          SizedBox(width: 6.w),
          Text('Retail Profit: ₹${profit.toStringAsFixed(2)}  (${margin.toStringAsFixed(1)}%)', style: TextStyle(fontSize: 12.sp, color: profit >= 0 ? AppTheme.accent : AppTheme.danger, fontWeight: FontWeight.w500, fontFamily: 'Poppins')),
        ]),
        if (ws > 0) Text('Wholesale Profit: ₹${(ws - buy).toStringAsFixed(2)}', style: TextStyle(fontSize: 11.sp, color: (ws-buy) >= 0 ? AppTheme.accent : AppTheme.danger, fontFamily: 'Poppins')),
      ]),
    );
  }

  Widget _gstPreview() {
    final price = double.tryParse(_sellCtrl.text) ?? 0;
    if (price == 0) return const SizedBox();
    final r = GstCalculator.calculate(baseAmount: price, gstRate: _gstRate, isInclusive: _gstInclusive);
    return Container(
      padding: EdgeInsets.all(10.w),
      decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(10.r)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('GST Breakdown (${_gstInclusive ? "Inclusive" : "Exclusive"})', style: AppTheme.caption.copyWith(fontWeight: FontWeight.w600)),
        SizedBox(height: 4.h),
        _gstRow('Taxable Amount', r.taxableAmount),
        _gstRow('CGST (${(_gstRate/2).toStringAsFixed(1)}%)', r.cgst),
        _gstRow('SGST (${(_gstRate/2).toStringAsFixed(1)}%)', r.sgst),
        Divider(height: 8.h, color: AppTheme.divider),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('Total GST', style: AppTheme.body.copyWith(fontWeight: FontWeight.w600)),
          Text('₹${r.gstAmount.toStringAsFixed(2)}', style: AppTheme.body.copyWith(fontWeight: FontWeight.w700, color: AppTheme.primary)),
        ]),
      ]),
    );
  }
  Widget _gstRow(String l, double v) => Padding(padding: EdgeInsets.symmetric(vertical: 1.h), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(l, style: AppTheme.caption), Text('₹${v.toStringAsFixed(2)}', style: AppTheme.caption)]));
}