import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import '../../data/repositories/sales_repository_impl.dart';

// Events
abstract class SalesEvent extends Equatable {
  @override List<Object?> get props => [];
}
class LoadSalesData extends SalesEvent {}
class LoadSalesByDate extends SalesEvent {
  final DateTime date;
  LoadSalesByDate(this.date);
  @override List<Object?> get props => [date];
}

// States
abstract class SalesState extends Equatable {
  @override List<Object?> get props => [];
}
class SalesInitial extends SalesState {}
class SalesLoading extends SalesState {}
class SalesLoaded extends SalesState {
  final double todaySales;
  final double todayProfit;
  final int todayBillCount;
  final double monthlySales;
  final double monthlyProfit;
  final int monthlyBillCount;
  final List<Map<String, double>> weeklyData;
  final double profitMargin;

  SalesLoaded({
    required this.todaySales,
    required this.todayProfit,
    required this.todayBillCount,
    required this.monthlySales,
    required this.monthlyProfit,
    required this.monthlyBillCount,
    required this.weeklyData,
    required this.profitMargin,
  });

  @override
  List<Object?> get props => [todaySales, todayProfit, monthlySales, monthlyProfit];
}

class SalesByDateLoaded extends SalesState {
  final DateTime date;
  final List<Map<String, dynamic>> bills;
  final double totalSales;
  final double totalProfit;
  final int billCount;

  SalesByDateLoaded({
    required this.date,
    required this.bills,
    required this.totalSales,
    required this.totalProfit,
    required this.billCount,
  });

  @override
  List<Object?> get props => [date, bills, totalSales, totalProfit, billCount];
}
class SalesError extends SalesState {
  final String message;
  SalesError(this.message);
  @override List<Object?> get props => [message];
}

// BLoC
class SalesBloc extends Bloc<SalesEvent, SalesState> {
  final SalesRepository _repository;

  SalesBloc(this._repository) : super(SalesInitial()) {
    on<LoadSalesData>(_onLoadSalesData);
    on<LoadSalesByDate>(_onLoadSalesByDate);
  }

  Future<void> _onLoadSalesData(LoadSalesData event, Emitter<SalesState> emit) async {
    emit(SalesLoading());
    try {
      final today = DateTime.now();
      final todaySummary = await _repository.getDailySummary(today);
      final monthlySummary = await _repository.getMonthlySummary(today.year, today.month);
      final weeklyData = await _repository.getLast7DaysSales();

      final todaySales = todaySummary['sales'] ?? 0.0;
      final todayProfit = todaySummary['profit'] ?? 0.0;
      final profitMargin = todaySales > 0 ? (todayProfit / todaySales) * 100 : 0.0;

      emit(SalesLoaded(
        todaySales: todaySales,
        todayProfit: todayProfit,
        todayBillCount: (todaySummary['billCount'] ?? 0.0).toInt(),
        monthlySales: monthlySummary['sales'] ?? 0.0,
        monthlyProfit: monthlySummary['profit'] ?? 0.0,
        monthlyBillCount: (monthlySummary['billCount'] ?? 0.0).toInt(),
        weeklyData: weeklyData,
        profitMargin: profitMargin,
      ));
    } catch (e) {
      emit(SalesError(e.toString()));
    }
  }

  Future<void> _onLoadSalesByDate(LoadSalesByDate event, Emitter<SalesState> emit) async {
    emit(SalesLoading());
    try {
      final summary = await _repository.getDailySummary(event.date);
      final bills = await _repository.getDailyReport(event.date);
      emit(SalesByDateLoaded(
        date: event.date,
        bills: bills,
        totalSales: summary['sales'] ?? 0.0,
        totalProfit: summary['profit'] ?? 0.0,
        billCount: (summary['billCount'] ?? 0.0).toInt(),
      ));
    } catch (e) {
      emit(SalesError(e.toString()));
    }
  }
}
