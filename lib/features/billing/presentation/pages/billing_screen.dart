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
  @override State<BillingScreen> createState() => _BillingScreenState();
}

class _BillingScreenState extends State<BillingScreen> {
  final TextEditingController _searchController = TextEditingController();
  int? _selectedCategoryId;
  bool _showCart = false;

  @override void dispose() { _searchController.dispose(); super.dispose(); }

  // ── Helper: Product → CartItem ─────────────────────────────────────────────
  CartItem _toCartItem(Product p) => CartItem(
    productId: p.id!,
    productName: p.name,
    unit: p.displayUnit,
    sellingPrice: p.sellingPrice,
    wholesalePrice: p.wholesalePrice > 0 ? p.wholesalePrice : p.sellingPrice,
    purchasePrice: p.purchasePrice,
    gstRate: p.gstRate,
    gstInclusive: p.gstInclusive,
    rateType: p.rateType,
    quantity: 1,
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(),
            // ✅ Bill Type Toggle — always visible below search
            _buildBillTypeToggle(),
            Expanded(child: _showCart ? _buildCartView() : _buildProductView()),
          ],
        ),
      ),
    );
  }

  // ── Top Bar: Search + Cart button ─────────────────────────────────────────
  Widget _buildTopBar() {
    return BlocBuilder<BillingBloc, CartState>(
      builder: (context, state) {
        final cart = state as CartState;
        return Container(
          color: Colors.white,
          padding: EdgeInsets.fromLTRB(16.w, 10.h, 16.w, 6.h),
          child: Row(
            children: [
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
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                        icon: Icon(Icons.clear, size: 18.sp, color: AppTheme.textSecondary),
                        onPressed: () {
                          _searchController.clear();
                          context.read<ProductBloc>().add(SearchProducts(''));
                        },
                      )
                          : null,
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 12.h),
                      hintStyle: AppTheme.caption,
                    ),
                    style: AppTheme.body,
                  ),
                ),
              ),
              SizedBox(width: 10.w),
              // Cart button with item count badge
              GestureDetector(
                onTap: () => setState(() => _showCart = !_showCart),
                child: Container(
                  width: 50.w, height: 44.h,
                  decoration: BoxDecoration(
                    color: _showCart ? AppTheme.primary : AppTheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Icon(Icons.shopping_cart_rounded,
                          color: _showCart ? Colors.white : AppTheme.primary, size: 22.sp),
                      if (cart.itemCount > 0)
                        Positioned(
                          top: 6.h, right: 6.w,
                          child: Container(
                            width: 16.w, height: 16.w,
                            decoration: BoxDecoration(
                              color: _showCart ? Colors.white : AppTheme.danger,
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                cart.itemCount > 9 ? '9+' : '${cart.itemCount}',
                                style: TextStyle(
                                  fontSize: 9.sp, fontWeight: FontWeight.w700,
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

  // ── ✅ Bill Type Toggle: Retail / Wholesale ───────────────────────────────
  Widget _buildBillTypeToggle() {
    return BlocBuilder<BillingBloc, CartState>(
      builder: (context, state) {
        final cart = state as CartState;
        final isRetail = cart.billType == BillType.retail;

        return Container(
          color: Colors.white,
          padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 10.h),
          child: Container(
            height: 38.h,
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(10.r),
              border: Border.all(color: AppTheme.divider),
            ),
            child: Row(
              children: [
                // Retail tab
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      if (!isRetail) {
                        context.read<BillingBloc>().add(SetBillType(BillType.retail));
                      }
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: EdgeInsets.all(3.w),
                      decoration: BoxDecoration(
                        color: isRetail ? AppTheme.primary : Colors.transparent,
                        borderRadius: BorderRadius.circular(7.r),
                        boxShadow: isRetail
                            ? [BoxShadow(color: AppTheme.primary.withOpacity(0.25), blurRadius: 6, offset: const Offset(0, 2))]
                            : null,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('🛒', style: TextStyle(fontSize: 13.sp)),
                          SizedBox(width: 5.w),
                          Text(
                            'Retail',
                            style: TextStyle(
                              fontSize: 13.sp,
                              fontWeight: FontWeight.w600,
                              color: isRetail ? Colors.white : AppTheme.textSecondary,
                              fontFamily: 'Poppins',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                // Wholesale tab
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      if (isRetail) {
                        context.read<BillingBloc>().add(SetBillType(BillType.wholesale));
                      }
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: EdgeInsets.all(3.w),
                      decoration: BoxDecoration(
                        color: !isRetail ? const Color(0xFF2D3250) : Colors.transparent,
                        borderRadius: BorderRadius.circular(7.r),
                        boxShadow: !isRetail
                            ? [BoxShadow(color: const Color(0xFF2D3250).withOpacity(0.25), blurRadius: 6, offset: const Offset(0, 2))]
                            : null,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('📦', style: TextStyle(fontSize: 13.sp)),
                          SizedBox(width: 5.w),
                          Text(
                            'Wholesale',
                            style: TextStyle(
                              fontSize: 13.sp,
                              fontWeight: FontWeight.w600,
                              color: !isRetail ? Colors.white : AppTheme.textSecondary,
                              fontFamily: 'Poppins',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Product Grid view ─────────────────────────────────────────────────────
  Widget _buildProductView() {
    return BlocBuilder<BillingBloc, CartState>(
      builder: (ctx, billingState) {
        final billType = (billingState as CartState).billType;
        return BlocBuilder<ProductBloc, ProductState>(
          builder: (context, productState) {
            if (productState is ProductLoading) {
              return const Center(child: CircularProgressIndicator());
            }
            if (productState is! ProductsLoaded) return const SizedBox();

            return Column(
              children: [
                _buildCategoryFilter(productState.categories),
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
                      // ✅ Pass billType so grid shows correct price
                      return ProductGridItem(
                        product: product,
                        billType: billType,
                        onTap: () {
                          if (!product.isOutOfStock) {
                            // ✅ Convert Product → CartItem properly
                            context.read<BillingBloc>().add(AddToCart(_toCartItem(product)));
                            _showAddedFeedback(product.name);
                          } else {
                            _showOutOfStockSnack(product.name);
                          }
                        },
                      );
                    },
                  ),
                ),
                _buildBottomBar(),
              ],
            );
          },
        );
      },
    );
  }

  // ── Category filter chips ─────────────────────────────────────────────────
  Widget _buildCategoryFilter(List<Category> categories) {
    return SizedBox(
      height: 40.h,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 12.w),
        children: [
          _categoryChip(null, '🏪', 'All'),
          ...categories.map((c) => _categoryChip(c.id, c.icon, c.name)),
        ],
      ),
    );
  }

  Widget _categoryChip(int? id, String icon, String label) {
    final isSelected = _selectedCategoryId == id;
    return GestureDetector(
      onTap: () {
        setState(() => _selectedCategoryId = id);
        context.read<ProductBloc>().add(FilterByCategory(id));
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: EdgeInsets.only(right: 8.w),
        padding: EdgeInsets.symmetric(horizontal: 11.w, vertical: 5.h),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primary : Colors.white,
          borderRadius: BorderRadius.circular(20.r),
          border: Border.all(color: isSelected ? AppTheme.primary : AppTheme.divider),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(icon, style: TextStyle(fontSize: 13.sp)),
            SizedBox(width: 4.w),
            Text(label, style: TextStyle(
              fontSize: 12.sp, fontWeight: FontWeight.w500,
              color: isSelected ? Colors.white : AppTheme.textPrimary, fontFamily: 'Poppins',
            )),
          ],
        ),
      ),
    );
  }

  // ── Cart View ─────────────────────────────────────────────────────────────
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
        return Column(
          children: [
            if (cart.isEmpty)
              Expanded(child: _buildEmptyCart())
            else
              Expanded(
                child: ListView.separated(
                  padding: EdgeInsets.all(12.w),
                  itemCount: cart.items.length,
                  separatorBuilder: (_, __) => SizedBox(height: 8.h),
                  itemBuilder: (context, i) {
                    final item = cart.items[i];
                    return CartItemTile(
                      item: item,
                      billType: cart.billType,
                      onIncrease: () => context.read<BillingBloc>().add(
                          UpdateCartItemQty(productId: item.productId, quantity: item.quantity + 1)),
                      onDecrease: () => context.read<BillingBloc>().add(
                          UpdateCartItemQty(productId: item.productId, quantity: item.quantity - 1)),
                      onRemove: () => context.read<BillingBloc>().add(RemoveFromCart(item.productId)),
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

  // ── Cart summary + Pay button ─────────────────────────────────────────────
  Widget _buildCartSummary(CartState cart) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 12, offset: const Offset(0, -4))],
      ),
      child: Column(
        children: [
          // Bill type indicator
          Row(
            children: [
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                decoration: BoxDecoration(
                  color: cart.billType == BillType.retail
                      ? AppTheme.primary.withOpacity(0.1)
                      : AppTheme.secondary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6.r),
                ),
                child: Text(
                  cart.billType == BillType.retail ? '🛒 Retail Bill' : '📦 Wholesale Bill',
                  style: TextStyle(
                    fontSize: 11.sp, fontWeight: FontWeight.w600, fontFamily: 'Poppins',
                    color: cart.billType == BillType.retail ? AppTheme.primary : AppTheme.secondary,
                  ),
                ),
              ),
              const Spacer(),
              Text('${cart.items.length} item${cart.items.length == 1 ? '' : 's'}', style: AppTheme.caption),
            ],
          ),
          SizedBox(height: 10.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Subtotal', style: AppTheme.body.copyWith(color: AppTheme.textSecondary)),
              Text(CurrencyFormatter.format(cart.subtotal), style: AppTheme.body),
            ],
          ),
          if (cart.gstTotal > 0) ...[
            SizedBox(height: 3.h),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('GST', style: AppTheme.body.copyWith(color: AppTheme.textSecondary)),
                Text(CurrencyFormatter.format(cart.gstTotal), style: AppTheme.body),
              ],
            ),
          ],
          if (cart.discountAmount > 0) ...[
            SizedBox(height: 3.h),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Discount', style: AppTheme.body.copyWith(color: AppTheme.accent)),
                Text('-${CurrencyFormatter.format(cart.discountAmount)}',
                    style: AppTheme.body.copyWith(color: AppTheme.accent)),
              ],
            ),
          ],
          Divider(height: 14.h, color: AppTheme.divider),
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

  // ── Bottom floating cart bar ───────────────────────────────────────────────
  Widget _buildBottomBar() {
    return BlocBuilder<BillingBloc, CartState>(
      builder: (context, state) {
        final cart = state as CartState;
        if (cart.isEmpty) return const SizedBox();
        final isWholesale = cart.billType == BillType.wholesale;
        return GestureDetector(
          onTap: () => setState(() => _showCart = true),
          child: Container(
            margin: EdgeInsets.all(12.w),
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
            decoration: BoxDecoration(
              color: isWholesale ? AppTheme.secondary : AppTheme.primary,
              borderRadius: BorderRadius.circular(14.r),
              boxShadow: [
                BoxShadow(
                  color: (isWholesale ? AppTheme.secondary : AppTheme.primary).withOpacity(0.35),
                  blurRadius: 12, offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.25),
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: Text(
                    '${cart.itemCount} items',
                    style: TextStyle(color: Colors.white, fontSize: 12.sp, fontWeight: FontWeight.w600, fontFamily: 'Poppins'),
                  ),
                ),
                SizedBox(width: 8.w),
                Text(
                  isWholesale ? '📦 View Cart' : '🛒 View Cart',
                  style: TextStyle(color: Colors.white, fontSize: 14.sp, fontWeight: FontWeight.w600, fontFamily: 'Poppins'),
                ),
                const Spacer(),
                Text(
                  CurrencyFormatter.format(cart.subtotal),
                  style: TextStyle(color: Colors.white, fontSize: 16.sp, fontWeight: FontWeight.w700, fontFamily: 'Poppins'),
                ),
                Icon(Icons.chevron_right, color: Colors.white, size: 20.sp),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() => Center(
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Text('🔍', style: TextStyle(fontSize: 48.sp)),
      SizedBox(height: 12.h),
      Text('No products found', style: AppTheme.heading3),
      SizedBox(height: 4.h),
      Text('Try a different search or category', style: AppTheme.caption),
    ]),
  );

  Widget _buildEmptyCart() => Center(
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
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
    ]),
  );

  void _showAddedFeedback(String name) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('$name added'),
      duration: const Duration(milliseconds: 700),
      backgroundColor: AppTheme.accent,
      behavior: SnackBarBehavior.floating,
      margin: EdgeInsets.only(bottom: 80.h, left: 16.w, right: 16.w),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
    ));
  }

  void _showOutOfStockSnack(String name) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('$name — Out of stock'),
      backgroundColor: AppTheme.danger,
      behavior: SnackBarBehavior.floating,
      margin: EdgeInsets.only(bottom: 80.h, left: 16.w, right: 16.w),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
    ));
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