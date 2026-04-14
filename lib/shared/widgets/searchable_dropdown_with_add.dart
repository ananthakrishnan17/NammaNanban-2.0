import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../core/theme/app_theme.dart';

/// A searchable dropdown that shows a list of items and allows inline creation.
/// Used for Category, Brand, Unit selection in product screen.
class SearchableDropdownWithAdd<T> extends StatefulWidget {
  final String label;
  final String hint;
  final IconData icon;
  final T? selectedValue;
  final List<T> items;
  final String Function(T) itemLabel;
  final int? Function(T) itemId;
  final void Function(T?) onChanged;
  final Future<T?> Function(String name) onAddNew; // returns newly created item
  final String addNewLabel;

  const SearchableDropdownWithAdd({
    super.key,
    required this.label,
    required this.hint,
    required this.icon,
    required this.selectedValue,
    required this.items,
    required this.itemLabel,
    required this.itemId,
    required this.onChanged,
    required this.onAddNew,
    this.addNewLabel = 'Add New',
  });

  @override State<SearchableDropdownWithAdd<T>> createState() => _State<T>();
}

class _State<T> extends State<SearchableDropdownWithAdd<T>> {
  @override
  Widget build(BuildContext context) {
    final selectedLabel = widget.selectedValue != null
        ? widget.itemLabel(widget.selectedValue as T)
        : null;

    return GestureDetector(
      onTap: () => _showPicker(context),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 14.h),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: AppTheme.divider),
        ),
        child: Row(
          children: [
            Icon(widget.icon, size: 18.sp, color: AppTheme.textSecondary),
            SizedBox(width: 10.w),
            Expanded(
              child: Text(
                selectedLabel ?? widget.hint,
                style: selectedLabel != null
                    ? AppTheme.body
                    : AppTheme.body.copyWith(color: AppTheme.textSecondary),
              ),
            ),
            if (widget.selectedValue != null)
              GestureDetector(
                onTap: () => widget.onChanged(null),
                child: Icon(Icons.close, size: 16.sp, color: AppTheme.textSecondary),
              )
            else
              Icon(Icons.arrow_drop_down, color: AppTheme.textSecondary, size: 22.sp),
          ],
        ),
      ),
    );
  }

  void _showPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PickerSheet<T>(
        label: widget.label,
        items: widget.items,
        selectedValue: widget.selectedValue,
        itemLabel: widget.itemLabel,
        itemId: widget.itemId,
        onSelect: (item) {
          widget.onChanged(item);
          Navigator.pop(context);
        },
        onAddNew: (name) async {
          final created = await widget.onAddNew(name);
          if (created != null && context.mounted) {
            widget.onChanged(created);
            Navigator.pop(context);
          }
        },
        addNewLabel: widget.addNewLabel,
      ),
    );
  }
}

class _PickerSheet<T> extends StatefulWidget {
  final String label;
  final List<T> items;
  final T? selectedValue;
  final String Function(T) itemLabel;
  final int? Function(T) itemId;
  final void Function(T) onSelect;
  final Future<void> Function(String) onAddNew;
  final String addNewLabel;

  const _PickerSheet({
    required this.label, required this.items, required this.selectedValue,
    required this.itemLabel, required this.itemId,
    required this.onSelect, required this.onAddNew, required this.addNewLabel,
  });

  @override State<_PickerSheet<T>> createState() => _PickerSheetState<T>();
}

class _PickerSheetState<T> extends State<_PickerSheet<T>> {
  final _searchCtrl = TextEditingController();
  final _newNameCtrl = TextEditingController();
  List<T> _filtered = [];
  bool _showAddField = false;
  bool _isAdding = false;

  @override
  void initState() {
    super.initState();
    _filtered = widget.items;
    _searchCtrl.addListener(_onSearch);
  }

  @override void dispose() { _searchCtrl.dispose(); _newNameCtrl.dispose(); super.dispose(); }

  void _onSearch() {
    final q = _searchCtrl.text.toLowerCase();
    setState(() {
      _filtered = q.isEmpty
          ? widget.items
          : widget.items.where((i) => widget.itemLabel(i).toLowerCase().contains(q)).toList();
      _showAddField = q.isNotEmpty && _filtered.isEmpty;
      if (_showAddField) _newNameCtrl.text = _searchCtrl.text;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
      ),
      child: Column(
        children: [
          // Handle
          SizedBox(height: 12.h),
          Container(width: 40.w, height: 4.h,
              decoration: BoxDecoration(color: AppTheme.divider, borderRadius: BorderRadius.circular(2.r))),
          SizedBox(height: 12.h),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            child: Text('Select ${widget.label}', style: AppTheme.heading3),
          ),
          SizedBox(height: 12.h),

          // Search
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            child: TextField(
              controller: _searchCtrl,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Search or type new ${widget.label.toLowerCase()}...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(icon: const Icon(Icons.clear), onPressed: () { _searchCtrl.clear(); })
                    : null,
              ),
            ),
          ),
          SizedBox(height: 8.h),

          // Add new inline
          if (_showAddField || _newNameCtrl.text.isNotEmpty && _filtered.isEmpty)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 4.h),
              child: Container(
                padding: EdgeInsets.all(12.w),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border.all(color: AppTheme.primary.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.add_circle_outline, color: AppTheme.primary, size: 20.sp),
                    SizedBox(width: 10.w),
                    Expanded(child: Text(
                      '${widget.addNewLabel}: "${_searchCtrl.text}"',
                      style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w500,
                          fontSize: 13.sp, fontFamily: 'Poppins'),
                    )),
                    TextButton(
                      onPressed: _isAdding ? null : () async {
                        setState(() => _isAdding = true);
                        await widget.onAddNew(_searchCtrl.text.trim());
                        setState(() => _isAdding = false);
                      },
                      child: _isAdding
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('Add'),
                    ),
                  ],
                ),
              ),
            ),

          // Items list
          Expanded(
            child: _filtered.isEmpty && !_showAddField
                ? Center(child: Text('No items found', style: AppTheme.caption))
                : ListView.builder(
              itemCount: _filtered.length,
              itemBuilder: (_, i) {
                final item = _filtered[i];
                final isSelected = widget.selectedValue != null &&
                    widget.itemId(widget.selectedValue as T) == widget.itemId(item);
                return ListTile(
                  title: Text(widget.itemLabel(item), style: AppTheme.body),
                  trailing: isSelected
                      ? Icon(Icons.check_circle, color: AppTheme.primary, size: 20.sp)
                      : null,
                  tileColor: isSelected ? AppTheme.primary.withOpacity(0.05) : null,
                  onTap: () => widget.onSelect(item),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}