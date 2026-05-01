import 'package:flutter/foundation.dart';
import '../../../../core/database/database_helper.dart';
import '../../../../core/ledger/ledger_service.dart';
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

  /// Exact barcode lookup — returns the matching product or null.
  Future<Product?> findByBarcode(String barcode) async {
    if (barcode.isEmpty) return null;
    final db = await _dbHelper.database;
    final rows = await db.rawQuery('''
      SELECT p.*, c.name as category_name, b.name as brand_name, u.short_name as uom_short_name
      FROM products p
      LEFT JOIN categories c ON p.category_id = c.id
      LEFT JOIN brands b ON p.brand_id = b.id
      LEFT JOIN uom_units u ON p.uom_id = u.id
      WHERE p.is_active = 1 AND p.barcode = ?
      LIMIT 1''', [barcode]);
    if (rows.isEmpty) return null;
    return ProductModel.fromMap(rows.first);
  }

  @override Future<List<Product>> getLowStockProducts() async {
    final db = await _dbHelper.database;
    final rows = await db.rawQuery('''
      SELECT p.*, c.name as category_name, b.name as brand_name, u.short_name as uom_short_name
      FROM products p
      LEFT JOIN categories c ON p.category_id = c.id
      LEFT JOIN brands b ON p.brand_id = b.id
      LEFT JOIN uom_units u ON p.uom_id = u.id
      WHERE p.is_active = 1 AND p.stock_quantity > 0 AND p.stock_quantity <= p.low_stock_threshold  -- FIX BUG#7
      ORDER BY p.stock_quantity ASC''');
    return rows.map((m) => ProductModel.fromMap(m)).toList();
  }

  @override Future<int> addProduct(Product product) async {
    final db = await _dbHelper.database;
    final productId = await db.insert('products', (product as ProductModel).toMap());

    // ── Opening stock ledger ─────────────────────────────────────────────
    // Only create a ledger entry when the product is added with stock > 0.
    // Normal add-product (no stock) does NOT create any ledger entries.
    if (product.stockQuantity > 0) {
      try {
        final ledger = LedgerService.instance;
        final licenseId = await ledger.getLicenseId();
        final nowStr = DateTime.now().toIso8601String();
        final inventoryValue = product.purchasePrice * product.stockQuantity;
        await ledger.recordTransaction(
          executor: db,
          type: 'stock_adjustment',
          totalAmount: inventoryValue,
          tags: {
            'product_id': productId,
            'product_name': product.name,
            'reason': 'opening_stock',
          },
          licenseId: licenseId,
          createdAt: nowStr,
          entries: [
            LedgerEntryInput(
              accountType: 'inventory', direction: 'debit',
              amount: inventoryValue, quantityChange: product.stockQuantity,
            ),
            LedgerEntryInput(
              accountType: 'liability', direction: 'credit',
              amount: inventoryValue,
            ),
          ],
        );
      } catch (e, st) {
        // Ledger failure must not block product creation.
        // Log for audit purposes.
        debugPrint('[LedgerService] opening stock ledger write failed: $e\n$st');
      }
    }

    return productId;
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
    final updated = (await db.rawUpdate(
        'UPDATE products SET stock_quantity = stock_quantity + ?, updated_at = ? WHERE id = ?',
        [quantityChange, DateTime.now().toIso8601String(), productId])) > 0;

    if (updated) {
      // ── Stock adjustment ledger ────────────────────────────────────────
      // Increase:  DR Inventory  / CR Asset (adjustment gain)
      // Decrease:  DR Expense    / CR Inventory
      try {
        final ledger = LedgerService.instance;
        final licenseId = await ledger.getLicenseId();
        final nowStr = DateTime.now().toIso8601String();

        // Look up product purchase price for inventory valuation
        final productRows = await db.query('products',
            columns: ['purchase_price', 'name'],
            where: 'id = ?', whereArgs: [productId]);
        final purchasePrice = productRows.isNotEmpty
            ? (productRows.first['purchase_price'] as num?)?.toDouble() ?? 0.0
            : 0.0;
        final productName = productRows.isNotEmpty
            ? productRows.first['name'] as String? ?? 'Product'
            : 'Product';
        final inventoryValue = purchasePrice * quantityChange.abs();

        final List<LedgerEntryInput> entries;
        if (quantityChange > 0) {
          // Stock increase: DR Inventory / CR Asset (adjustment)
          entries = [
            LedgerEntryInput(
              accountType: 'inventory', direction: 'debit',
              amount: inventoryValue, quantityChange: quantityChange,
            ),
            LedgerEntryInput(
              accountType: 'asset', direction: 'credit',
              amount: inventoryValue,
            ),
          ];
        } else {
          // Stock decrease (write-down): DR Expense / CR Inventory
          entries = [
            LedgerEntryInput(
              accountType: 'expense', direction: 'debit',
              amount: inventoryValue,
            ),
            LedgerEntryInput(
              accountType: 'inventory', direction: 'credit',
              amount: inventoryValue, quantityChange: quantityChange,
            ),
          ];
        }

        await ledger.recordTransaction(
          executor: db,
          type: 'stock_adjustment',
          totalAmount: inventoryValue,
          tags: {
            'product_id': productId,
            'product_name': productName,
            'quantity_change': quantityChange,
          },
          licenseId: licenseId,
          createdAt: nowStr,
          entries: entries,
        );
      } catch (e, st) {
        // Ledger failure must not block stock update.
        // Log for audit purposes.
        debugPrint('[LedgerService] stock adjustment ledger write failed: $e\n$st');
      }
    }

    return updated;
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
        where: "product_id = ? AND unit_role = 'sale'",
        whereArgs: [productId],
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