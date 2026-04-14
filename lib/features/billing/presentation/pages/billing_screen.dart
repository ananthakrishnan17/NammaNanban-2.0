import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../products/domain/entities/product.dart';
import '../../../products/presentation/bloc/product_bloc.dart';
import '../../domain/entities/bill.dart';
import '../bloc/billing_bloc.dart';
import '../widgets/cart_item_tile.dart';
import '../widgets/product_grid_item.dart';
import '../widgets/payment_bottom_sheet.dart';

class BillingScreen extends StatefulWidget {
  const BillingScreen({super.key});

  @override
  State<BillingScreen> createState() => _BillingScreenState();
}

class _BillingScreenState extends State<BillingScreen> {
  final TextEditingController _searchController = TextEditingController();
  int? _selectedCategoryId;
  bool _showCart = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: _showCart ? _buildCartView() : _buildProductView(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return BlocBuilder<BillingBloc, CartState>(
      builder: (context, state) {
        final cart = state as CartState;
        return Container(
          color: Colors.white,
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
          child: Row(
            children: [
              // Search
              Expanded(
                child: Container(
                  height: 44.h,
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(12.r),
                    border: Border.all(color: AppTheme.divider),
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (v) => context.read<ProductBloc>().add(SearchProducts(v)),
                    decoration: InputDecoration(
                      hintText: 'Search products...',
                      prefixIcon: Icon(Icons.search, color: AppTheme.textSecondary, size: 20.sp),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 12.h),
                      hintStyle: AppTheme.caption,
                    ),
                    style: AppTheme.body,
                  ),
                ),
              ),
              SizedBox(width: 12.w),
              // Cart Button
              GestureDetector(
                onTap: () => setState(() => _showCart = !_showCart),
                child: Container(
                  width: 50.w,
                  height: 44.h,
                  decoration: BoxDecoration(
                    color: _showCart ? AppTheme.primary : AppTheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Icon(
                        Icons.shopping_cart_rounded,
                        color: _showCart ? Colors.white : AppTheme.primary,
                        size: 22.sp,
                      ),
                      if (cart.itemCount > 0)
                        Positioned(
                          top: 6.h,
                          right: 6.w,
                          child: Container(
                            width: 16.w,
                            height: 16.w,
                            decoration: BoxDecoration(
                              color: _showCart ? Colors.white : AppTheme.danger,
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                cart.itemCount > 9 ? '9+' : '${cart.itemCount}',
                                style: TextStyle(
                                  fontSize: 9.sp,
                                  fontWeight: FontWeight.w700,
                                  color: _showCart ? AppTheme.danger : Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildProductView() {
    return BlocBuilder<ProductBloc, ProductState>(
      builder: (context, productState) {
        if (productState is ProductLoading) {
          return const Center(child: CircularProgressIndicator());
        }
        if (productState is ProductsLoaded) {
          return Column(
            children: [
              // Category Filter
              _buildCategoryFilter(productState.categories),
              // Product Grid
              Expanded(
                child: productState.filteredProducts.isEmpty
                    ? _buildEmptyState()
                    : GridView.builder(
                  padding: EdgeInsets.all(12.w),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 10.h,
                    crossAxisSpacing: 10.w,
                    childAspectRatio: 0.82,
                  ),
                  itemCount: productState.filteredProducts.length,
                  itemBuilder: (context, index) {
                    final product = productState.filteredProducts[index];
                    return ProductGridItem(
                      product: product,
                      onTap: () {
                        if (!product.isOutOfStock) {
                          context.read<BillingBloc>().add(AddToCart(
                            CartItem(
                              // Use ! because product.id from the database won't be null here
                              productId: product.id!,
                              productName: product.name,
                              unit: product.unit,
                              quantity: 1,
                              sellingPrice: product.sellingPrice,
                              wholesalePrice: product.wholesalePrice,
                              purchasePrice: product.purchasePrice, // Added this
                              // If "product: product" gave an error, just remove it.
                              // Your CartItem likely uses the individual fields above instead.
                            ),
                          ));
                          _showAddedFeedback(product.name);
                        } else {
                          _showOutOfStockDialog(product.name);
                        }
                      },
                    );
                  },
                ),
              ),
              // Bottom Total Bar
              _buildBottomBar(),
            ],
          );
        }
        return const SizedBox();
      },
    );
  }

  Widget _buildCategoryFilter(List<Category> categories) {
    return SizedBox(
      height: 44.h,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 12.w),
        children: [
          _buildCategoryChip(null, '🏪', 'All'),
          ...categories.map((c) => _buildCategoryChip(c.id, c.icon, c.name)),
        ],
      ),
    );
  }

  Widget _buildCategoryChip(int? id, String icon, String label) {
    final isSelected = _selectedCategoryId == id;
    return GestureDetector(
      onTap: () {
        setState(() => _selectedCategoryId = id);
        context.read<ProductBloc>().add(FilterByCategory(id));
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: EdgeInsets.only(right: 8.w),
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primary : Colors.white,
          borderRadius: BorderRadius.circular(20.r),
          border: Border.all(
            color: isSelected ? AppTheme.primary : AppTheme.divider,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(icon, style: TextStyle(fontSize: 14.sp)),
            SizedBox(width: 4.w),
            Text(
              label,
              style: TextStyle(
                fontSize: 12.sp,
                fontWeight: FontWeight.w500,
                color: isSelected ? Colors.white : AppTheme.textPrimary,
                fontFamily: 'Poppins',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCartView() {
    return BlocConsumer<BillingBloc, CartState>(
      listener: (context, state) {
        final cart = state as CartState;
        if (cart.lastSavedBill != null && !cart.isSaving) {
          setState(() => _showCart = false);
        }
      },
      builder: (context, state) {
        final cart = state as CartState;
        if (cart.isEmpty) {
          return Column(
            children: [
              Expanded(child: _buildEmptyCart()),
              _buildBottomBar(),
            ],
          );
        }
        return Column(
          children: [
            Expanded(
              child: ListView.separated(
                padding: EdgeInsets.all(12.w),
                itemCount: cart.items.length,
                separatorBuilder: (_, __) => SizedBox(height: 8.h),
                itemBuilder: (context, index) {
                  return CartItemTile(
                    item: cart.items[index],
                    onIncrease: () => context.read<BillingBloc>().add(
                      UpdateCartItemQty(
                        productId: cart.items[index].productId!,
                        quantity: cart.items[index].quantity + 1,
                      ),
                    ),
                    onDecrease: () => context.read<BillingBloc>().add(
                      UpdateCartItemQty(
                        productId: cart.items[index].productId!,
                        quantity: cart.items[index].quantity - 1,
                      ),
                    ),
                    onRemove: () => context.read<BillingBloc>().add(
                      RemoveFromCart(cart.items[index].productId!),
                    ),
                  );
                },
              ),
            ),
            _buildCartSummary(cart),
          ],
        );
      },
    );
  }

  Widget _buildCartSummary(CartState cart) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Subtotal', style: AppTheme.body.copyWith(color: AppTheme.textSecondary)),
              Text(CurrencyFormatter.format(cart.subtotal), style: AppTheme.body),
            ],
          ),
          if (cart.discountAmount > 0) ...[
            SizedBox(height: 4.h),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Discount', style: AppTheme.body.copyWith(color: AppTheme.accent)),
                Text('-${CurrencyFormatter.format(cart.discountAmount)}',
                    style: AppTheme.body.copyWith(color: AppTheme.accent)),
              ],
            ),
          ],
          Divider(height: 16.h, color: AppTheme.divider),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Total', style: AppTheme.heading3),
              Text(CurrencyFormatter.format(cart.totalAmount), style: AppTheme.price),
            ],
          ),
          SizedBox(height: 12.h),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    context.read<BillingBloc>().add(ClearCart());
                    setState(() => _showCart = false);
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.danger,
                    side: const BorderSide(color: AppTheme.danger),
                    minimumSize: Size(0, 48.h),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                  ),
                  child: const Text('Clear'),
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: cart.isEmpty ? null : () => _showPaymentSheet(context, cart),
                  style: ElevatedButton.styleFrom(
                    minimumSize: Size(0, 48.h),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                  ),
                  child: Text('Pay ${CurrencyFormatter.format(cart.totalAmount)}'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    return BlocBuilder<BillingBloc, CartState>(
      builder: (context, state) {
        final cart = state as CartState;
        if (cart.isEmpty) return const SizedBox();
        return GestureDetector(
          onTap: () => setState(() => _showCart = true),
          child: Container(
            margin: EdgeInsets.all(12.w),
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
            decoration: BoxDecoration(
              color: AppTheme.primary,
              borderRadius: BorderRadius.circular(14.r),
              boxShadow: [
                BoxShadow(color: AppTheme.primary.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4)),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: Text(
                    '${cart.itemCount} items',
                    style: TextStyle(color: Colors.white, fontSize: 12.sp, fontWeight: FontWeight.w600),
                  ),
                ),
                SizedBox(width: 8.w),
                Expanded(
                  child: Text(
                    'View Cart',
                    style: TextStyle(color: Colors.white, fontSize: 15.sp, fontWeight: FontWeight.w600),
                  ),
                ),
                Text(
                  CurrencyFormatter.format(cart.subtotal),
                  style: TextStyle(color: Colors.white, fontSize: 16.sp, fontWeight: FontWeight.w700),
                ),
                Icon(Icons.chevron_right, color: Colors.white, size: 20.sp),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('🔍', style: TextStyle(fontSize: 48.sp)),
          SizedBox(height: 12.h),
          Text('No products found', style: AppTheme.heading3),
          SizedBox(height: 4.h),
          Text('Try a different search or category', style: AppTheme.caption),
        ],
      ),
    );
  }

  Widget _buildEmptyCart() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('🛒', style: TextStyle(fontSize: 56.sp)),
          SizedBox(height: 16.h),
          Text('Cart is empty', style: AppTheme.heading2),
          SizedBox(height: 8.h),
          Text('Tap products to add them to cart', style: AppTheme.caption),
          SizedBox(height: 20.h),
          TextButton.icon(
            onPressed: () => setState(() => _showCart = false),
            icon: const Icon(Icons.grid_view_rounded),
            label: const Text('Browse Products'),
          ),
        ],
      ),
    );
  }

  void _showAddedFeedback(String productName) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$productName added to cart'),
        duration: const Duration(milliseconds: 800),
        backgroundColor: AppTheme.accent,
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.only(bottom: 80.h, left: 16.w, right: 16.w),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
      ),
    );
  }

  void _showOutOfStockDialog(String name) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$name is out of stock'),
        backgroundColor: AppTheme.danger,
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.only(bottom: 80.h, left: 16.w, right: 16.w),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
      ),
    );
  }

  void _showPaymentSheet(BuildContext context, CartState cart) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BlocProvider.value(
        value: context.read<BillingBloc>(),
        child: PaymentBottomSheet(cart: cart),
      ),
    );
  }
}
