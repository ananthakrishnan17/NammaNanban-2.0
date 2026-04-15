import 'package:NammaNanban/features/users/domain/entities/product_uom.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../../../../core/theme/app_theme.dart';

import '../../../masters/domain/entities/masters.dart';

/// Shows a list of UOM+price rows that can be added/removed.
/// Used inside AddEditProductPage.
class MultiUomEditor extends StatefulWidget {
  final int productId;
  final List<UomUnit> availableUnits;
  final List<ProductUom> initialUoms;
  final void Function(List<ProductUom>) onChanged;

  const MultiUomEditor({
    super.key,
    required this.productId,
    required this.availableUnits,
    required this.initialUoms,
    required this.onChanged,
  });

  @override
  State<MultiUomEditor> createState() => _MultiUomEditorState();
}

class _MultiUomEditorState extends State<MultiUomEditor> {
  late List<_UomRow> _rows;

  @override
  void initState() {
    super.initState();
    _rows = widget.initialUoms
        .map((u) => _UomRow.fromProductUom(u, widget.availableUnits))
        .toList();
    if (_rows.isEmpty) _addRow(); // start with one empty row
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
    final uoms = _rows
        .where((r) => r.selectedUnit != null)
        .toList()
        .asMap()
        .entries
        .map((e) => ProductUom(
      productId: widget.productId,
      uomId: e.value.selectedUnit!.id!,
      uomName: e.value.selectedUnit!.name,
      uomShortName: e.value.selectedUnit!.shortName,
      conversionQty: e.value.conversionQty,
      sellingPrice: e.value.sellingPrice,
      wholesalePrice: e.value.wholesalePrice,
      purchasePrice: e.value.purchasePrice,
      isDefault: e.key == 0,
    ))
        .toList();
    widget.onChanged(uoms);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Expanded(child: Text('Multiple Units & Prices', style: AppTheme.heading3.copyWith(color: AppTheme.primary))),
          TextButton.icon(
            onPressed: _addRow,
            icon: const Icon(Icons.add, size: 16),
            label: const Text('Add UOM'),
          ),
        ]),
        Text('Sell the same product in different units (e.g. Piece ₹10, Dozen ₹110)', style: AppTheme.caption),
        SizedBox(height: 10.h),

        // Column headers
        Container(
          padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
          decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(8.r)),
          child: Row(children: [
            SizedBox(width: 100.w, child: Text('Unit', style: AppTheme.caption.copyWith(fontWeight: FontWeight.w600))),
            SizedBox(width: 6.w),
            SizedBox(width: 60.w, child: Text('Conv.', style: AppTheme.caption.copyWith(fontWeight: FontWeight.w600))),
            SizedBox(width: 6.w),
            Expanded(child: Text('Retail ₹', style: AppTheme.caption.copyWith(fontWeight: FontWeight.w600))),
            SizedBox(width: 6.w),
            Expanded(child: Text('Wholesale ₹', style: AppTheme.caption.copyWith(fontWeight: FontWeight.w600))),
            SizedBox(width: 30.w),
          ]),
        ),
        SizedBox(height: 6.h),

        // Rows
        ..._rows.asMap().entries.map((entry) {
          final i = entry.key;
          final row = entry.value;
          return _buildRow(i, row);
        }),
      ],
    );
  }

  Widget _buildRow(int index, _UomRow row) {
    final isDefault = index == 0;
    return Container(
      margin: EdgeInsets.only(bottom: 8.h),
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: isDefault ? AppTheme.primary.withOpacity(0.04) : Colors.white,
        borderRadius: BorderRadius.circular(10.r),
        border: Border.all(color: isDefault ? AppTheme.primary.withOpacity(0.3) : AppTheme.divider),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
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
                child: Text('${u.name}\n(${u.shortName})', style: TextStyle(fontSize: 11.sp, fontFamily: 'Poppins')),
              )).toList(),
              onChanged: (u) {
                setState(() => row.selectedUnit = u);
                _notify();
              },
            ),
          ),
        ),
        SizedBox(width: 6.w),

        // Conversion qty
        SizedBox(
          width: 60.w,
          child: TextFormField(
            initialValue: row.conversionQty == 1.0 ? '1' : row.conversionQty.toString(),
            keyboardType: TextInputType.number,
            style: TextStyle(fontSize: 12.sp, fontFamily: 'Poppins'),
            decoration: InputDecoration(
              hintText: '1',
              contentPadding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 8.h),
              isDense: true,
            ),
            onChanged: (v) {
              row.conversionQty = double.tryParse(v) ?? 1.0;
              _notify();
            },
          ),
        ),
        SizedBox(width: 6.w),

        // Retail price
        Expanded(
          child: TextFormField(
            initialValue: row.sellingPrice > 0 ? row.sellingPrice.toStringAsFixed(2) : '',
            keyboardType: TextInputType.number,
            style: TextStyle(fontSize: 12.sp, fontFamily: 'Poppins', color: AppTheme.primary, fontWeight: FontWeight.w600),
            decoration: InputDecoration(
              hintText: '0.00',
              contentPadding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 8.h),
              isDense: true,
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
            initialValue: row.wholesalePrice > 0 ? row.wholesalePrice.toStringAsFixed(2) : '',
            keyboardType: TextInputType.number,
            style: TextStyle(fontSize: 12.sp, fontFamily: 'Poppins', color: AppTheme.secondary),
            decoration: InputDecoration(
              hintText: '0.00',
              contentPadding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 8.h),
              isDense: true,
            ),
            onChanged: (v) {
              row.wholesalePrice = double.tryParse(v) ?? 0;
              _notify();
            },
          ),
        ),

        // Remove button (keep at least 1 row)
        SizedBox(
          width: 28.w,
          child: IconButton(
            padding: EdgeInsets.zero,
            icon: Icon(
              isDefault ? Icons.star : Icons.remove_circle_outline,
              color: isDefault ? AppTheme.warning : AppTheme.danger,
              size: 18.sp,
            ),
            tooltip: isDefault ? 'Default UOM' : 'Remove',
            onPressed: isDefault ? null : () => _removeRow(index),
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
  final List<UomUnit> units;

  _UomRow({
    this.selectedUnit,
    this.conversionQty = 1.0,
    this.sellingPrice = 0.0,
    this.wholesalePrice = 0.0,
    this.purchasePrice = 0.0,
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