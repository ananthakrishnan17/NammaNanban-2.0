import 'package:equatable/equatable.dart';
import '../../../../core/database/database_helper.dart';
import '../../../products/domain/entities/product.dart';

// ─── Brand ─────────────────────────────────────────────────────────────────────
class Brand extends Equatable {
  final int? id;
  final String name;
  final String? description;
  final DateTime createdAt;

  const Brand({this.id, required this.name, this.description, required this.createdAt});

  factory Brand.fromMap(Map<String, dynamic> m) => Brand(
      id: m['id'], name: m['name'], description: m['description'],
      createdAt: DateTime.parse(m['created_at']));

  Map<String, dynamic> toMap() => {
    if (id != null) 'id': id, 'name': name,
    'description': description, 'created_at': createdAt.toIso8601String()};

  @override List<Object?> get props => [id, name];
}

// ─── UOM Unit ─────────────────────────────────────────────────────────────────
class UomUnit extends Equatable {
  final int? id;
  final String name;
  final String shortName;
  final String uomType; // count, weight, volume, length
  final DateTime createdAt;

  const UomUnit({this.id, required this.name, required this.shortName,
    this.uomType = 'count', required this.createdAt});

  factory UomUnit.fromMap(Map<String, dynamic> m) => UomUnit(
      id: m['id'], name: m['name'], shortName: m['short_name'],
      uomType: m['uom_type'] ?? 'count', createdAt: DateTime.parse(m['created_at']));

  Map<String, dynamic> toMap() => {
    if (id != null) 'id': id, 'name': name, 'short_name': shortName,
    'uom_type': uomType, 'created_at': createdAt.toIso8601String()};

  String get displayName => '$name ($shortName)';
  @override List<Object?> get props => [id, name, shortName];
}

// ─── Customer ─────────────────────────────────────────────────────────────────
class Customer extends Equatable {
  final int? id;
  final String name;
  final String? phone;
  final String? address;
  final String? gstNumber;
  final double creditLimit;
  final double outstandingBalance;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Customer({this.id, required this.name, this.phone, this.address,
    this.gstNumber, this.creditLimit = 0.0, this.outstandingBalance = 0.0,
    this.isActive = true, required this.createdAt, required this.updatedAt});

  factory Customer.fromMap(Map<String, dynamic> m) => Customer(
      id: m['id'], name: m['name'], phone: m['phone'], address: m['address'],
      gstNumber: m['gst_number'],
      creditLimit: (m['credit_limit'] as num?)?.toDouble() ?? 0.0,
      outstandingBalance: (m['outstanding_balance'] as num?)?.toDouble() ?? 0.0,
      isActive: (m['is_active'] as int? ?? 1) == 1,
      createdAt: DateTime.parse(m['created_at']),
      updatedAt: DateTime.parse(m['updated_at']));

  Map<String, dynamic> toMap() => {
    if (id != null) 'id': id, 'name': name, 'phone': phone, 'address': address,
    'gst_number': gstNumber, 'credit_limit': creditLimit,
    'outstanding_balance': outstandingBalance, 'is_active': isActive ? 1 : 0,
    'created_at': createdAt.toIso8601String(), 'updated_at': updatedAt.toIso8601String()};

  Customer copyWith({String? name, String? phone, String? address, String? gstNumber,
    double? creditLimit, double? outstandingBalance, bool? isActive}) =>
      Customer(id: id, name: name ?? this.name, phone: phone ?? this.phone,
          address: address ?? this.address, gstNumber: gstNumber ?? this.gstNumber,
          creditLimit: creditLimit ?? this.creditLimit,
          outstandingBalance: outstandingBalance ?? this.outstandingBalance,
          isActive: isActive ?? this.isActive,
          createdAt: createdAt, updatedAt: DateTime.now());

  @override List<Object?> get props => [id, name, phone];
}

// ─── Supplier ─────────────────────────────────────────────────────────────────
class Supplier extends Equatable {
  final int? id;
  final String name;
  final String? phone;
  final String? address;
  final String? gstNumber;
  final double outstandingBalance;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Supplier({this.id, required this.name, this.phone, this.address,
    this.gstNumber, this.outstandingBalance = 0.0, this.isActive = true,
    required this.createdAt, required this.updatedAt});

  factory Supplier.fromMap(Map<String, dynamic> m) => Supplier(
      id: m['id'], name: m['name'], phone: m['phone'], address: m['address'],
      gstNumber: m['gst_number'],
      outstandingBalance: (m['outstanding_balance'] as num?)?.toDouble() ?? 0.0,
      isActive: (m['is_active'] as int? ?? 1) == 1,
      createdAt: DateTime.parse(m['created_at']),
      updatedAt: DateTime.parse(m['updated_at']));

  Map<String, dynamic> toMap() => {
    if (id != null) 'id': id, 'name': name, 'phone': phone, 'address': address,
    'gst_number': gstNumber, 'outstanding_balance': outstandingBalance,
    'is_active': isActive ? 1 : 0,
    'created_at': createdAt.toIso8601String(), 'updated_at': updatedAt.toIso8601String()};

  @override List<Object?> get props => [id, name, phone];
}

// ─── Masters Repository ────────────────────────────────────────────────────────
abstract class MastersRepository {
  // Brands
  Future<List<Brand>> getAllBrands();
  Future<int> addBrand(String name, {String? description});
  Future<bool> deleteBrand(int id);

  // UOM
  Future<List<UomUnit>> getAllUnits();
  Future<int> addUnit(UomUnit unit);
  Future<bool> deleteUnit(int id);

  // Customers
  Future<List<Customer>> getAllCustomers({String? search});
  Future<Customer?> getCustomerById(int id);
  Future<int> addCustomer(Customer customer);
  Future<bool> updateCustomer(Customer customer);
  Future<bool> deleteCustomer(int id);
  Future<void> addCategory(Category category);
  // Suppliers
  Future<List<Supplier>> getAllSuppliers({String? search});
  Future<Supplier?> getSupplierById(int id);
  Future<int> addSupplier(Supplier supplier);
  Future<bool> updateSupplier(Supplier supplier);
  Future<bool> deleteSupplier(int id);
}

class MastersRepositoryImpl implements MastersRepository {
  final DatabaseHelper _db;
  MastersRepositoryImpl(this._db);

  // ── Brands ─────────────────────────────────────────────────────────────────
  @override Future<List<Brand>> getAllBrands() async {
    final db = await _db.database;
    final rows = await db.query('brands', orderBy: 'name ASC');
    return rows.map((r) => Brand.fromMap(r)).toList();
  }
  @override
  Future<void> addCategory(Category category) async {
    final db = await _db.database;
    await db.insert('categories', category.toMap());
  }
  @override Future<int> addBrand(String name, {String? description}) async {
    final db = await _db.database;
    return await db.insert('brands', {
      'name': name, 'description': description,
      'created_at': DateTime.now().toIso8601String()});
  }

  @override Future<bool> deleteBrand(int id) async {
    final db = await _db.database;
    return (await db.delete('brands', where: 'id=?', whereArgs: [id])) > 0;
  }

  // ── UOM ────────────────────────────────────────────────────────────────────
  @override Future<List<UomUnit>> getAllUnits() async {
    final db = await _db.database;
    final rows = await db.query('uom_units', orderBy: 'name ASC');
    return rows.map((r) => UomUnit.fromMap(r)).toList();
  }

  @override Future<int> addUnit(UomUnit unit) async {
    final db = await _db.database;
    return await db.insert('uom_units', unit.toMap());
  }

  @override Future<bool> deleteUnit(int id) async {
    final db = await _db.database;
    return (await db.delete('uom_units', where: 'id=?', whereArgs: [id])) > 0;
  }

  // ── Customers ──────────────────────────────────────────────────────────────
  @override Future<List<Customer>> getAllCustomers({String? search}) async {
    final db = await _db.database;
    if (search != null && search.isNotEmpty) {
      final rows = await db.query('customers',
          where: 'is_active=1 AND (name LIKE ? OR phone LIKE ?)',
          whereArgs: ['%$search%', '%$search%'], orderBy: 'name ASC');
      return rows.map((r) => Customer.fromMap(r)).toList();
    }
    final rows = await db.query('customers', where: 'is_active=1', orderBy: 'name ASC');
    return rows.map((r) => Customer.fromMap(r)).toList();
  }

  @override Future<Customer?> getCustomerById(int id) async {
    final db = await _db.database;
    final rows = await db.query('customers', where: 'id=?', whereArgs: [id]);
    return rows.isEmpty ? null : Customer.fromMap(rows.first);
  }

  @override Future<int> addCustomer(Customer customer) async {
    final db = await _db.database;
    return await db.insert('customers', customer.toMap());
  }

  @override Future<bool> updateCustomer(Customer customer) async {
    final db = await _db.database;
    return (await db.update('customers', customer.toMap(),
        where: 'id=?', whereArgs: [customer.id])) > 0;
  }

  @override Future<bool> deleteCustomer(int id) async {
    final db = await _db.database;
    return (await db.update('customers', {'is_active': 0},
        where: 'id=?', whereArgs: [id])) > 0;
  }

  // ── Suppliers ──────────────────────────────────────────────────────────────
  @override Future<List<Supplier>> getAllSuppliers({String? search}) async {
    final db = await _db.database;
    if (search != null && search.isNotEmpty) {
      final rows = await db.query('suppliers',
          where: 'is_active=1 AND (name LIKE ? OR phone LIKE ?)',
          whereArgs: ['%$search%', '%$search%'], orderBy: 'name ASC');
      return rows.map((r) => Supplier.fromMap(r)).toList();
    }
    final rows = await db.query('suppliers', where: 'is_active=1', orderBy: 'name ASC');
    return rows.map((r) => Supplier.fromMap(r)).toList();
  }

  @override Future<Supplier?> getSupplierById(int id) async {
    final db = await _db.database;
    final rows = await db.query('suppliers', where: 'id=?', whereArgs: [id]);
    return rows.isEmpty ? null : Supplier.fromMap(rows.first);
  }

  @override Future<int> addSupplier(Supplier supplier) async {
    final db = await _db.database;
    return await db.insert('suppliers', supplier.toMap());
  }

  @override Future<bool> updateSupplier(Supplier supplier) async {
    final db = await _db.database;
    return (await db.update('suppliers', supplier.toMap(),
        where: 'id=?', whereArgs: [supplier.id])) > 0;
  }

  @override Future<bool> deleteSupplier(int id) async {
    final db = await _db.database;
    return (await db.update('suppliers', {'is_active': 0},
        where: 'id=?', whereArgs: [id])) > 0;
  }
}