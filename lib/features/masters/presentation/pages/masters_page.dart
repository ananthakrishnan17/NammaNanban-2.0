import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../products/domain/entities/product.dart';
import '../../../products/presentation/bloc/product_bloc.dart';
import '../../domain/entities/masters.dart';
import '../bloc/masters_bloc.dart';

class MastersPage extends StatefulWidget {
  const MastersPage({super.key});
  @override State<MastersPage> createState() => _MastersPageState();
}

class _MastersPageState extends State<MastersPage> with SingleTickerProviderStateMixin {
  late TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 5, vsync: this);
    // Load both masters and products (for categories)
    context.read<MastersBloc>().add(LoadAllMasters());
    context.read<ProductBloc>().add(LoadProducts());
  }

  @override void dispose() { _tabs.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Masters'),
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          labelColor: AppTheme.primary,
          unselectedLabelColor: AppTheme.textSecondary,
          indicatorColor: AppTheme.primary,
          tabs: const [
            Tab(text: '🏷️ Category'),
            Tab(text: '🏭 Brand'),
            Tab(text: '📏 Unit'),
            Tab(text: '👤 Customer'),
            Tab(text: '🚚 Supplier'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          // ✅ FIXED: Category tab uses ProductBloc
          const _CategoryMasterTab(),
          // Brand uses MastersBloc
          BlocBuilder<MastersBloc, MastersState>(
            builder: (ctx, state) => _SimpleMasterTab(
              title: 'Brand',
              items: state.brands.map((b) => _MItem(id: b.id!, label: b.name, sub: b.description)).toList(),
              onAdd: (name) => ctx.read<MastersBloc>().add(AddBrand(name)),
              onDelete: (id) => ctx.read<MastersBloc>().add(DeleteBrand(id)),
            ),
          ),
          // Unit
          BlocBuilder<MastersBloc, MastersState>(
            builder: (ctx, state) => _UnitMasterTab(units: state.units),
          ),
          // Customer
          BlocBuilder<MastersBloc, MastersState>(
            builder: (ctx, state) => _CustomerMasterTab(customers: state.customers),
          ),
          // Supplier
          BlocBuilder<MastersBloc, MastersState>(
            builder: (ctx, state) => _SupplierMasterTab(suppliers: state.suppliers),
          ),
        ],
      ),
    );
  }
}

// ─── Helper model ─────────────────────────────────────────────────────────────
class _MItem {
  final int id; final String label; final String? sub;
  _MItem({required this.id, required this.label, this.sub});
}

// ─── ✅ FIXED: Category Master Tab — uses ProductBloc ──────────────────────────
class _CategoryMasterTab extends StatefulWidget {
  const _CategoryMasterTab();
  @override State<_CategoryMasterTab> createState() => _CategoryMasterTabState();
}

class _CategoryMasterTabState extends State<_CategoryMasterTab> {
  final _nameCtrl = TextEditingController();
  String _selectedIcon = '📦';
  String _selectedColor = '#FF6B35';

  final List<String> _icons = ['📦', '☕', '🍱', '🍪', '🍬', '🥖', '🧃', '🍫', '🥤', '🌾', '🏠', '🛒', '💊', '🧴', '👗', '📱', '⚡', '🔧'];
  final List<Map<String, String>> _colors = [
    {'hex': '#FF6B35', 'name': 'Orange'},
    {'hex': '#4CAF50', 'name': 'Green'},
    {'hex': '#E91E63', 'name': 'Pink'},
    {'hex': '#2196F3', 'name': 'Blue'},
    {'hex': '#FF9800', 'name': 'Amber'},
    {'hex': '#9C27B0', 'name': 'Purple'},
    {'hex': '#F44336', 'name': 'Red'},
    {'hex': '#009688', 'name': 'Teal'},
    {'hex': '#795548', 'name': 'Brown'},
    {'hex': '#9E9E9E', 'name': 'Grey'},
  ];

  @override void dispose() { _nameCtrl.dispose(); super.dispose(); }

  Color _fromHex(String hex) {
    final h = hex.replaceAll('#', '');
    return Color(int.parse('FF$h', radix: 16));
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ProductBloc, ProductState>(
      builder: (ctx, state) {
        final categories = state is ProductsLoaded ? state.categories : <Category>[];
        return Column(
          children: [
            // ── Add Category Form ────────────────────────────────────────────
            Container(
              margin: EdgeInsets.all(12.w),
              padding: EdgeInsets.all(14.w),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14.r),
                border: Border.all(color: AppTheme.divider),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Add New Category', style: AppTheme.heading3),
                SizedBox(height: 10.h),

                // Name input
                TextField(
                  controller: _nameCtrl,
                  decoration: InputDecoration(
                    hintText: 'Category name (e.g. Beverages)',
                    prefixText: '$_selectedIcon  ',
                    suffixIcon: IconButton(
                      onPressed: _addCategory,
                      icon: Container(
                        padding: EdgeInsets.all(8.w),
                        decoration: BoxDecoration(color: AppTheme.primary, borderRadius: BorderRadius.circular(8.r)),
                        child: Icon(Icons.add, color: Colors.white, size: 18.sp),
                      ),
                    ),
                  ),
                  onSubmitted: (_) => _addCategory(),
                ),
                SizedBox(height: 12.h),

                // Icon picker
                Text('Icon', style: AppTheme.caption),
                SizedBox(height: 6.h),
                SizedBox(
                  height: 44.h,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _icons.length,
                    separatorBuilder: (_, __) => SizedBox(width: 6.w),
                    itemBuilder: (_, i) {
                      final isSelected = _selectedIcon == _icons[i];
                      return GestureDetector(
                        onTap: () => setState(() => _selectedIcon = _icons[i]),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          width: 40.w, height: 40.h,
                          decoration: BoxDecoration(
                            color: isSelected ? AppTheme.primary.withOpacity(0.15) : AppTheme.surface,
                            borderRadius: BorderRadius.circular(8.r),
                            border: Border.all(color: isSelected ? AppTheme.primary : AppTheme.divider, width: isSelected ? 2 : 1),
                          ),
                          child: Center(child: Text(_icons[i], style: TextStyle(fontSize: 18.sp))),
                        ),
                      );
                    },
                  ),
                ),
                SizedBox(height: 10.h),

                // Color picker
                Text('Color', style: AppTheme.caption),
                SizedBox(height: 6.h),
                SizedBox(
                  height: 36.h,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _colors.length,
                    separatorBuilder: (_, __) => SizedBox(width: 6.w),
                    itemBuilder: (_, i) {
                      final isSelected = _selectedColor == _colors[i]['hex'];
                      return GestureDetector(
                        onTap: () => setState(() => _selectedColor = _colors[i]['hex']!),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          width: 32.w, height: 32.h,
                          decoration: BoxDecoration(
                            color: _fromHex(_colors[i]['hex']!),
                            shape: BoxShape.circle,
                            border: Border.all(color: isSelected ? Colors.black54 : Colors.transparent, width: 2.5),
                          ),
                          child: isSelected ? const Icon(Icons.check, color: Colors.white, size: 16) : null,
                        ),
                      );
                    },
                  ),
                ),
              ]),
            ),

            // ── Category List ────────────────────────────────────────────────
            Expanded(
              child: categories.isEmpty
                  ? Center(
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text('🏷️', style: TextStyle(fontSize: 48.sp)),
                  SizedBox(height: 12.h),
                  Text('No categories yet', style: AppTheme.heading3),
                  SizedBox(height: 4.h),
                  Text('Add your first category above', style: AppTheme.caption),
                ]),
              )
                  : ListView.separated(
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
                itemCount: categories.length,
                separatorBuilder: (_, __) => SizedBox(height: 8.h),
                itemBuilder: (ctx2, i) => _categoryTile(ctx2, categories[i]),
              ),
            ),
          ],
        );
      },
    );
  }

  void _addCategory() {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    context.read<ProductBloc>().add(AddCategoryEvent(name, icon: _selectedIcon, color: _selectedColor));
    _nameCtrl.clear();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('$_selectedIcon $name added!'),
      backgroundColor: AppTheme.accent,
      duration: const Duration(seconds: 1),
      behavior: SnackBarBehavior.floating,
    ));
  }

  Widget _categoryTile(BuildContext ctx, Category cat) {
    Color catColor = AppTheme.primary;
    try {
      final h = cat.color.replaceAll('#', '');
      catColor = Color(int.parse('FF$h', radix: 16));
    } catch (_) {}

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: AppTheme.divider),
      ),
      child: ListTile(
        leading: Container(
          width: 42.w, height: 42.h,
          decoration: BoxDecoration(color: catColor.withOpacity(0.15), borderRadius: BorderRadius.circular(10.r)),
          child: Center(child: Text(cat.icon, style: TextStyle(fontSize: 20.sp))),
        ),
        title: Text(cat.name, style: AppTheme.heading3),
        subtitle: Text('Icon: ${cat.icon}  •  Color: ${cat.color}', style: AppTheme.caption),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline, color: AppTheme.danger),
          onPressed: () => _confirmDelete(ctx, cat),
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext ctx, Category cat) {
    showDialog(
      context: ctx,
      builder: (_) => AlertDialog(
        title: const Text('Delete Category?'),
        content: Text('Delete "${cat.icon} ${cat.name}"?\n\nProducts in this category will not be deleted, but will lose their category.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              ctx.read<ProductBloc>().add(DeleteCategoryEvent(cat.id!));
              Navigator.pop(ctx);
            },
            child: const Text('Delete', style: TextStyle(color: AppTheme.danger)),
          ),
        ],
      ),
    );
  }
}

// ─── Simple Master Tab (for Brand) ────────────────────────────────────────────
class _SimpleMasterTab extends StatefulWidget {
  final String title;
  final List<_MItem> items;
  final void Function(String) onAdd;
  final void Function(int) onDelete;
  final String? emptyMsg;
  const _SimpleMasterTab({required this.title, required this.items, required this.onAdd, required this.onDelete, this.emptyMsg});
  @override State<_SimpleMasterTab> createState() => _SimpleMasterTabState();
}

class _SimpleMasterTabState extends State<_SimpleMasterTab> {
  final _ctrl = TextEditingController();
  @override void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.all(12.w),
          child: Row(children: [
            Expanded(
              child: TextField(
                controller: _ctrl,
                decoration: InputDecoration(hintText: 'New ${widget.title} name', prefixIcon: const Icon(Icons.add_circle_outline)),
                onSubmitted: (_) => _doAdd(),
              ),
            ),
            SizedBox(width: 8.w),
            ElevatedButton(
              onPressed: _doAdd,
              style: ElevatedButton.styleFrom(minimumSize: Size(60.w, 48.h), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r))),
              child: const Text('Add'),
            ),
          ]),
        ),
        Expanded(
          child: widget.items.isEmpty
              ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text('🏭', style: TextStyle(fontSize: 48.sp)),
            SizedBox(height: 12.h),
            Text(widget.emptyMsg ?? 'No ${widget.title.toLowerCase()}s yet', style: AppTheme.heading3),
            SizedBox(height: 4.h),
            Text('Type above and tap Add', style: AppTheme.caption),
          ]))
              : ListView.separated(
            padding: EdgeInsets.symmetric(horizontal: 12.w),
            itemCount: widget.items.length,
            separatorBuilder: (_, __) => SizedBox(height: 8.h),
            itemBuilder: (_, i) {
              final item = widget.items[i];
              return Container(
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12.r), border: Border.all(color: AppTheme.divider)),
                child: ListTile(
                  leading: Container(width: 36.w, height: 36.h,
                      decoration: BoxDecoration(color: AppTheme.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(8.r)),
                      child: Center(child: Text(widget.title[0], style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w700, fontFamily: 'Poppins', fontSize: 16.sp)))),
                  title: Text(item.label, style: AppTheme.body),
                  subtitle: item.sub != null && item.sub!.isNotEmpty ? Text(item.sub!, style: AppTheme.caption) : null,
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline, color: AppTheme.danger),
                    onPressed: () => _confirmDelete(context, item),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _doAdd() {
    if (_ctrl.text.trim().isEmpty) return;
    widget.onAdd(_ctrl.text.trim()); _ctrl.clear();
  }

  void _confirmDelete(BuildContext ctx, _MItem item) => showDialog(
    context: ctx, builder: (_) => AlertDialog(
    title: Text('Delete ${widget.title}?'),
    content: Text('Delete "${item.label}"?'),
    actions: [
      TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
      TextButton(onPressed: () { widget.onDelete(item.id); Navigator.pop(ctx); },
          child: const Text('Delete', style: TextStyle(color: AppTheme.danger))),
    ],
  ),
  );
}

// ─── Unit Master Tab ──────────────────────────────────────────────────────────
class _UnitMasterTab extends StatefulWidget {
  final List<UomUnit> units;
  const _UnitMasterTab({required this.units});
  @override State<_UnitMasterTab> createState() => _UnitMasterTabState();
}

class _UnitMasterTabState extends State<_UnitMasterTab> {
  final _nameCtrl = TextEditingController();
  final _shortCtrl = TextEditingController();
  String _uomType = 'count';

  @override void dispose() { _nameCtrl.dispose(); _shortCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          margin: EdgeInsets.all(12.w),
          padding: EdgeInsets.all(14.w),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14.r), border: Border.all(color: AppTheme.divider)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Add New Unit', style: AppTheme.heading3),
            SizedBox(height: 10.h),
            Row(children: [
              Expanded(child: TextField(controller: _nameCtrl, decoration: const InputDecoration(labelText: 'Unit Name', hintText: 'e.g. Kilogram'))),
              SizedBox(width: 8.w),
              SizedBox(width: 80.w, child: TextField(controller: _shortCtrl, decoration: const InputDecoration(labelText: 'Short', hintText: 'Kg'))),
            ]),
            SizedBox(height: 8.h),
            Row(children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _uomType,
                  decoration: const InputDecoration(labelText: 'Type'),
                  items: [
                    const DropdownMenuItem(value: 'count', child: Text('Count (pcs)')),
                    const DropdownMenuItem(value: 'weight', child: Text('Weight (kg/g)')),
                    const DropdownMenuItem(value: 'volume', child: Text('Volume (L/ml)')),
                    const DropdownMenuItem(value: 'length', child: Text('Length (m/cm)')),
                  ],
                  onChanged: (v) => setState(() => _uomType = v!),
                ),
              ),
              SizedBox(width: 8.w),
              ElevatedButton(
                onPressed: () {
                  if (_nameCtrl.text.trim().isEmpty || _shortCtrl.text.trim().isEmpty) return;
                  context.read<MastersBloc>().add(AddUnit(UomUnit(
                      name: _nameCtrl.text.trim(), shortName: _shortCtrl.text.trim(),
                      uomType: _uomType, createdAt: DateTime.now())));
                  _nameCtrl.clear(); _shortCtrl.clear();
                },
                style: ElevatedButton.styleFrom(minimumSize: Size(60.w, 48.h), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r))),
                child: const Text('Add'),
              ),
            ]),
          ]),
        ),
        Expanded(
          child: widget.units.isEmpty
              ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text('📏', style: TextStyle(fontSize: 48.sp)),
            SizedBox(height: 12.h), Text('No units yet', style: AppTheme.heading3),
            SizedBox(height: 4.h), Text('Add a unit above', style: AppTheme.caption),
          ]))
              : ListView.separated(
            padding: EdgeInsets.symmetric(horizontal: 12.w),
            itemCount: widget.units.length,
            separatorBuilder: (_, __) => SizedBox(height: 8.h),
            itemBuilder: (ctx, i) {
              final u = widget.units[i];
              return Container(
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12.r), border: Border.all(color: AppTheme.divider)),
                child: ListTile(
                  leading: Container(width: 36.w, height: 36.h,
                      decoration: BoxDecoration(color: AppTheme.secondary.withOpacity(0.1), borderRadius: BorderRadius.circular(8.r)),
                      child: Center(child: Text(u.shortName, style: TextStyle(color: AppTheme.secondary, fontWeight: FontWeight.w700, fontFamily: 'Poppins', fontSize: 11.sp)))),
                  title: Text('${u.name} (${u.shortName})', style: AppTheme.body),
                  subtitle: Text(u.uomType, style: AppTheme.caption),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline, color: AppTheme.danger),
                    onPressed: () => ctx.read<MastersBloc>().add(DeleteUnit(u.id!)),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ─── Customer Master Tab ──────────────────────────────────────────────────────
class _CustomerMasterTab extends StatelessWidget {
  final List<Customer> customers;
  const _CustomerMasterTab({required this.customers});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showForm(context, null),
        backgroundColor: AppTheme.primary,
        icon: const Icon(Icons.person_add, color: Colors.white),
        label: const Text('Add Customer', style: TextStyle(color: Colors.white)),
      ),
      body: customers.isEmpty
          ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text('👤', style: TextStyle(fontSize: 48.sp)),
        SizedBox(height: 12.h), Text('No customers yet', style: AppTheme.heading3),
        SizedBox(height: 4.h), Text('Tap + to add your first customer', style: AppTheme.caption),
      ]))
          : ListView.separated(
        padding: EdgeInsets.all(12.w),
        itemCount: customers.length,
        separatorBuilder: (_, __) => SizedBox(height: 8.h),
        itemBuilder: (ctx, i) => _tile(ctx, customers[i]),
      ),
    );
  }

  Widget _tile(BuildContext ctx, Customer c) => Container(
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14.r), border: Border.all(color: AppTheme.divider)),
    child: ListTile(
      leading: CircleAvatar(
        backgroundColor: AppTheme.primary.withOpacity(0.12),
        child: Text(c.name[0].toUpperCase(), style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w700, fontFamily: 'Poppins')),
      ),
      title: Text(c.name, style: AppTheme.heading3),
      subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (c.phone != null) Text('📞 ${c.phone}', style: AppTheme.caption),
        if (c.address != null) Text('📍 ${c.address}', style: AppTheme.caption, maxLines: 1, overflow: TextOverflow.ellipsis),
        if (c.gstNumber != null) Text('GST: ${c.gstNumber}', style: AppTheme.caption),
      ]),
      trailing: PopupMenuButton<String>(
        onSelected: (v) {
          if (v == 'edit') _showForm(ctx, c);
          if (v == 'delete') ctx.read<MastersBloc>().add(DeleteCustomer(c.id!));
        },
        itemBuilder: (_) => [
          const PopupMenuItem(value: 'edit', child: Text('Edit')),
          const PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: AppTheme.danger))),
        ],
      ),
    ),
  );

  void _showForm(BuildContext ctx, Customer? existing) {
    final nc = TextEditingController(text: existing?.name ?? '');
    final pc = TextEditingController(text: existing?.phone ?? '');
    final ac = TextEditingController(text: existing?.address ?? '');
    final gc = TextEditingController(text: existing?.gstNumber ?? '');
    showModalBottomSheet(
      context: ctx, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: EdgeInsets.only(left: 20.w, right: 20.w, top: 20.h, bottom: MediaQuery.of(ctx).viewInsets.bottom + 20.h),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24.r))),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(existing == null ? 'Add Customer' : 'Edit Customer', style: AppTheme.heading2),
          SizedBox(height: 16.h),
          TextField(controller: nc, decoration: const InputDecoration(labelText: 'Name *', prefixIcon: Icon(Icons.person))),
          SizedBox(height: 10.h),
          TextField(controller: pc, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Phone', prefixIcon: Icon(Icons.phone))),
          SizedBox(height: 10.h),
          TextField(controller: ac, decoration: const InputDecoration(labelText: 'Address', prefixIcon: Icon(Icons.location_on)), maxLines: 2),
          SizedBox(height: 10.h),
          TextField(controller: gc, decoration: const InputDecoration(labelText: 'GSTIN (optional)', prefixIcon: Icon(Icons.business))),
          SizedBox(height: 16.h),
          ElevatedButton(
            onPressed: () {
              if (nc.text.trim().isEmpty) return;
              final now = DateTime.now();
              final customer = Customer(
                id: existing?.id, name: nc.text.trim(),
                phone: pc.text.isEmpty ? null : pc.text,
                address: ac.text.isEmpty ? null : ac.text,
                gstNumber: gc.text.isEmpty ? null : gc.text,
                createdAt: existing?.createdAt ?? now, updatedAt: now,
              );
              if (existing == null) ctx.read<MastersBloc>().add(AddCustomer(customer));
              else ctx.read<MastersBloc>().add(UpdateCustomer(customer));
              Navigator.pop(ctx);
            },
            child: Text(existing == null ? 'Add Customer' : 'Update'),
          ),
        ]),
      ),
    );
  }
}

// ─── Supplier Master Tab ──────────────────────────────────────────────────────
class _SupplierMasterTab extends StatelessWidget {
  final List<Supplier> suppliers;
  const _SupplierMasterTab({required this.suppliers});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showForm(context, null),
        backgroundColor: AppTheme.secondary,
        icon: const Icon(Icons.local_shipping, color: Colors.white),
        label: const Text('Add Supplier', style: TextStyle(color: Colors.white)),
      ),
      body: suppliers.isEmpty
          ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text('🚚', style: TextStyle(fontSize: 48.sp)),
        SizedBox(height: 12.h), Text('No suppliers yet', style: AppTheme.heading3),
        SizedBox(height: 4.h), Text('Tap + to add', style: AppTheme.caption),
      ]))
          : ListView.separated(
        padding: EdgeInsets.all(12.w),
        itemCount: suppliers.length,
        separatorBuilder: (_, __) => SizedBox(height: 8.h),
        itemBuilder: (ctx, i) => _tile(ctx, suppliers[i]),
      ),
    );
  }

  Widget _tile(BuildContext ctx, Supplier s) => Container(
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14.r), border: Border.all(color: AppTheme.divider)),
    child: ListTile(
      leading: CircleAvatar(
        backgroundColor: AppTheme.secondary.withOpacity(0.12),
        child: Text(s.name[0].toUpperCase(), style: TextStyle(color: AppTheme.secondary, fontWeight: FontWeight.w700, fontFamily: 'Poppins')),
      ),
      title: Text(s.name, style: AppTheme.heading3),
      subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (s.phone != null) Text('📞 ${s.phone}', style: AppTheme.caption),
        if (s.gstNumber != null) Text('GST: ${s.gstNumber}', style: AppTheme.caption),
        if (s.outstandingBalance > 0)
          Text('Outstanding: ₹${s.outstandingBalance.toStringAsFixed(2)}',
              style: AppTheme.caption.copyWith(color: AppTheme.warning, fontWeight: FontWeight.w600)),
      ]),
      trailing: PopupMenuButton<String>(
        onSelected: (v) {
          if (v == 'edit') _showForm(ctx, s);
          if (v == 'delete') ctx.read<MastersBloc>().add(DeleteSupplier(s.id!));
        },
        itemBuilder: (_) => [
          const PopupMenuItem(value: 'edit', child: Text('Edit')),
          const PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: AppTheme.danger))),
        ],
      ),
    ),
  );

  void _showForm(BuildContext ctx, Supplier? existing) {
    final nc = TextEditingController(text: existing?.name ?? '');
    final pc = TextEditingController(text: existing?.phone ?? '');
    final ac = TextEditingController(text: existing?.address ?? '');
    final gc = TextEditingController(text: existing?.gstNumber ?? '');
    showModalBottomSheet(
      context: ctx, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: EdgeInsets.only(left: 20.w, right: 20.w, top: 20.h, bottom: MediaQuery.of(ctx).viewInsets.bottom + 20.h),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24.r))),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(existing == null ? 'Add Supplier' : 'Edit Supplier', style: AppTheme.heading2),
          SizedBox(height: 16.h),
          TextField(controller: nc, decoration: const InputDecoration(labelText: 'Supplier Name *', prefixIcon: Icon(Icons.business))),
          SizedBox(height: 10.h),
          TextField(controller: pc, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Phone', prefixIcon: Icon(Icons.phone))),
          SizedBox(height: 10.h),
          TextField(controller: ac, decoration: const InputDecoration(labelText: 'Address', prefixIcon: Icon(Icons.location_on))),
          SizedBox(height: 10.h),
          TextField(controller: gc, decoration: const InputDecoration(labelText: 'GSTIN', prefixIcon: Icon(Icons.receipt))),
          SizedBox(height: 16.h),
          ElevatedButton(
            onPressed: () {
              if (nc.text.trim().isEmpty) return;
              final now = DateTime.now();
              final supplier = Supplier(
                id: existing?.id, name: nc.text.trim(),
                phone: pc.text.isEmpty ? null : pc.text,
                address: ac.text.isEmpty ? null : ac.text,
                gstNumber: gc.text.isEmpty ? null : gc.text,
                createdAt: existing?.createdAt ?? now, updatedAt: now,
              );
              if (existing == null) ctx.read<MastersBloc>().add(AddSupplier(supplier));
              else ctx.read<MastersBloc>().add(UpdateSupplier(supplier));
              Navigator.pop(ctx);
            },
            child: Text(existing == null ? 'Add Supplier' : 'Update'),
          ),
        ]),
      ),
    );
  }
}