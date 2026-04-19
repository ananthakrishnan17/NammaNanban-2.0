import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/stock_display_helper.dart';
import '../../domain/entities/product.dart';
import '../bloc/product_bloc.dart';
import 'add_edit_product_page.dart';

class ProductsPage extends StatefulWidget {
  const ProductsPage({super.key});

  @override
  State<ProductsPage> createState() => _ProductsPageState();
}

class _ProductsPageState extends State<ProductsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Products & Stock'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppTheme.primary,
          unselectedLabelColor: AppTheme.textSecondary,
          indicatorColor: AppTheme.primary,
          tabs: const [
            Tab(text: 'All Products'),
            Tab(text: 'Low Stock'),
            Tab(text: 'Out of Stock'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AddEditProductPage()),
        ),
        backgroundColor: AppTheme.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Add Product', style: TextStyle(color: Colors.white)),
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: EdgeInsets.all(12.w),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (v) => context.read<ProductBloc>().add(SearchProducts(v)),
              decoration: InputDecoration(
                hintText: 'Search products...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchCtrl.clear();
                    context.read<ProductBloc>().add(SearchProducts(''));
                  },
                )
                    : null,
              ),
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildProductList(filter: 'all'),
                _buildProductList(filter: 'low'),
                _buildProductList(filter: 'out'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductList({required String filter}) {
    return BlocBuilder<ProductBloc, ProductState>(
      builder: (context, state) {
        if (state is ProductLoading) {
          return const Center(child: CircularProgressIndicator());
        }
        if (state is ProductsLoaded) {
          List<Product> products;
          switch (filter) {
            case 'low':
              products = state.lowStockProducts.where((p) => !p.isOutOfStock).toList();
              break;
            case 'out':
              products = state.products.where((p) => p.isOutOfStock).toList();
              break;
            default:
              products = state.filteredProducts;
          }

          if (products.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(filter == 'out' ? '✅' : filter == 'low' ? '👍' : '📦',
                      style: TextStyle(fontSize: 48.sp)),
                  SizedBox(height: 12.h),
                  Text(
                    filter == 'out'
                        ? 'No out of stock items!'
                        : filter == 'low'
                        ? 'No low stock items!'
                        : 'No products found',
                    style: AppTheme.heading3,
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
            itemCount: products.length,
            separatorBuilder: (_, __) => SizedBox(height: 8.h),
            itemBuilder: (context, index) => _ProductTile(
              product: products[index],
              onEdit: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AddEditProductPage(product: products[index]),
                ),
              ),
              onDelete: () => _confirmDelete(context, products[index]),
              onAdjustStock: () => _showStockAdjustDialog(context, products[index]),
            ),
          );
        }
        return const SizedBox();
      },
    );
  }

  void _confirmDelete(BuildContext context, Product product) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Product'),
        content: Text('Delete "${product.name}"? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              context.read<ProductBloc>().add(DeleteProduct(product.id!));
              Navigator.pop(context);
            },
            child: const Text('Delete', style: TextStyle(color: AppTheme.danger)),
          ),
        ],
      ),
    );
  }

  void _showStockAdjustDialog(BuildContext context, Product product) {
    double adjustment = 0;
    String reason = 'Manual adjustment';
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Adjust Stock — ${product.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Current: ${product.stockQuantity} ${product.unit}', style: AppTheme.caption),
            SizedBox(height: 12.h),
            TextField(
              keyboardType: const TextInputType.numberWithOptions(signed: true),
              decoration: InputDecoration(
                labelText: 'Adjustment (use - to reduce)',
                hintText: 'e.g. +10 or -5',
                helperText: 'Enter positive to add, negative to reduce',
              ),
              onChanged: (v) => adjustment = double.tryParse(v) ?? 0,
            ),
            SizedBox(height: 8.h),
            TextField(
              decoration: const InputDecoration(labelText: 'Reason'),
              onChanged: (v) => reason = v,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              context.read<ProductBloc>().add(AdjustStock(
                productId: product.id!,
                quantity: adjustment,
                reason: reason,
              ));
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}

class _ProductTile extends StatelessWidget {
  final Product product;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onAdjustStock;

  const _ProductTile({
    required this.product,
    required this.onEdit,
    required this.onDelete,
    required this.onAdjustStock,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(
          color: product.isOutOfStock
              ? AppTheme.danger.withOpacity(0.3)
              : product.isLowStock
              ? AppTheme.warning.withOpacity(0.3)
              : AppTheme.divider,
        ),
      ),
      child: ListTile(
        contentPadding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 4.h),
        leading: Container(
          width: 44.w,
          height: 44.h,
          decoration: BoxDecoration(
            color: AppTheme.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10.r),
          ),
          child: Center(
            child: Text(
              product.categoryName != null ? _emoji(product.categoryName!) : '📦',
              style: TextStyle(fontSize: 20.sp),
            ),
          ),
        ),
        title: Text(product.name, style: AppTheme.heading3),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '₹${product.sellingPrice}  •  Buy: ₹${product.purchasePrice}',
              style: AppTheme.caption,
            ),
            SizedBox(height: 2.h),
            Row(
              children: [
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                  decoration: BoxDecoration(
                    color: product.isOutOfStock
                        ? AppTheme.danger.withOpacity(0.1)
                        : product.isLowStock
                        ? AppTheme.warning.withOpacity(0.1)
                        : AppTheme.accent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4.r),
                  ),
                  child: Text(
                    product.wholesaleToRetailQty > 1.0
                        ? StockDisplayHelper.formatMixedStock(
                            stockRetailQty: product.stockQuantity,
                            wholesaleToRetailQty: product.wholesaleToRetailQty,
                            wholesaleUnit: product.wholesaleUnit,
                            retailUnit: product.retailUnit,
                          )
                        : '${product.stockQuantity} ${product.unit}',
                    style: TextStyle(
                      fontSize: 10.sp,
                      fontWeight: FontWeight.w600,
                      color: product.isOutOfStock
                          ? AppTheme.danger
                          : product.isLowStock
                          ? AppTheme.warning
                          : AppTheme.accent,
                    ),
                  ),
                ),
                SizedBox(width: 6.w),
                Text(
                  'Profit: ${CurrencyFormatter.format(product.profit)}',
                  style: AppTheme.caption.copyWith(color: AppTheme.accent),
                ),
              ],
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (val) {
            if (val == 'edit') onEdit();
            if (val == 'stock') onAdjustStock();
            if (val == 'delete') onDelete();
          },
          itemBuilder: (_) => [
            const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit, size: 16), SizedBox(width: 8), Text('Edit')])),
            const PopupMenuItem(value: 'stock', child: Row(children: [Icon(Icons.inventory, size: 16), SizedBox(width: 8), Text('Adjust Stock')])),
            const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete, size: 16, color: AppTheme.danger), SizedBox(width: 8), Text('Delete', style: TextStyle(color: AppTheme.danger))])),
          ],
        ),
      ),
    );
  }

  String _emoji(String category) {
    final c = category.toLowerCase();
    if (c.contains('beverage')) return '☕';
    if (c.contains('food')) return '🍱';
    if (c.contains('snack')) return '🍪';
    if (c.contains('sweet')) return '🍬';
    return '📦';
  }
}
