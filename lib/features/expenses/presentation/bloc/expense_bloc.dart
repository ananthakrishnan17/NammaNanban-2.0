// ─── Expense Entity ────────────────────────────────────────────────────────────
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import '../../../../core/database/database_helper.dart';
import '../../../../core/ledger/ledger_service.dart';


  final int? id;
  final String category;
  final String? description;
  final double amount;
  final DateTime date;
  final DateTime createdAt;
  final bool isRawMaterial;

  const Expense({
    this.id,
    required this.category,
    this.description,
    required this.amount,
    required this.date,
    required this.createdAt,
    this.isRawMaterial = false,
  });

  factory Expense.fromMap(Map<String, dynamic> map) => Expense(
    id: map['id'] as int?,
    category: map['category'] as String,
    description: map['description'] as String?,
    amount: (map['amount'] as num).toDouble(),
    date: DateTime.parse(map['date'] as String),
    createdAt: DateTime.parse(map['created_at'] as String),
    isRawMaterial: (map['is_raw_material'] as int? ?? 0) == 1,
  );

  Map<String, dynamic> toMap() => {
    if (id != null) 'id': id,
    'category': category,
    'description': description,
    'amount': amount,
    'date': date.toIso8601String(),
    'created_at': createdAt.toIso8601String(),
    'is_raw_material': isRawMaterial ? 1 : 0,
  };

  @override
  List<Object?> get props => [id, category, amount, date, isRawMaterial];
}

const List<String> kExpenseCategories = [
  'Rent', 'Electricity', 'Water', 'Raw Materials',
  'Salary', 'Maintenance', 'Transport', 'Packaging', 'Other',
];

// ─── Repository ────────────────────────────────────────────────────────────────
abstract class ExpenseRepository {
  Future<List<Expense>> getExpensesByDate(DateTime date);
  Future<List<Expense>> getExpensesByMonth(int year, int month);
  Future<int> addExpense(Expense expense);
  Future<bool> deleteExpense(int id);
  Future<Map<String, double>> getDailyExpenseSummary(DateTime date);
  Future<Map<String, double>> getMonthlyExpenseSummary(int year, int month);
  Future<double> getTodayRawMaterialExpenses(DateTime date);
}

class ExpenseRepositoryImpl implements ExpenseRepository {
  final DatabaseHelper _dbHelper;
  ExpenseRepositoryImpl(this._dbHelper);

  @override
  Future<List<Expense>> getExpensesByDate(DateTime date) async {
    final db = await _dbHelper.database;
    final dateStr = date.toIso8601String().substring(0, 10);
    final rows = await db.query(
      'expenses',
      where: "date LIKE ?",
      whereArgs: ['$dateStr%'],
      orderBy: 'created_at DESC',
    );
    return rows.map((r) => Expense.fromMap(r)).toList();
  }

  @override
  Future<List<Expense>> getExpensesByMonth(int year, int month) async {
    final db = await _dbHelper.database;
    final prefix = '$year-${month.toString().padLeft(2, '0')}';
    final rows = await db.query(
      'expenses',
      where: "date LIKE ?",
      whereArgs: ['$prefix%'],
      orderBy: 'date DESC',
    );
    return rows.map((r) => Expense.fromMap(r)).toList();
  }

  @override
  Future<int> addExpense(Expense expense) async {
    final db = await _dbHelper.database;
    final expenseId = await db.insert('expenses', expense.toMap());

    // ── Double-entry ledger ──────────────────────────────────────────────
    // Expense journal:
    //   DR Expense   amount
    //   CR Asset     amount (cash/bank paid out)
    try {
      final ledger = LedgerService.instance;
      final licenseId = await ledger.getLicenseId();
      final nowStr = expense.createdAt.toIso8601String();
      await ledger.recordTransaction(
        executor: db,
        type: 'expense',
        totalAmount: expense.amount,
        tags: {
          'expense_id': expenseId,
          'category': expense.category,
          'description': expense.description,
          'is_raw_material': expense.isRawMaterial,
        },
        licenseId: licenseId,
        createdAt: nowStr,
        entries: [
          LedgerEntryInput(accountType: 'expense', direction: 'debit', amount: expense.amount),
          LedgerEntryInput(accountType: 'asset', direction: 'credit', amount: expense.amount),
        ],
      );
    } catch (_) {
      rethrow;
    }

    return expenseId;
  }

  @override
  Future<bool> deleteExpense(int id) async {
    final db = await _dbHelper.database;
    final count = await db.delete('expenses', where: 'id = ?', whereArgs: [id]);
    return count > 0;
  }

  @override
  Future<Map<String, double>> getDailyExpenseSummary(DateTime date) async {
    final db = await _dbHelper.database;
    final dateStr = date.toIso8601String().substring(0, 10);
    final result = await db.rawQuery('''
      SELECT COALESCE(SUM(amount), 0.0) as total FROM expenses WHERE date LIKE ?
    ''', ['$dateStr%']);
    return {'total': (result.first['total'] as num).toDouble()};
  }

  @override
  Future<Map<String, double>> getMonthlyExpenseSummary(int year, int month) async {
    final db = await _dbHelper.database;
    final prefix = '$year-${month.toString().padLeft(2, '0')}';
    final result = await db.rawQuery('''
      SELECT COALESCE(SUM(amount), 0.0) as total,
             category, COUNT(*) as count
      FROM expenses WHERE date LIKE ?
      GROUP BY category
    ''', ['$prefix%']);
    final map = <String, double>{};
    for (final r in result) {
      map[r['category'] as String] = (r['total'] as num).toDouble();
    }
    return map;
  }

  @override
  Future<double> getTodayRawMaterialExpenses(DateTime date) async {
    final db = await _dbHelper.database;
    final dateStr = date.toIso8601String().substring(0, 10);
    final result = await db.rawQuery('''
      SELECT COALESCE(SUM(amount), 0.0) as total FROM expenses
      WHERE date LIKE ? AND is_raw_material = 1
    ''', ['$dateStr%']);
    return (result.first['total'] as num).toDouble();
  }
}

// ─── Events ────────────────────────────────────────────────────────────────────
abstract class ExpenseEvent extends Equatable {
  @override List<Object?> get props => [];
}
class LoadExpenses extends ExpenseEvent {}
class AddExpenseEvent extends ExpenseEvent {
  final Expense expense;
  AddExpenseEvent(this.expense);
  @override List<Object?> get props => [expense];
}
class DeleteExpenseEvent extends ExpenseEvent {
  final int id;
  DeleteExpenseEvent(this.id);
  @override List<Object?> get props => [id];
}

// ─── States ────────────────────────────────────────────────────────────────────
abstract class ExpenseState extends Equatable {
  @override List<Object?> get props => [];
}
class ExpenseInitial extends ExpenseState {}
class ExpenseLoading extends ExpenseState {}
class ExpenseLoaded extends ExpenseState {
  final List<Expense> todayExpenses;
  final List<Expense> monthlyExpenses;
  final double todayTotal;
  final double monthlyTotal;
  final Map<String, double> categoryBreakdown;

  ExpenseLoaded({
    required this.todayExpenses,
    required this.monthlyExpenses,
    required this.todayTotal,
    required this.monthlyTotal,
    required this.categoryBreakdown,
  });

  @override List<Object?> get props => [todayExpenses, monthlyExpenses];
}
class ExpenseError extends ExpenseState {
  final String message;
  ExpenseError(this.message);
  @override List<Object?> get props => [message];
}

// ─── BLoC ──────────────────────────────────────────────────────────────────────
class ExpenseBloc extends Bloc<ExpenseEvent, ExpenseState> {
  final ExpenseRepository _repository;

  ExpenseBloc(this._repository) : super(ExpenseInitial()) {
    on<LoadExpenses>(_onLoad);
    on<AddExpenseEvent>(_onAdd);
    on<DeleteExpenseEvent>(_onDelete);
  }

  Future<void> _onLoad(LoadExpenses event, Emitter<ExpenseState> emit) async {
    emit(ExpenseLoading());
    try {
      final now = DateTime.now();
      final todayExpenses = await _repository.getExpensesByDate(now);
      final monthlyExpenses = await _repository.getExpensesByMonth(now.year, now.month);
      final categoryBreakdown = await _repository.getMonthlyExpenseSummary(now.year, now.month);
      final todayTotal = todayExpenses.fold(0.0, (sum, e) => sum + e.amount);
      final monthlyTotal = monthlyExpenses.fold(0.0, (sum, e) => sum + e.amount);

      emit(ExpenseLoaded(
        todayExpenses: todayExpenses,
        monthlyExpenses: monthlyExpenses,
        todayTotal: todayTotal,
        monthlyTotal: monthlyTotal,
        categoryBreakdown: categoryBreakdown,
      ));
    } catch (e) {
      emit(ExpenseError(e.toString()));
    }
  }

  Future<void> _onAdd(AddExpenseEvent event, Emitter<ExpenseState> emit) async {
    try {
      await _repository.addExpense(event.expense);
      add(LoadExpenses());
    } catch (e) {
      emit(ExpenseError(e.toString()));
    }
  }

  Future<void> _onDelete(DeleteExpenseEvent event, Emitter<ExpenseState> emit) async {
    try {
      await _repository.deleteExpense(event.id);
      add(LoadExpenses());
    } catch (e) {
      emit(ExpenseError(e.toString()));
    }
  }
}
