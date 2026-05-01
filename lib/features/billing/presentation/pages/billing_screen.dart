import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../../core/database/database_helper.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../products/data/repositories/product_repository_impl.dart';
import '../../../products/domain/entities/product.dart';
import '../../../products/presentation/bloc/product_bloc.dart';
import '../../domain/entities/bill.dart';
import '../../domain/entities/sale_type.dart';
import '../bloc/billing_bloc.dart';
import '../widgets/cart_item_tile.dart';
import '../widgets/product_grid_item.dart';
import '../widgets/payment_bottom_sheet.dart';
import '../widgets/uom_picker_sheet.dart';
import 'bill_view_screen.dart';
import 'held_bills_page.dart';
import 'split_bill_page.dart';

class BillingScreen extends StatefulWidget {
  const BillingScreen({super.key});
  @override
  State<BillingScreen> createState() => _BillingScreenState();
}

const Duration _kBottomSheetDismissalDelay = Duration(milliseconds: 150);

class _BillingScreenState extends State<BillingScreen> {
  final TextEditingController _searchController = TextEditingController();
  int? _selectedCategoryId;
  bool _showCart = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ── Helper: Product → CartItem ─────────────────────────────────────────────
  CartItem _toCartItem(Product p, {SaleType saleType = SaleType.retail}) {
    final unit = saleType == SaleType.wholesale && p.wholesaleToRetailQty > 1.0
        ? p.wholesaleUnit
        : p.displayUnit;
    return CartItem(
      productId: p.id!,
      productName: p.name,
      unit: unit,
      sellingPrice: p.sellingPrice,
      wholesalePrice: p.wholesalePrice > 0 ? p.wholesalePrice : p.sellingPrice,
      purchasePrice: p.purchasePrice,
      gstRate: p.gstRate,
      gstInclusive: p.gstInclusive,
      rateType: p.rateType,
      quantity: 1,
      saleType: saleType,
      retailPrice: p.retailPrice,
      wholesaleToRetailQty: p.wholesaleToRetailQty,
    );
  }

  // ── Barcode Scanner ────────────────────────────────────────────────────────
  Future<void> _scanBarcode(BuildContext context) async {
    final barcode = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _BarcodeScannerSheet(),
    );
    if (barcode == null || barcode.isEmpty || !mounted) return;

    final repo = ProductRepositoryImpl(DatabaseHelper.instance);
    final product = await repo.findByBarcode(barcode);
    if (!mounted) return;

    if (product == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('No product found for barcode: $barcode'),
        backgroundColor: AppTheme.danger,
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.only(bottom: 80.h, left: 16.w, right: 16.w),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
      ));
      return;
    }
    if (product.isOutOfStock) { _showOutOfStockSnack(product.name); return; }

    final uoms = await repo.getProductUoms(product.id!);
    if (!mounted) return;
    if (uoms.isEmpty) {
      await _addProductToCart(context, product);
    } else {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24.r))),
        builder: (_) => BlocProvider.value(
          value: context.read<BillingBloc>(),
          child: UomPickerSheet(product: product, uoms: uoms),
        ),
      );
    }
  }

  /// Show sale type selection dialog for products with wholesaleToRetailQty > 1
  Future<void> _addProductToCart(BuildContext context, Product product) async {
    if (product.wholesaleToRetailQty > 1.0) {
      await _showSaleTypeSheet(context, product);
    } else {
      context.read<BillingBloc>().add(AddToCart(_toCartItem(product)));
      _showAddedFeedback(product.name);
    }
  }

  Future<void> _showSaleTypeSheet(BuildContext context, Product product) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24.r))),
      builder: (_) => Container(
        padding: EdgeInsets.all(20.w),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40.w, height: 4.h, decoration: BoxDecoration(color: AppTheme.divider, borderRadius: BorderRadius.circular(2.r))),
          SizedBox(height: 16.h),
          Text('Select Sale Type', style: AppTheme.heading2),
          SizedBox(height: 6.h),
          Text(product.name, style: AppTheme.caption),
          SizedBox(height: 20.h),
          Row(children: [
            Expanded(child: _saleTypeBtn(
              context: context,
              emoji: '🛒',
              label: 'Retail',
              sub: 'per ${product.retailUnit} ₹${product.retailPrice > 0 ? product.retailPrice.toStringAsFixed(2) : product.sellingPrice.toStringAsFixed(2)}',
              color: AppTheme.primary,
              onTap: () {
                Navigator.pop(context);
                context.read<BillingBloc>().add(AddToCart(_toCartItem(product, saleType: SaleType.retail)));
                _showAddedFeedback(product.name);
              },
            )),
            SizedBox(width: 12.w),
            Expanded(child: _saleTypeBtn(
              context: context,
              emoji: '📦',
              label: 'Wholesale',
              sub: 'per ${product.wholesaleUnit} ₹${product.wholesalePrice.toStringAsFixed(2)}',
              color: AppTheme.accent,
              onTap: () {
                Navigator.pop(context);
                context.read<BillingBloc>().add(AddToCart(_toCartItem(product, saleType: SaleType.wholesale)));
                _showAddedFeedback(product.name);
              },
            )),
          ]),
          SizedBox(height: 20.h),
        ]),
      ),
    );
  }

  Widget _saleTypeBtn({
    required BuildContext context,
    required String emoji,
    required String label,
    required String sub,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(14.r),
          border: Border.all(color: color.withOpacity(0.4)),
        ),
        child: Column(children: [
          Text(emoji, style: TextStyle(fontSize: 28.sp)),
          SizedBox(height: 6.h),
          Text(label, style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w700, color: color, fontFamily: 'Poppins')),
          SizedBox(height: 4.h),
          Text(sub, style: AppTheme.caption, textAlign: TextAlign.center),
        ]),
      ),
    );
  }

  // ✅ FIX: Central handler called after bill is saved successfully.
  //         1. Hides cart so UI feels responsive
  //         2. Resets cart via ResetAfterSave
  //         3. Navigates to BillViewScreen (print happens there on demand)
  Future<void> _onBillSaved(BuildContext context, Bill bill) async {
    // Close the payment bottom sheet first (it's the topmost route)
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }

    // Small delay to let the sheet dismiss animation complete
    await Future.delayed(_kBottomSheetDismissalDelay);

    setState(() => _showCart = false);
    context.read<BillingBloc>().add(ResetAfterSave());

    if (!mounted) return;

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('✅ Bill #${bill.billNumber} saved!'),
        backgroundColor: AppTheme.accent,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        margin: EdgeInsets.only(bottom: 24.h, left: 16.w, right: 16.w),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10.r)),
      ),
    );

    // Now safe to push BillViewScreen (bottom sheet is gone)
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => BillViewScreen(bill: bill)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<BillingBloc, CartState>(
      listenWhen: (prev, curr) =>
          prev.isSaving == true &&
          curr.isSaving == false &&
          curr.lastSavedBill != null,
      listener: (context, state) {
        final bill = state.lastSavedBill!;
        _onBillSaved(context, bill);
      },
      child: Scaffold(
        backgroundColor: AppTheme.surface,
        body: SafeArea(
          child: Column(
            children: [
              _buildTopBar(),
              _buildBillTypeToggle(),
              Expanded(
                  child: _showCart ? _buildCartView() : _buildProductView()),
            ],
          ),
        ),
      ),
    );
  }

  // ── Top Bar ───────────────────────────────────────────────────────────────
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
                    onChanged: (v) =>
                        context.read<ProductBloc>().add(SearchProducts(v)),
                    decoration: InputDecoration(
                      hintText: 'Search products...',
                      prefixIcon: Icon(Icons.search,
                          color: AppTheme.textSecondary, size: 20.sp),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                        icon: Icon(Icons.clear,
                            size: 18.sp,
                            color: AppTheme.textSecondary),
                        onPressed: () {
                          _searchController.clear();
                          context
                              .read<ProductBloc>()
                              .add(SearchProducts(''));
                        },
                      )
                          : null,
                      border: InputBorder.none,
                      contentPadding:
                      EdgeInsets.symmetric(vertical: 12.h),
                      hintStyle: AppTheme.caption,
                    ),
                    style: AppTheme.body,
                  ),
                ),
              ),
              SizedBox(width: 8.w),
              // ── Barcode Scan ──────────────────────────────────────────────
              GestureDetector(
                onTap: () => _scanBarcode(context),
                child: Container(
                  width: 44.w,
                  height: 44.h,
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(12.r),
                    border: Border.all(color: AppTheme.divider),
                  ),
                  child: Icon(Icons.qr_code_scanner,
                      color: AppTheme.textSecondary, size: 22.sp),
                ),
              ),
              // ── Held Bills Badge ────────────────────────────────────────────
              BlocBuilder<HeldBillBloc, HeldBillState>(
                builder: (context, heldState) {
                  final count = heldState.heldBills.length;
                  return GestureDetector(
                    onTap: () => _showHeldBillsPage(context),
                    child: Container(
                      width: 44.w,
                      height: 44.h,
                      decoration: BoxDecoration(
                        color: count > 0
                            ? AppTheme.warning.withOpacity(0.12)
                            : AppTheme.surface,
                        borderRadius: BorderRadius.circular(12.r),
                        border: Border.all(
                          color: count > 0
                              ? AppTheme.warning.withOpacity(0.6)
                              : AppTheme.divider,
                        ),
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Icon(Icons.pause_circle_outline_rounded,
                              color: count > 0
                                  ? AppTheme.warning
                                  : AppTheme.textSecondary,
                              size: 22.sp),
                          if (count > 0)
                            Positioned(
                              top: 6.h,
                              right: 5.w,
                              child: Container(
                                width: 15.w,
                                height: 15.w,
                                decoration: const BoxDecoration(
                                  color: AppTheme.warning,
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Text(
                                    count > 9 ? '9+' : '$count',
                                    style: TextStyle(
                                      fontSize: 8.sp,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              SizedBox(width: 8.w),
              GestureDetector(
                onTap: () => setState(() => _showCart = !_showCart),
                child: Container(
                  width: 50.w,
                  height: 44.h,
                  decoration: BoxDecoration(
                    color: _showCart
                        ? AppTheme.primary
                        : AppTheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Icon(Icons.shopping_cart_rounded,
                          color: _showCart
                              ? Colors.white
                              : AppTheme.primary,
                          size: 22.sp),
                      if (cart.itemCount > 0)
                        Positioned(
                          top: 6.h,
                          right: 6.w,
                          child: Container(
                            width: 16.w,
                            height: 16.w,
                            decoration: BoxDecoration(
                              color: _showCart
                                  ? Colors.white
                                  : AppTheme.danger,
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                cart.itemCount > 9
                                    ? '9+'
                                    : '${cart.itemCount}',
                                style: TextStyle(
                                  fontSize: 9.sp,
                                  fontWeight: FontWeight.w700,
                                  color: _showCart
                                      ? AppTheme.danger
                                      : Colors.white,
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

  // ── Bill Type Toggle ──────────────────────────────────────────────────────
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
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      if (!isRetail) {
                        context
                            .read<BillingBloc>()
                            .add(SetBillType(BillType.retail));
                      }
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: EdgeInsets.all(3.w),
                      decoration: BoxDecoration(
                        color: isRetail
                            ? AppTheme.primary
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(7.r),
                        boxShadow: isRetail
                            ? [
                          BoxShadow(
                              color: AppTheme.primary.withOpacity(0.25),
                              blurRadius: 6,
                              offset: const Offset(0, 2))
                        ]
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
                              color: isRetail
                                  ? Colors.white
                                  : AppTheme.textSecondary,
                              fontFamily: 'Poppins',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      if (isRetail) {
                        context
                            .read<BillingBloc>()
                            .add(SetBillType(BillType.wholesale));
                      }
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: EdgeInsets.all(3.w),
                      decoration: BoxDecoration(
                        color: !isRetail
                            ? const Color(0xFF2D3250)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(7.r),
                        boxShadow: !isRetail
                            ? [
                          BoxShadow(
                              color: const Color(0xFF2D3250)
                                  .withOpacity(0.25),
                              blurRadius: 6,
                              offset: const Offset(0, 2))
                        ]
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
                              color: !isRetail
                                  ? Colors.white
                                  : AppTheme.textSecondary,
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

  // ── Product Grid ──────────────────────────────────────────────────────────
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
                    gridDelegate:
                    SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      mainAxisSpacing: 10.h,
                      crossAxisSpacing: 10.w,
                      childAspectRatio: 0.82,
                    ),
                    itemCount: productState.filteredProducts.length,
                    itemBuilder: (context, index) {
                      final product =
                      productState.filteredProducts[index];
                      return ProductGridItem(
                        product: product,
                        billType: billType,
                        onTap: () async {
                          if (product.isOutOfStock) {
                            _showOutOfStockSnack(product.name);
                            return;
                          }
                          final uoms = await ProductRepositoryImpl(
                                  DatabaseHelper.instance)
                              .getProductUoms(product.id!);
                          if (!mounted) return;
                          if (uoms.isEmpty) {
                            await _addProductToCart(context, product);
                          } else {
                            showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              backgroundColor: Colors.transparent,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.vertical(
                                      top: Radius.circular(24.r))),
                              builder: (_) => BlocProvider.value(
                                value: context.read<BillingBloc>(),
                                child: UomPickerSheet(
                                  product: product,
                                  uoms: uoms,
                                ),
                              ),
                            );
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

  // ── Category Filter ───────────────────────────────────────────────────────
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
          border:
          Border.all(color: isSelected ? AppTheme.primary : AppTheme.divider),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(icon, style: TextStyle(fontSize: 13.sp)),
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

  // ── Cart View ─────────────────────────────────────────────────────────────
  Widget _buildCartView() {
    return BlocBuilder<BillingBloc, CartState>(
      builder: (context, state) {
        final cart = state as CartState;

        // ✅ Show error if save failed
        if (cart.errorMessage != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('Error: ${cart.errorMessage}'),
              backgroundColor: AppTheme.danger,
              behavior: SnackBarBehavior.floating,
            ));
          });
        }

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
                          UpdateCartItemQty(
                              productId: item.productId,
                              quantity: item.quantity + 1,
                              saleUomId: item.saleUomId)),
                      onDecrease: () => context.read<BillingBloc>().add(
                          UpdateCartItemQty(
                              productId: item.productId,
                              quantity: item.quantity - 1,
                              saleUomId: item.saleUomId)),
                      onRemove: () => context
                          .read<BillingBloc>()
                          .add(RemoveFromCart(item.productId,
                              saleUomId: item.saleUomId)),
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

  // ── Cart Summary ──────────────────────────────────────────────────────────
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
              offset: const Offset(0, -4))
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding:
                EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                decoration: BoxDecoration(
                  color: cart.billType == BillType.retail
                      ? AppTheme.primary.withOpacity(0.1)
                      : AppTheme.secondary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6.r),
                ),
                child: Text(
                  cart.billType == BillType.retail
                      ? '🛒 Retail Bill'
                      : '📦 Wholesale Bill',
                  style: TextStyle(
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Poppins',
                    color: cart.billType == BillType.retail
                        ? AppTheme.primary
                        : AppTheme.secondary,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                '${cart.items.length} item${cart.items.length == 1 ? '' : 's'}',
                style: AppTheme.caption,
              ),
            ],
          ),
          SizedBox(height: 10.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Subtotal',
                  style:
                  AppTheme.body.copyWith(color: AppTheme.textSecondary)),
              Text(CurrencyFormatter.format(cart.subtotal),
                  style: AppTheme.body),
            ],
          ),
          if (cart.gstTotal > 0) ...[
            SizedBox(height: 3.h),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('GST',
                    style: AppTheme.body
                        .copyWith(color: AppTheme.textSecondary)),
                Text(CurrencyFormatter.format(cart.gstTotal),
                    style: AppTheme.body),
              ],
            ),
          ],
          if (cart.discountAmount > 0) ...[
            SizedBox(height: 3.h),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Discount',
                    style:
                    AppTheme.body.copyWith(color: AppTheme.accent)),
                Text(
                    '-${CurrencyFormatter.format(cart.discountAmount)}',
                    style: AppTheme.body.copyWith(color: AppTheme.accent)),
              ],
            ),
          ],
          Divider(height: 14.h, color: AppTheme.divider),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Total', style: AppTheme.heading3),
              Text(CurrencyFormatter.format(cart.totalAmount),
                  style: AppTheme.price),
            ],
          ),
          SizedBox(height: 12.h),
          // ── Feature Action Buttons: Hold · Edit · Split ───────────────────
          if (!cart.isEmpty) ...[
            Row(
              children: [
                _cartActionBtn(
                  icon: Icons.pause_circle_outline_rounded,
                  label: 'Hold',
                  color: AppTheme.warning,
                  onTap: () => _holdBill(context, cart),
                ),
                SizedBox(width: 8.w),
                _cartActionBtn(
                  icon: Icons.edit_outlined,
                  label: 'Edit',
                  color: AppTheme.primary,
                  onTap: () => setState(() => _showCart = false),
                ),
                SizedBox(width: 8.w),
                _cartActionBtn(
                  icon: Icons.call_split_rounded,
                  label: 'Split',
                  color: AppTheme.accent,
                  onTap: cart.items.length >= 2
                      ? () => _showSplitBillPage(context, cart)
                      : null,
                ),
              ],
            ),
            SizedBox(height: 10.h),
          ],
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
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.r)),
                  ),
                  child: const Text('Clear'),
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  // ✅ Disable button while saving to prevent double-tap
                  onPressed: cart.isEmpty || cart.isSaving
                      ? null
                      : () => _showPaymentSheet(context, cart),
                  style: ElevatedButton.styleFrom(
                    minimumSize: Size(0, 48.h),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.r)),
                  ),
                  child: cart.isSaving
                      ? SizedBox(
                    height: 20.h,
                    width: 20.h,
                    child: const CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                      : Text(
                      'Pay ${CurrencyFormatter.format(cart.totalAmount)}'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Bottom Floating Bar ───────────────────────────────────────────────────
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
            padding:
            EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
            decoration: BoxDecoration(
              color: isWholesale ? AppTheme.secondary : AppTheme.primary,
              borderRadius: BorderRadius.circular(14.r),
              boxShadow: [
                BoxShadow(
                  color:
                  (isWholesale ? AppTheme.secondary : AppTheme.primary)
                      .withOpacity(0.35),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.symmetric(
                      horizontal: 8.w, vertical: 3.h),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.25),
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: Text(
                    '${cart.itemCount} items',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Poppins'),
                  ),
                ),
                SizedBox(width: 8.w),
                Text(
                  isWholesale ? '📦 View Cart' : '🛒 View Cart',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Poppins'),
                ),
                const Spacer(),
                Text(
                  CurrencyFormatter.format(cart.subtotal),
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'Poppins'),
                ),
                Icon(Icons.chevron_right,
                    color: Colors.white, size: 20.sp),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text('🔍', style: TextStyle(fontSize: 48.sp)),
        SizedBox(height: 12.h),
        Text('No products found', style: AppTheme.heading3),
        SizedBox(height: 4.h),
        Text('Try a different search or category',
            style: AppTheme.caption),
      ],
    ),
  );

  Widget _buildEmptyCart() => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text('🛒', style: TextStyle(fontSize: 56.sp)),
        SizedBox(height: 16.h),
        Text('Cart is empty', style: AppTheme.heading2),
        SizedBox(height: 8.h),
        Text('Tap products to add them to cart',
            style: AppTheme.caption),
        SizedBox(height: 20.h),
        TextButton.icon(
          onPressed: () => setState(() => _showCart = false),
          icon: const Icon(Icons.grid_view_rounded),
          label: const Text('Browse Products'),
        ),
      ],
    ),
  );

  void _showAddedFeedback(String name) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('$name added'),
      duration: const Duration(milliseconds: 700),
      backgroundColor: AppTheme.accent,
      behavior: SnackBarBehavior.floating,
      margin: EdgeInsets.only(bottom: 80.h, left: 16.w, right: 16.w),
      shape:
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
    ));
  }

  void _showOutOfStockSnack(String name) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('$name — Out of stock'),
      backgroundColor: AppTheme.danger,
      behavior: SnackBarBehavior.floating,
      margin: EdgeInsets.only(bottom: 80.h, left: 16.w, right: 16.w),
      shape:
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
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

  // ── Cart Action Button helper ────────────────────────────────────────────
  Widget _cartActionBtn({
    required IconData icon,
    required String label,
    required Color color,
    VoidCallback? onTap,
  }) {
    final active = onTap != null;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Opacity(
          opacity: active ? 1.0 : 0.4,
          child: Container(
            padding: EdgeInsets.symmetric(vertical: 8.h),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10.r),
              border: Border.all(color: color.withOpacity(0.35)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: color, size: 20.sp),
                SizedBox(height: 3.h),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w600,
                    color: color,
                    fontFamily: 'Poppins',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Hold Bill ─────────────────────────────────────────────────────────────
  void _holdBill(BuildContext context, CartState cart) {
    final nameCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
        title: Row(children: [
          Text('⏸️', style: TextStyle(fontSize: 22.sp)),
          SizedBox(width: 8.w),
          Text('Hold Bill', style: AppTheme.heading3),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Give this bill a name (optional) so you can find it later.',
              style: AppTheme.caption,
            ),
            SizedBox(height: 12.h),
            TextField(
              controller: nameCtrl,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'e.g., Table 3, John...',
                prefixIcon: const Icon(Icons.label_outline),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.warning,
              minimumSize: Size(80.w, 38.h),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              if (!mounted) return;
              final name = nameCtrl.text.trim();
              context.read<HeldBillBloc>().add(HoldCurrentBill(
                    cart,
                    holdName: name.isEmpty ? null : name,
                  ));
              context.read<BillingBloc>().add(ClearCart());
              setState(() => _showCart = false);
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: const Text('⏸️ Bill held! Start a new bill.'),
                backgroundColor: AppTheme.warning,
                behavior: SnackBarBehavior.floating,
                duration: const Duration(seconds: 2),
                margin: EdgeInsets.only(bottom: 24.h, left: 16.w, right: 16.w),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10.r)),
              ));
            },
            child: const Text('Hold Bill'),
          ),
        ],
      ),
    );
  }

  // ── Held Bills Page ────────────────────────────────────────────────────────
  void _showHeldBillsPage(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MultiBlocProvider(
          providers: [
            BlocProvider.value(value: context.read<HeldBillBloc>()),
            BlocProvider.value(value: context.read<BillingBloc>()),
          ],
          child: HeldBillsPage(
            onRestore: (bill) {
              // Convert HeldBillItems → CartItems
              final cartItems = bill.items
                  .map((item) => CartItem(
                        productId: item.productId,
                        productName: item.productName,
                        unit: item.unit,
                        sellingPrice: item.unitPrice,
                        wholesalePrice: item.unitPrice,
                        purchasePrice: item.purchasePrice,
                        gstRate: item.gstRate,
                        gstInclusive: item.gstInclusive,
                        rateType: 'fixed',
                        quantity: item.quantity,
                      ))
                  .toList();

              context.read<BillingBloc>().add(RestoreHeldCartItems(
                    items: cartItems,
                    billType: bill.billType,
                    customerName: bill.customerName,
                    discountAmount: bill.discountAmount,
                  ));

              // Delete the restored held bill so it's not shown twice
              context.read<HeldBillBloc>().add(DeleteHeldBill(bill.id!));

              if (mounted) setState(() => _showCart = true);
            },
          ),
        ),
      ),
    );
  }

  // ── Split Bill Page ────────────────────────────────────────────────────────
  void _showSplitBillPage(BuildContext context, CartState cart) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MultiBlocProvider(
          providers: [
            BlocProvider.value(value: context.read<BillingBloc>()),
            BlocProvider.value(value: context.read<HeldBillBloc>()),
          ],
          child: SplitBillPage(cart: cart),
        ),
      ),
    ).then((_) {
      // After returning, show the cart if items exist
      if (mounted) {
        final currentCart = context.read<BillingBloc>().state;
        if (!currentCart.isEmpty) {
          setState(() => _showCart = true);
        }
      }
    });
  }
}

// ── Barcode Scanner Bottom Sheet ──────────────────────────────────────────────
class _BarcodeScannerSheet extends StatefulWidget {
  const _BarcodeScannerSheet();

  @override
  State<_BarcodeScannerSheet> createState() => _BarcodeScannerSheetState();
}

class _BarcodeScannerSheetState extends State<_BarcodeScannerSheet> {
  late final MobileScannerController _controller;
  bool _hasScanned = false;

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 320.h,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
      ),
      child: Column(children: [
        Padding(
          padding: EdgeInsets.all(12.w),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Scan Barcode',
                  style: TextStyle(color: Colors.white, fontSize: 16.sp,
                      fontWeight: FontWeight.w600, fontFamily: 'Poppins')),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        ),
        Expanded(
          child: MobileScanner(
            controller: _controller,
            onDetect: (capture) {
              if (_hasScanned) return;
              final barcode = capture.barcodes.firstOrNull?.rawValue;
              if (barcode != null && barcode.isNotEmpty) {
                _hasScanned = true;
                Navigator.pop(context, barcode);
              }
            },
          ),
        ),
        const SizedBox(height: 16),
        const Text('Point camera at a barcode',
            style: TextStyle(color: Colors.white60, fontSize: 13)),
        const SizedBox(height: 12),
      ]),
    );
  }
}
}