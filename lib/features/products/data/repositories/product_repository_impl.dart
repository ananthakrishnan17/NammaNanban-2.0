import '../../../../core/database/database_helper.dart';
import '../../domain/entities/product.dart';
import '../../../users/domain/entities/product_uom.dart';

abstract class ProductRepository {
  Future<List<Product>> getAllProducts();
  Future<List<Product>> searchProducts(String query);
  Future<List<Product>> getLowStockProducts();
  Future<int> addProduct(Product product);
  Future<bool> updateProduct(Product product);
  Future<bool> deleteProduct(int id);
  Future<bool> updateStock(int productId, double quantity);
  Future<List<Category>> getAllCategories();
  Future<int> addCategory(Category category);
  Future<bool> deleteCategory(int id);
  Future<List<ProductUom>> getProductUoms(int productId);
  Future<int> addProductUom(ProductUom uom);
  Future<bool> updateProductUom(ProductUom uom);
  Future<bool> deleteProductUom(int id);
}

class ProductRepositoryImpl implements ProductRepository {
  final DatabaseHelper _dbHelper;
  ProductRepositoryImpl(this._dbHelper);

  @override Future<List<Product>> getAllProducts() async {
    final db = await _dbHelper.database;
    final rows = await db.rawQuery('''
      SELECT p.*, c.name as category_name, b.name as brand_name, u.short_name as uom_short_name
      FROM products p
      LEFT JOIN categories c ON p.category_id = c.id
      LEFT JOIN brands b ON p.brand_id = b.id
      LEFT JOIN uom_units u ON p.uom_id = u.id
      WHERE p.is_active = 1 ORDER BY p.name ASC''');
    return rows.map((m) => ProductModel.fromMap(m)).toList();
  }

  @override Future<List<Product>> searchProducts(String query) async {
    final db = await _dbHelper.database;
    final rows = await db.rawQuery('''
      SELECT p.*, c.name as category_name, b.name as brand_name, u.short_name as uom_short_name
      FROM products p
      LEFT JOIN categories c ON p.category_id = c.id
      LEFT JOIN brands b ON p.brand_id = b.id
      LEFT JOIN uom_units u ON p.uom_id = u.id
      WHERE p.is_active = 1 AND (p.name LIKE ? OR p.barcode LIKE ?)
      ORDER BY p.name ASC''', ['%$query%', '%$query%']);
    return rows.map((m) => ProductModel.fromMap(m)).toList();
  }

  @override Future<List<Product>> getLowStockProducts() async {
    final db = await _dbHelper.database;
    final rows = await db.rawQuery('''
      SELECT p.*, c.name as category_name, b.name as brand_name, u.short_name as uom_short_name
      FROM products p
      LEFT JOIN categories c ON p.category_id = c.id
      LEFT JOIN brands b ON p.brand_id = b.id
      LEFT JOIN uom_units u ON p.uom_id = u.id
      WHERE p.is_active = 1 AND p.stock_quantity <= p.low_stock_threshold
      ORDER BY p.stock_quantity ASC''');
    return rows.map((m) => ProductModel.fromMap(m)).toList();
  }

  @override Future<int> addProduct(Product product) async {
    final db = await _dbHelper.database;
    return await db.insert('products', (product as ProductModel).toMap());
  }

  @override Future<bool> updateProduct(Product product) async {
    final db = await _dbHelper.database;
    return (await db.update('products', (product as ProductModel).toMap(), where: 'id=?', whereArgs: [product.id])) > 0;
  }

  @override Future<bool> deleteProduct(int id) async {
    final db = await _dbHelper.database;
    return (await db.update('products', {'is_active': 0, 'updated_at': DateTime.now().toIso8601String()}, where: 'id=?', whereArgs: [id])) > 0;
  }

  @override Future<bool> updateStock(int productId, double quantityChange) async {
    final db = await _dbHelper.database;
    return (await db.rawUpdate('UPDATE products SET stock_quantity = stock_quantity + ?, updated_at = ? WHERE id = ?',
        [quantityChange, DateTime.now().toIso8601String(), productId])) > 0;
  }

  @override Future<List<Category>> getAllCategories() async {
    final db = await _dbHelper.database;
    final rows = await db.query('categories', orderBy: 'name ASC');
    return rows.map((m) => Category.fromMap(m)).toList();
  }

  @override Future<int> addCategory(Category category) async {
    final db = await _dbHelper.database;
    return await db.insert('categories', category.toMap());
  }

  @override Future<bool> deleteCategory(int id) async {
    final db = await _dbHelper.database;
    return (await db.delete('categories', where: 'id=?', whereArgs: [id])) > 0;
  }

  @override Future<List<ProductUom>> getProductUoms(int productId) async {
    final db = await _dbHelper.database;
    final rows = await db.query('product_uoms',
        where: 'product_id = ?', whereArgs: [productId],
        orderBy: 'is_default DESC, id ASC');
    return rows.map((m) => ProductUom.fromMap(m)).toList();
  }

  @override Future<int> addProductUom(ProductUom uom) async {
    final db = await _dbHelper.database;
    if (uom.isDefault) {
      await db.update('product_uoms', {'is_default': 0},
          where: 'product_id = ?', whereArgs: [uom.productId]);
    }
    return await db.insert('product_uoms', uom.toMap());
  }

  @override Future<bool> updateProductUom(ProductUom uom) async {
    final db = await _dbHelper.database;
    if (uom.isDefault) {
      await db.update('product_uoms', {'is_default': 0},
          where: 'product_id = ? AND id != ?', whereArgs: [uom.productId, uom.id]);
    }
    return (await db.update('product_uoms', uom.toMap(),
        where: 'id = ?', whereArgs: [uom.id])) > 0;
  }

  @override Future<bool> deleteProductUom(int id) async {
    final db = await _dbHelper.database;
    return (await db.delete('product_uoms', where: 'id = ?', whereArgs: [id])) > 0;
  }
}