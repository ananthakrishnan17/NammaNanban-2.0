import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/masters.dart';
import '../bloc/masters_bloc.dart';

class MastersPage extends StatefulWidget {
  const MastersPage({super.key});
  @override State<MastersPage> createState() => _MastersPageState();
}

class _MastersPageState extends State<MastersPage> with SingleTickerProviderStateMixin {
  late TabController _tabs;

  @override void initState() { super.initState(); _tabs = TabController(length: 5, vsync: this); context.read<MastersBloc>().add(LoadAllMasters()); }
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
            Tab(text: '🏷️ Category'), Tab(text: '🏭 Brand'),
            Tab(text: '📏 Unit'), Tab(text: '👤 Customer'), Tab(text: '🚚 Supplier'),
          ],
        ),
      ),
      body: BlocBuilder<MastersBloc, MastersState>(
        builder: (context, state) => TabBarView(
          controller: _tabs,
          children: [
            _SimpleMasterTab(
              title: 'Category', items: state.brands.isNotEmpty || state.units.isNotEmpty ? [] : [],
              // Note: Categories come from ProductBloc — use existing product repo
              emptyMsg: 'No categories. Add from product screen.',
              onAdd: (name) => {},
              onDelete: (id) => {},
              isExternal: true, // managed by product repo
            ),
            _SimpleMasterTab(
              title: 'Brand',
              items: state.brands.map((b) => _MasterItem(id: b.id!, label: b.name, sub: b.description)).toList(),
              onAdd: (name) => context.read<MastersBloc>().add(AddBrand(name)),
              onDelete: (id) => context.read<MastersBloc>().add(DeleteBrand(id)),
            ),
            _UnitMasterTab(units: state.units),
            _CustomerMasterTab(customers: state.customers),
            _SupplierMasterTab(suppliers: state.suppliers),
          ],
        ),
      ),
    );
  }
}

class _MasterItem { final int id; final String label; final String? sub; _MasterItem({required this.id, required this.label, this.sub}); }

// ─── Simple Master Tab (Brand, Category) ──────────────────────────────────────
class _SimpleMasterTab extends StatefulWidget {
  final String title;
  final List<_MasterItem> items;
  final void Function(String) onAdd;
  final void Function(int) onDelete;
  final String? emptyMsg;
  final bool isExternal;
  const _SimpleMasterTab({required this.title, required this.items, required this.onAdd, required this.onDelete, this.emptyMsg, this.isExternal = false});
  @override State<_SimpleMasterTab> createState() => _SimpleMasterTabState();
}

class _SimpleMasterTabState extends State<_SimpleMasterTab> {
  final _ctrl = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (!widget.isExternal) Padding(
          padding: EdgeInsets.all(12.w),
          child: Row(children: [
            Expanded(child: TextField(controller: _ctrl, decoration: InputDecoration(hintText: 'New ${widget.title} name', prefixIcon: const Icon(Icons.add)))),
            SizedBox(width: 8.w),
            ElevatedButton(
              onPressed: () { if (_ctrl.text.trim().isNotEmpty) { widget.onAdd(_ctrl.text.trim()); _ctrl.clear(); } },
              style: ElevatedButton.styleFrom(minimumSize: Size(60.w, 48.h), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r))),
              child: const Text('Add'),
            ),
          ]),
        ),
        Expanded(
          child: widget.items.isEmpty
              ? Center(child: Text(widget.emptyMsg ?? 'No ${widget.title.toLowerCase()}s yet', style: AppTheme.caption))
              : ListView.separated(
            padding: EdgeInsets.symmetric(horizontal: 12.w),
            itemCount: widget.items.length,
            separatorBuilder: (_, __) => SizedBox(height: 6.h),
            itemBuilder: (_, i) {
              final item = widget.items[i];
              return Container(
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12.r), border: Border.all(color: AppTheme.divider)),
                child: ListTile(
                  title: Text(item.label, style: AppTheme.body),
                  subtitle: item.sub != null ? Text(item.sub!, style: AppTheme.caption) : null,
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

  void _confirmDelete(BuildContext ctx, _MasterItem item) => showDialog(
    context: ctx,
    builder: (_) => AlertDialog(
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

// ─── Unit Master Tab ───────────────────────────────────────────────────────────
class _UnitMasterTab extends StatelessWidget {
  final List<UomUnit> units;
  const _UnitMasterTab({required this.units});

  @override
  Widget build(BuildContext context) {
    final nameCtrl = TextEditingController();
    final shortCtrl = TextEditingController();
    String selectedType = 'count';

    return Column(
      children: [
        Padding(
          padding: EdgeInsets.all(12.w),
          child: StatefulBuilder(builder: (ctx, setSt) => Column(children: [
            Row(children: [
              Expanded(child: TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Unit Name', hintText: 'e.g. Kilogram'))),
              SizedBox(width: 8.w),
              SizedBox(width: 80.w, child: TextField(controller: shortCtrl, decoration: const InputDecoration(labelText: 'Short', hintText: 'Kg'))),
            ]),
            SizedBox(height: 8.h),
            Row(children: [
              Expanded(child: DropdownButtonFormField<String>(
                value: selectedType,
                decoration: const InputDecoration(labelText: 'Type'),
                items: ['count', 'weight', 'volume', 'length']
                    .map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                onChanged: (v) => setSt(() => selectedType = v!),
              )),
              SizedBox(width: 8.w),
              ElevatedButton(
                onPressed: () {
                  if (nameCtrl.text.trim().isNotEmpty && shortCtrl.text.trim().isNotEmpty) {
                    context.read<MastersBloc>().add(AddUnit(UomUnit(
                        name: nameCtrl.text.trim(), shortName: shortCtrl.text.trim(),
                        uomType: selectedType, createdAt: DateTime.now())));
                    nameCtrl.clear(); shortCtrl.clear();
                  }
                },
                style: ElevatedButton.styleFrom(minimumSize: Size(60.w, 48.h), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r))),
                child: const Text('Add'),
              ),
            ]),
          ])),
        ),
        Expanded(
          child: units.isEmpty
              ? Center(child: Text('No units yet', style: AppTheme.caption))
              : ListView.separated(
            padding: EdgeInsets.symmetric(horizontal: 12.w),
            itemCount: units.length,
            separatorBuilder: (_, __) => SizedBox(height: 6.h),
            itemBuilder: (_, i) {
              final u = units[i];
              return Container(
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12.r), border: Border.all(color: AppTheme.divider)),
                child: ListTile(
                  title: Text('${u.name} (${u.shortName})', style: AppTheme.body),
                  subtitle: Text(u.uomType, style: AppTheme.caption),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline, color: AppTheme.danger),
                    onPressed: () => context.read<MastersBloc>().add(DeleteUnit(u.id!)),
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

// ─── Customer Master Tab ───────────────────────────────────────────────────────
class _CustomerMasterTab extends StatelessWidget {
  final List<Customer> customers;
  const _CustomerMasterTab({required this.customers});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCustomerForm(context, null),
        backgroundColor: AppTheme.primary,
        icon: const Icon(Icons.person_add, color: Colors.white),
        label: const Text('Add Customer', style: TextStyle(color: Colors.white)),
      ),
      body: customers.isEmpty
          ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text('👤', style: TextStyle(fontSize: 48.sp)),
        SizedBox(height: 12.h),
        Text('No customers yet', style: AppTheme.heading3),
        Text('Tap + to add your first customer', style: AppTheme.caption),
      ]))
          : ListView.separated(
        padding: EdgeInsets.all(12.w),
        itemCount: customers.length,
        separatorBuilder: (_, __) => SizedBox(height: 8.h),
        itemBuilder: (_, i) => _customerTile(context, customers[i]),
      ),
    );
  }

  Widget _customerTile(BuildContext ctx, Customer c) {
    return Container(
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
            if (v == 'edit') _showCustomerForm(ctx, c);
            if (v == 'delete') ctx.read<MastersBloc>().add(DeleteCustomer(c.id!));
          },
          itemBuilder: (_) => [
            const PopupMenuItem(value: 'edit', child: Text('Edit')),
            const PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: AppTheme.danger))),
          ],
        ),
      ),
    );
  }

  void _showCustomerForm(BuildContext ctx, Customer? existing) {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final phoneCtrl = TextEditingController(text: existing?.phone ?? '');
    final addrCtrl = TextEditingController(text: existing?.address ?? '');
    final gstCtrl = TextEditingController(text: existing?.gstNumber ?? '');

    showModalBottomSheet(
      context: ctx, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: EdgeInsets.only(left: 20.w, right: 20.w, top: 20.h, bottom: MediaQuery.of(ctx).viewInsets.bottom + 20.h),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24.r))),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(existing == null ? 'Add Customer' : 'Edit Customer', style: AppTheme.heading2),
          SizedBox(height: 16.h),
          TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Name *', prefixIcon: Icon(Icons.person))),
          SizedBox(height: 10.h),
          TextField(controller: phoneCtrl, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Phone', prefixIcon: Icon(Icons.phone))),
          SizedBox(height: 10.h),
          TextField(controller: addrCtrl, decoration: const InputDecoration(labelText: 'Address', prefixIcon: Icon(Icons.location_on)), maxLines: 2),
          SizedBox(height: 10.h),
          TextField(controller: gstCtrl, decoration: const InputDecoration(labelText: 'GSTIN (optional)', prefixIcon: Icon(Icons.business))),
          SizedBox(height: 16.h),
          ElevatedButton(
            onPressed: () {
              if (nameCtrl.text.trim().isEmpty) return;
              final now = DateTime.now();
              final customer = Customer(
                id: existing?.id, name: nameCtrl.text.trim(),
                phone: phoneCtrl.text.isEmpty ? null : phoneCtrl.text,
                address: addrCtrl.text.isEmpty ? null : addrCtrl.text,
                gstNumber: gstCtrl.text.isEmpty ? null : gstCtrl.text,
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

// ─── Supplier Master Tab ───────────────────────────────────────────────────────
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
      ]))
          : ListView.separated(
        padding: EdgeInsets.all(12.w), itemCount: suppliers.length,
        separatorBuilder: (_, __) => SizedBox(height: 8.h),
        itemBuilder: (_, i) {
          final s = suppliers[i];
          return Container(
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
                if (s.outstandingBalance > 0) Text('Outstanding: ₹${s.outstandingBalance.toStringAsFixed(2)}', style: AppTheme.caption.copyWith(color: AppTheme.warning)),
              ]),
              trailing: PopupMenuButton<String>(
                onSelected: (v) {
                  if (v == 'edit') _showForm(context, s);
                  if (v == 'delete') context.read<MastersBloc>().add(DeleteSupplier(s.id!));
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'edit', child: Text('Edit')),
                  const PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: AppTheme.danger))),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showForm(BuildContext ctx, Supplier? existing) {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final phoneCtrl = TextEditingController(text: existing?.phone ?? '');
    final addrCtrl = TextEditingController(text: existing?.address ?? '');
    final gstCtrl = TextEditingController(text: existing?.gstNumber ?? '');

    showModalBottomSheet(
      context: ctx, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: EdgeInsets.only(left: 20.w, right: 20.w, top: 20.h, bottom: MediaQuery.of(ctx).viewInsets.bottom + 20.h),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24.r))),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(existing == null ? 'Add Supplier' : 'Edit Supplier', style: AppTheme.heading2),
          SizedBox(height: 16.h),
          TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Supplier Name *', prefixIcon: Icon(Icons.business))),
          SizedBox(height: 10.h),
          TextField(controller: phoneCtrl, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Phone', prefixIcon: Icon(Icons.phone))),
          SizedBox(height: 10.h),
          TextField(controller: addrCtrl, decoration: const InputDecoration(labelText: 'Address', prefixIcon: Icon(Icons.location_on))),
          SizedBox(height: 10.h),
          TextField(controller: gstCtrl, decoration: const InputDecoration(labelText: 'GSTIN', prefixIcon: Icon(Icons.receipt))),
          SizedBox(height: 16.h),
          ElevatedButton(
            onPressed: () {
              if (nameCtrl.text.trim().isEmpty) return;
              final now = DateTime.now();
              final supplier = Supplier(
                id: existing?.id, name: nameCtrl.text.trim(),
                phone: phoneCtrl.text.isEmpty ? null : phoneCtrl.text,
                address: addrCtrl.text.isEmpty ? null : addrCtrl.text,
                gstNumber: gstCtrl.text.isEmpty ? null : gstCtrl.text,
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