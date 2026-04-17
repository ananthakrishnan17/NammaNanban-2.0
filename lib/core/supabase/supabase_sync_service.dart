import 'package:shared_preferences/shared_preferences.dart';
import '../database/database_helper.dart';
import '../supabase/supabase_config.dart';
import '../supabase/supabase_auth_service.dart';

/// Syncs bills and products to Supabase cloud
/// Called after: bill saved, product added/updated
class SupabaseSyncService {
  static final SupabaseSyncService instance = SupabaseSyncService._();
  SupabaseSyncService._();

  static const _kLastBillSync = 'sync_last_bill_id';
  static const _kLastProductSync = 'sync_last_product_ts';

  // ── Sync Bills ────────────────────────────────────────────────────────────
  /// Sync a just-saved bill immediately
  Future<bool> syncBill({
    required int localBillId,
    required String billNumber,
    required String billType,
    required double totalAmount,
    required double totalProfit,
    required double discountAmount,
    required double gstTotal,
    required String paymentMode,
    required String? customerName,
    required String? billedBy,
    required List<Map<String, dynamic>> items,
    required DateTime createdAt,
  }) async {
    try {
      final licenseId = await SupabaseAuthService.instance.licenseId;
      if (licenseId == null) return false;

      await SupabaseClientHelper.table('bills_sync').insert({
        'license_id': licenseId,
        'local_bill_id': localBillId,
        'bill_number': billNumber,
        'bill_type': billType,
        'customer_name': customerName,
        'total_amount': totalAmount,
        'total_profit': totalProfit,
        'discount_amount': discountAmount,
        'gst_total': gstTotal,
        'payment_mode': paymentMode,
        'billed_by': billedBy,
        'items_json': items,
        'created_at': createdAt.toIso8601String(),
        'synced_at': DateTime.now().toIso8601String(),
      });

      // Update last synced bill id
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_kLastBillSync, localBillId);
      return true;
    } catch (e) {
      // Sync failure is non-fatal — bill is already saved locally
      return false;
    }
  }

  /// Bulk sync all unsynced bills (call on app start if online)
  Future<void> syncPendingBills() async {
    try {
      final licenseId = await SupabaseAuthService.instance.licenseId;
      if (licenseId == null) return;

      final db = await DatabaseHelper.instance.database;
      final prefs = await SharedPreferences.getInstance();
      final lastSyncedId = prefs.getInt(_kLastBillSync) ?? 0;

      // Get bills not yet synced
      final bills = await db.rawQuery('''
        SELECT b.*, GROUP_CONCAT(
          json_object(
            'product_name', bi.product_name,
            'quantity', bi.quantity,
            'unit', bi.unit,
            'unit_price', bi.unit_price,
            'total_price', bi.total_price,
            'gst_rate', bi.gst_rate
          )
        ) as items_json
        FROM bills b
        LEFT JOIN bill_items bi ON b.id = bi.bill_id
        WHERE b.id > ?
        GROUP BY b.id
        ORDER BY b.id ASC
        LIMIT 100
      ''', [lastSyncedId]);

      if (bills.isEmpty) return;

      for (final bill in bills) {
        await syncBill(
          localBillId: bill['id'] as int,
          billNumber: bill['bill_number'] as String,
          billType: bill['bill_type'] as String? ?? 'retail',
          totalAmount: (bill['total_amount'] as num).toDouble(),
          totalProfit: (bill['total_profit'] as num).toDouble(),
          discountAmount: (bill['discount_amount'] as num?)?.toDouble() ?? 0,
          gstTotal: (bill['gst_total'] as num?)?.toDouble() ?? 0,
          paymentMode: bill['payment_mode'] as String? ?? 'cash',
          customerName: bill['customer_name'] as String?,
          billedBy: null, // will be set after user system integration
          items: [], // already have items in bill_items table
          createdAt: DateTime.parse(bill['created_at'] as String),
        );
      }
    } catch (e) {
      // Non-fatal
    }
  }

  // ── Sync Products ─────────────────────────────────────────────────────────
  /// Sync a product immediately after create/update
  Future<bool> syncProduct({
    required int localProductId,
    required String name,
    required String? categoryName,
    required String? brandName,
    required double purchasePrice,
    required double sellingPrice,
    required double wholesalePrice,
    required double stockQuantity,
    required String unit,
    required double gstRate,
    required bool isActive,
    required DateTime updatedAt,
  }) async {
    try {
      final licenseId = await SupabaseAuthService.instance.licenseId;
      if (licenseId == null) return false;

      // Upsert — update if exists, insert if not
      await SupabaseClientHelper.table('products_sync').upsert({
        'license_id': licenseId,
        'local_product_id': localProductId,
        'name': name,
        'category_name': categoryName,
        'brand_name': brandName,
        'purchase_price': purchasePrice,
        'selling_price': sellingPrice,
        'wholesale_price': wholesalePrice,
        'stock_quantity': stockQuantity,
        'unit': unit,
        'gst_rate': gstRate,
        'is_active': isActive,
        'updated_at': updatedAt.toIso8601String(),
        'synced_at': DateTime.now().toIso8601String(),
      }, onConflict: 'license_id, local_product_id');

      return true;
    } catch (e) {
      return false;
    }
  }

  /// Bulk sync all products (call on app start)
  Future<void> syncAllProducts() async {
    try {
      final licenseId = await SupabaseAuthService.instance.licenseId;
      if (licenseId == null) return;

      final db = await DatabaseHelper.instance.database;
      final products = await db.rawQuery('''
        SELECT p.*, c.name as category_name, b.name as brand_name
        FROM products p
        LEFT JOIN categories c ON p.category_id = c.id
        LEFT JOIN brands b ON p.brand_id = b.id
        WHERE p.is_active = 1
      ''');

      for (final p in products) {
        await syncProduct(
          localProductId: p['id'] as int,
          name: p['name'] as String,
          categoryName: p['category_name'] as String?,
          brandName: p['brand_name'] as String?,
          purchasePrice: (p['purchase_price'] as num).toDouble(),
          sellingPrice: (p['selling_price'] as num).toDouble(),
          wholesalePrice: (p['wholesale_price'] as num?)?.toDouble() ?? 0,
          stockQuantity: (p['stock_quantity'] as num).toDouble(),
          unit: p['unit'] as String? ?? 'piece',
          gstRate: (p['gst_rate'] as num?)?.toDouble() ?? 0,
          isActive: (p['is_active'] as int? ?? 1) == 1,
          updatedAt: DateTime.tryParse(p['updated_at'] as String? ?? '') ?? DateTime.now(),
        );
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kLastProductSync, DateTime.now().toIso8601String());
    } catch (e) {
      // Non-fatal
    }
  }

  // ── Check Connectivity + Auto Sync ───────────────────────────────────────
  /// Call this on app foreground / startup
  Future<void> autoSync() async {
    try {
      // Fire and forget — don't block app startup
      await Future.wait([
        syncPendingBills(),
        syncAllProducts(),
      ]);
    } catch (_) {}
  }
}