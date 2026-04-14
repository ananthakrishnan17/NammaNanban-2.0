import '../../../../core/database/database_helper.dart';

abstract class SalesRepository {
  Future<Map<String, double>> getDailySummary(DateTime date);
  Future<Map<String, double>> getMonthlySummary(int year, int month);
  Future<List<Map<String, double>>> getLast7DaysSales();
  Future<List<Map<String, dynamic>>> getProductWiseSales(DateTime from, DateTime to);
  Future<List<Map<String, dynamic>>> getDailyReport(DateTime date);
}

class SalesRepositoryImpl implements SalesRepository {
  final DatabaseHelper _dbHelper;
  SalesRepositoryImpl(this._dbHelper);

  @override
  Future<Map<String, double>> getDailySummary(DateTime date) async {
    final db = await _dbHelper.database;
    final dateStr = date.toIso8601String().substring(0, 10);
    final result = await db.rawQuery('''
      SELECT 
        COALESCE(SUM(total_amount), 0.0) as total_sales,
        COALESCE(SUM(total_profit), 0.0) as total_profit,
        COUNT(*) as bill_count
      FROM bills WHERE created_at LIKE ?
    ''', ['$dateStr%']);
    final row = result.first;
    return {
      'sales': (row['total_sales'] as num).toDouble(),
      'profit': (row['total_profit'] as num).toDouble(),
      'billCount': (row['bill_count'] as num).toDouble(),
    };
  }

  @override
  Future<Map<String, double>> getMonthlySummary(int year, int month) async {
    final db = await _dbHelper.database;
    final prefix = '$year-${month.toString().padLeft(2, '0')}';
    final result = await db.rawQuery('''
      SELECT 
        COALESCE(SUM(total_amount), 0.0) as total_sales,
        COALESCE(SUM(total_profit), 0.0) as total_profit,
        COUNT(*) as bill_count
      FROM bills WHERE created_at LIKE ?
    ''', ['$prefix%']);
    final row = result.first;
    return {
      'sales': (row['total_sales'] as num).toDouble(),
      'profit': (row['total_profit'] as num).toDouble(),
      'billCount': (row['bill_count'] as num).toDouble(),
    };
  }

  @override
  Future<List<Map<String, double>>> getLast7DaysSales() async {
    final db = await _dbHelper.database;
    final result = <Map<String, double>>[];
    for (int i = 6; i >= 0; i--) {
      final date = DateTime.now().subtract(Duration(days: i));
      final dateStr = date.toIso8601String().substring(0, 10);
      final rows = await db.rawQuery('''
        SELECT COALESCE(SUM(total_amount), 0.0) as sales,
               COALESCE(SUM(total_profit), 0.0) as profit
        FROM bills WHERE created_at LIKE ?
      ''', ['$dateStr%']);
      result.add({
        'sales': (rows.first['sales'] as num).toDouble(),
        'profit': (rows.first['profit'] as num).toDouble(),
      });
    }
    return result;
  }

  @override
  Future<List<Map<String, dynamic>>> getProductWiseSales(DateTime from, DateTime to) async {
    final db = await _dbHelper.database;
    final rows = await db.rawQuery('''
      SELECT 
        bi.product_name,
        SUM(bi.quantity) as total_qty,
        SUM(bi.total_price) as total_revenue,
        SUM((bi.unit_price - bi.purchase_price) * bi.quantity) as total_profit,
        COUNT(DISTINCT bi.bill_id) as bill_count
      FROM bill_items bi
      INNER JOIN bills b ON bi.bill_id = b.id
      WHERE b.created_at BETWEEN ? AND ?
      GROUP BY bi.product_id, bi.product_name
      ORDER BY total_revenue DESC
    ''', [from.toIso8601String(), to.toIso8601String()]);
    return rows.map((r) => Map<String, dynamic>.from(r)).toList();
  }

  @override
  Future<List<Map<String, dynamic>>> getDailyReport(DateTime date) async {
    final db = await _dbHelper.database;
    final dateStr = date.toIso8601String().substring(0, 10);
    final rows = await db.rawQuery('''
      SELECT b.*, 
             GROUP_CONCAT(bi.product_name || ' x' || bi.quantity, ', ') as items_summary
      FROM bills b
      LEFT JOIN bill_items bi ON b.id = bi.bill_id
      WHERE b.created_at LIKE ?
      GROUP BY b.id
      ORDER BY b.created_at DESC
    ''', ['$dateStr%']);
    return rows.map((r) => Map<String, dynamic>.from(r)).toList();
  }
}
