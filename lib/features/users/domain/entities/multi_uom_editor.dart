import 'package:NammaNanban/features/users/domain/entities/product_uom.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../../../../core/theme/app_theme.dart';

import '../../../masters/domain/entities/masters.dart';

/// Editing mode for [MultiUomEditor].
enum UomEditorMode {
  /// Units used when buying stock from supplier.
  /// Only unit name, conversion, and default flag are needed.
  purchase,

  /// Units offered to customers during billing.
  /// Unit name, conversion, retail price, and optional wholesale price.
  sale,
}

/// An editor widget that manages a list of UOM rows.
///
/// Pass [mode] = [UomEditorMode.purchase] for the Purchase Units section, or
/// [mode] = [UomEditorMode.sale] for the Sale Units & Prices section.
class MultiUomEditor extends StatefulWidget {
  final int productId;
  final List<UomUnit> availableUnits;
  final List<ProductUom> initialUoms;
  final void Function(List<ProductUom>) onChanged;
  final UomEditorMode mode;
  /// Short name of the base stock unit (e.g. 'kg') for preview text.
  final String baseUnitShortName;

  const MultiUomEditor({
    super.key,
    required this.productId,
    required this.availableUnits,
    required this.initialUoms,
    required this.onChanged,
    this.mode = UomEditorMode.sale,
    this.baseUnitShortName = '',
  });

  @override
  State<MultiUomEditor> createState() => _MultiUomEditorState();
}

class _MultiUomEditorState extends State<MultiUomEditor> {
  late List<_UomRow> _rows;

  bool get _isPurchase => widget.mode == UomEditorMode.purchase;
  String get _unitRole => _isPurchase ? 'purchase' : 'sale';

  @override
  void initState() {
    super.initState();
    _rows = widget.initialUoms
        .map((u) => _UomRow.fromProductUom(u, widget.availableUnits))
        .toList();
    if (_rows.isEmpty) _addRow();
  }

  void _addRow() {
    setState(() {
      _rows.add(_UomRow(units: widget.availableUnits));
    });
  }

  void _removeRow(int index) {
    setState(() => _rows.removeAt(index));
    _notify();
  }

  void _notify() {
    // Validate no duplicate unit names
    final valid = _rows.where((r) => r.selectedUnit != null).toList();
    final uoms = valid.asMap().entries.map((e) {
      final row = e.value;
      return ProductUom(
        productId: widget.productId,
        uomId: row.selectedUnit!.id!,
        uomName: row.selectedUnit!.name,
        uomShortName: row.selectedUnit!.shortName,
        conversionQty: row.conversionQty,
        sellingPrice: row.sellingPrice,
        wholesalePrice: row.wholesalePrice,
        purchasePrice: 0.0,
        isDefault: e.key == 0,
        unitRole: _unitRole,
      );
    }).toList();
    widget.onChanged(uoms);
  }

  @override
  Widget build(BuildContext context) {
    final title = _isPurchase ? 'Purchase Units' : 'Sale Units & Prices';
    final addLabel = _isPurchase ? 'Add Purchase Unit' : 'Add Sale Unit';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header row
        Row(children: [
          Expanded(
            child: Text(title,
                style: AppTheme.heading3.copyWith(color: AppTheme.primary)),
          ),
          TextButton.icon(
            onPressed: _addRow,
            icon: Icon(Icons.add, size: 16.sp),
            label: Text(addLabel, style: TextStyle(fontSize: 12.sp)),
          ),
        ]),
        Text(
          _isPurchase
              ? 'Units used when purchasing stock from supplier.'
              : 'Units offered to customers during billing.',
          style: AppTheme.caption,
        ),
        SizedBox(height: 10.h),

        // Column headers
        if (_rows.isNotEmpty) _buildHeaders(),
        SizedBox(height: 6.h),

        // Rows
        ..._rows.asMap().entries.map((entry) =>
            _buildRow(entry.key, entry.value)),
      ],
    );
  }

  Widget _buildHeaders() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
      decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(8.r)),
      child: Row(children: [
        SizedBox(
            width: 100.w,
            child: Text('Unit',
                style: AppTheme.caption
                    .copyWith(fontWeight: FontWeight.w600))),
        SizedBox(width: 6.w),
        SizedBox(
            width: 64.w,
            child: Text('Conv. to base',
                style: AppTheme.caption
                    .copyWith(fontWeight: FontWeight.w600),
                maxLines: 2)),
        if (!_isPurchase) ...[
          SizedBox(width: 6.w),
          Expanded(
              child: Text('Retail ₹',
                  style: AppTheme.caption
                      .copyWith(fontWeight: FontWeight.w600))),
          SizedBox(width: 6.w),
          Expanded(
              child: Text('Wholesale ₹',
                  style: AppTheme.caption
                      .copyWith(fontWeight: FontWeight.w600))),
        ],
        SizedBox(width: 30.w),
      ]),
    );
  }

  Widget _buildRow(int index, _UomRow row) {
    final isDefault = index == 0;
    final base = widget.baseUnitShortName;
    final qty = row.conversionQty;
    final unitLabel = row.selectedUnit?.shortName ?? '';

    // Conversion preview text
    String preview = '';
    if (unitLabel.isNotEmpty && base.isNotEmpty && qty > 0) {
      final qtyStr = qty == qty.truncateToDouble()
          ? qty.toInt().toString()
          : qty.toString();
      preview = _isPurchase
          ? '1 $unitLabel = $qtyStr $base'
          : 'Selling 1 $unitLabel reduces $qtyStr $base from stock';
    }

    return Container(
      margin: EdgeInsets.only(bottom: 10.h),
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: isDefault
            ? AppTheme.primary.withOpacity(0.04)
            : Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(
            color: isDefault
                ? AppTheme.primary.withOpacity(0.3)
                : AppTheme.divider),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          // Unit dropdown
          SizedBox(
            width: 100.w,
            child: DropdownButtonHideUnderline(
              child: DropdownButton<UomUnit>(
                isExpanded: true,
                value: row.selectedUnit,
                hint: Text('Unit', style: AppTheme.caption),
                items: widget.availableUnits.map((u) => DropdownMenuItem(
                  value: u,
                  child: Text(
                    '${u.name}\n(${u.shortName})',
                    style: TextStyle(fontSize: 11.sp, fontFamily: 'Poppins'),
                  ),
                )).toList(),
                onChanged: (u) {
                  // Prevent duplicate unit selection
                  final alreadyUsed = _rows
                      .where((r) => r != row && r.selectedUnit?.id == u?.id)
                      .isNotEmpty;
                  if (alreadyUsed) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(
                            '${u?.name} is already added. Use a different unit.'),
                        duration: const Duration(seconds: 2)));
                    return;
                  }
                  setState(() => row.selectedUnit = u);
                  _notify();
                },
              ),
            ),
          ),
          SizedBox(width: 6.w),

          // Conversion qty
          SizedBox(
            width: 64.w,
            child: TextFormField(
              initialValue: row.conversionQty == 1.0
                  ? '1'
                  : row.conversionQty.toString(),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              style: TextStyle(fontSize: 12.sp, fontFamily: 'Poppins'),
              decoration: InputDecoration(
                hintText: 'e.g. 22',
                contentPadding: EdgeInsets.symmetric(
                    horizontal: 8.w, vertical: 8.h),
                isDense: true,
                helperText: base.isNotEmpty ? '= ? $base' : null,
                helperStyle: TextStyle(fontSize: 9.sp),
                errorText: row.showConversionError ? '> 0' : null,
              ),
              onChanged: (v) {
                final val = double.tryParse(v);
                setState(() {
                  row.conversionQty = val ?? row.conversionQty;
                  row.showConversionError = val == null || val <= 0;
                });
                if (val != null && val > 0) _notify();
              },
            ),
          ),

          if (!_isPurchase) ...[
            SizedBox(width: 6.w),
            // Retail price
            Expanded(
              child: TextFormField(
                initialValue: row.sellingPrice > 0
                    ? row.sellingPrice.toStringAsFixed(2)
                    : '',
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                style: TextStyle(
                    fontSize: 12.sp,
                    fontFamily: 'Poppins',
                    color: AppTheme.primary,
                    fontWeight: FontWeight.w600),
                decoration: InputDecoration(
                  hintText: '0.00',
                  contentPadding: EdgeInsets.symmetric(
                      horizontal: 8.w, vertical: 8.h),
                  isDense: true,
                  prefixText: '₹',
                ),
                onChanged: (v) {
                  row.sellingPrice = double.tryParse(v) ?? 0;
                  _notify();
                },
              ),
            ),
            SizedBox(width: 6.w),
            // Wholesale price
            Expanded(
              child: TextFormField(
                initialValue: row.wholesalePrice > 0
                    ? row.wholesalePrice.toStringAsFixed(2)
                    : '',
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                style: TextStyle(
                    fontSize: 12.sp,
                    fontFamily: 'Poppins',
                    color: AppTheme.secondary),
                decoration: InputDecoration(
                  hintText: '0.00',
                  contentPadding: EdgeInsets.symmetric(
                      horizontal: 8.w, vertical: 8.h),
                  isDense: true,
                  prefixText: '₹',
                ),
                onChanged: (v) {
                  row.wholesalePrice = double.tryParse(v) ?? 0;
                  _notify();
                },
              ),
            ),
          ],

          // Default / remove button
          SizedBox(
            width: 30.w,
            child: IconButton(
              padding: EdgeInsets.zero,
              icon: Icon(
                isDefault ? Icons.star : Icons.remove_circle_outline,
                color: isDefault ? AppTheme.warning : AppTheme.danger,
                size: 18.sp,
              ),
              tooltip: isDefault ? 'Default unit' : 'Remove',
              onPressed: isDefault ? null : () => _removeRow(index),
            ),
          ),
        ]),

        // Conversion preview chip
        if (preview.isNotEmpty)
          Padding(
            padding: EdgeInsets.only(top: 6.h),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.07),
                borderRadius: BorderRadius.circular(6.r),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.info_outline,
                    size: 12.sp, color: AppTheme.primary),
                SizedBox(width: 4.w),
                Text(preview,
                    style: AppTheme.caption.copyWith(
                        color: AppTheme.primary,
                        fontWeight: FontWeight.w600)),
              ]),
            ),
          ),
      ]),
    );
  }
}

// ─── Row state ────────────────────────────────────────────────────────────────
class _UomRow {
  UomUnit? selectedUnit;
  double conversionQty;
  double sellingPrice;
  double wholesalePrice;
  double purchasePrice;
  bool showConversionError;
  final List<UomUnit> units;

  _UomRow({
    this.selectedUnit,
    this.conversionQty = 1.0,
    this.sellingPrice = 0.0,
    this.wholesalePrice = 0.0,
    this.purchasePrice = 0.0,
    this.showConversionError = false,
    required this.units,
  });

  factory _UomRow.fromProductUom(ProductUom pu, List<UomUnit> units) {
    final unit = units.where((u) => u.id == pu.uomId).firstOrNull;
    return _UomRow(
      selectedUnit: unit,
      conversionQty: pu.conversionQty,
      sellingPrice: pu.sellingPrice,
      wholesalePrice: pu.wholesalePrice,
      purchasePrice: pu.purchasePrice,
      units: units,
    );
  }
}