import 'package:get_it/get_it.dart';
import '../database/database_helper.dart';
import '../../features/billing/data/repositories/billing_repository_impl.dart';
import '../../features/billing/presentation/bloc/billing_bloc.dart';
import '../../features/expenses/presentation/bloc/expense_bloc.dart';
import '../../features/masters/domain/entities/masters.dart';
import '../../features/masters/presentation/bloc/masters_bloc.dart';
import '../../features/products/data/repositories/product_repository_impl.dart';
import '../../features/products/presentation/bloc/product_bloc.dart';
import '../../features/purchase/domain/entities/purchase.dart';
import '../../features/sales/data/repositories/sales_repository_impl.dart';
import '../../features/sales/presentation/bloc/sales_bloc.dart';
import '../../features/billing/presentation/pages/held_bills_page.dart';

final sl = GetIt.instance;

Future<void> init() async {
  // Database
  sl.registerLazySingleton(() => DatabaseHelper.instance);

  // Repositories
  sl.registerLazySingleton<ProductRepository>(() => ProductRepositoryImpl(sl()));
  sl.registerLazySingleton<BillingRepository>(() => BillingRepositoryImpl(sl()));
  sl.registerLazySingleton<SalesRepository>(() => SalesRepositoryImpl(sl()));
  sl.registerLazySingleton<ExpenseRepository>(() => ExpenseRepositoryImpl(sl()));
  sl.registerLazySingleton<MastersRepository>(() => MastersRepositoryImpl(sl()));
  sl.registerLazySingleton(() => PurchaseRepository(sl()));
  sl.registerLazySingleton(() => HeldBillRepository(sl()));

  // BLoCs
  sl.registerFactory(() => ProductBloc(sl()));
  sl.registerFactory(() => BillingBloc(sl()));
  sl.registerFactory(() => SalesBloc(sl()));
  sl.registerFactory(() => ExpenseBloc(sl()));
  sl.registerFactory(() => MastersBloc(sl()));
  sl.registerFactory(() => PurchaseBloc(sl()));
  sl.registerFactory(() => HeldBillBloc(sl()));
}