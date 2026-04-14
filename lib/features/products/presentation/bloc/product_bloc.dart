import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import '../../domain/entities/product.dart';
import '../../data/repositories/product_repository_impl.dart';

// ─── Events ───────────────────────────────────────────────────────────────────
abstract class ProductEvent extends Equatable {
  @override List<Object?> get props => [];
}
class LoadProducts extends ProductEvent {}
class SearchProducts extends ProductEvent {
  final String query; SearchProducts(this.query);
  @override List<Object?> get props => [query];
}
class AddProduct extends ProductEvent {
  final Product product; AddProduct(this.product);
  @override List<Object?> get props => [product];
}
class UpdateProduct extends ProductEvent {
  final Product product; UpdateProduct(this.product);
  @override List<Object?> get props => [product];
}
class DeleteProduct extends ProductEvent {
  final int id; DeleteProduct(this.id);
  @override List<Object?> get props => [id];
}
class AdjustStock extends ProductEvent {
  final int productId; final double quantity; final String reason;
  AdjustStock({required this.productId, required this.quantity, required this.reason});
  @override List<Object?> get props => [productId, quantity];
}
class FilterByCategory extends ProductEvent {
  final int? categoryId; FilterByCategory(this.categoryId);
  @override List<Object?> get props => [categoryId];
}

// ── NEW: Category CRUD events ─────────────────────────────────────────────────
class AddCategoryEvent extends ProductEvent {
  final String name; final String icon; final String color;
  AddCategoryEvent(this.name, {this.icon = '📦', this.color = '#FF6B35'});
  @override List<Object?> get props => [name];
}
class DeleteCategoryEvent extends ProductEvent {
  final int id; DeleteCategoryEvent(this.id);
  @override List<Object?> get props => [id];
}

// ─── States ───────────────────────────────────────────────────────────────────
abstract class ProductState extends Equatable {
  @override List<Object?> get props => [];
}
class ProductInitial extends ProductState {}
class ProductLoading extends ProductState {}
class ProductsLoaded extends ProductState {
  final List<Product> products;
  final List<Product> filteredProducts;
  final List<Product> lowStockProducts;
  final List<Category> categories;
  final int? selectedCategoryId;
  final String searchQuery;

  ProductsLoaded({required this.products, required this.filteredProducts,
    required this.lowStockProducts, required this.categories,
    this.selectedCategoryId, this.searchQuery = ''});

  ProductsLoaded copyWith({List<Product>? products, List<Product>? filteredProducts,
    List<Product>? lowStockProducts, List<Category>? categories,
    int? selectedCategoryId, String? searchQuery}) => ProductsLoaded(
    products: products ?? this.products,
    filteredProducts: filteredProducts ?? this.filteredProducts,
    lowStockProducts: lowStockProducts ?? this.lowStockProducts,
    categories: categories ?? this.categories,
    selectedCategoryId: selectedCategoryId ?? this.selectedCategoryId,
    searchQuery: searchQuery ?? this.searchQuery,
  );

  @override List<Object?> get props => [products, filteredProducts, lowStockProducts, categories, selectedCategoryId, searchQuery];
}
class ProductError extends ProductState {
  final String message; ProductError(this.message);
  @override List<Object?> get props => [message];
}

// ─── BLoC ─────────────────────────────────────────────────────────────────────
class ProductBloc extends Bloc<ProductEvent, ProductState> {
  final ProductRepository _repository;

  // ✅ Expose repository so UI can directly call addCategory for inline-create
  ProductRepository get repository => _repository;

  ProductBloc(this._repository) : super(ProductInitial()) {
    on<LoadProducts>(_onLoadProducts);
    on<SearchProducts>(_onSearchProducts);
    on<AddProduct>(_onAddProduct);
    on<UpdateProduct>(_onUpdateProduct);
    on<DeleteProduct>(_onDeleteProduct);
    on<AdjustStock>(_onAdjustStock);
    on<FilterByCategory>(_onFilterByCategory);
    on<AddCategoryEvent>(_onAddCategory);
    on<DeleteCategoryEvent>(_onDeleteCategory);
  }

  Future<void> _onLoadProducts(LoadProducts event, Emitter<ProductState> emit) async {
    emit(ProductLoading());
    try {
      final products = await _repository.getAllProducts();
      final lowStock = await _repository.getLowStockProducts();
      final categories = await _repository.getAllCategories();
      emit(ProductsLoaded(products: products, filteredProducts: products,
          lowStockProducts: lowStock, categories: categories));
    } catch (e) { emit(ProductError(e.toString())); }
  }

  Future<void> _onSearchProducts(SearchProducts event, Emitter<ProductState> emit) async {
    if (state is! ProductsLoaded) return;
    final current = state as ProductsLoaded;
    if (event.query.isEmpty) {
      emit(current.copyWith(filteredProducts: current.products, searchQuery: '')); return;
    }
    final q = event.query.toLowerCase();
    emit(current.copyWith(
      filteredProducts: current.products.where((p) => p.name.toLowerCase().contains(q)).toList(),
      searchQuery: event.query,
    ));
  }

  Future<void> _onAddProduct(AddProduct event, Emitter<ProductState> emit) async {
    try { await _repository.addProduct(event.product); add(LoadProducts()); }
    catch (e) { emit(ProductError(e.toString())); }
  }

  Future<void> _onUpdateProduct(UpdateProduct event, Emitter<ProductState> emit) async {
    try { await _repository.updateProduct(event.product); add(LoadProducts()); }
    catch (e) { emit(ProductError(e.toString())); }
  }

  Future<void> _onDeleteProduct(DeleteProduct event, Emitter<ProductState> emit) async {
    try { await _repository.deleteProduct(event.id); add(LoadProducts()); }
    catch (e) { emit(ProductError(e.toString())); }
  }

  Future<void> _onAdjustStock(AdjustStock event, Emitter<ProductState> emit) async {
    try { await _repository.updateStock(event.productId, event.quantity); add(LoadProducts()); }
    catch (e) { emit(ProductError(e.toString())); }
  }

  Future<void> _onFilterByCategory(FilterByCategory event, Emitter<ProductState> emit) async {
    if (state is! ProductsLoaded) return;
    final current = state as ProductsLoaded;
    final filtered = event.categoryId == null
        ? current.products
        : current.products.where((p) => p.categoryId == event.categoryId).toList();
    emit(current.copyWith(filteredProducts: filtered, selectedCategoryId: event.categoryId));
  }

  // ── Category CRUD ─────────────────────────────────────────────────────────
  Future<void> _onAddCategory(AddCategoryEvent event, Emitter<ProductState> emit) async {
    try {
      await _repository.addCategory(
          Category(name: event.name, icon: event.icon, color: event.color));
      add(LoadProducts()); // reload so categories list updates everywhere
    } catch (e) { emit(ProductError(e.toString())); }
  }

  Future<void> _onDeleteCategory(DeleteCategoryEvent event, Emitter<ProductState> emit) async {
    try { await _repository.deleteCategory(event.id); add(LoadProducts()); }
    catch (e) { emit(ProductError(e.toString())); }
  }
}