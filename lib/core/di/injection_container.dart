import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:get_it/get_it.dart';
import '../../features/users/domain/entities/app_user.dart';
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
import '../../features/license/data/repositories/license_repository_impl.dart';
import '../../features/license/domain/repositories/license_repository.dart';
import '../../features/license/domain/usecases/activate_license.dart';
import '../../features/license/domain/usecases/check_license_status.dart';
import '../../features/license/domain/usecases/verify_license.dart';
import '../../features/license/presentation/bloc/license_bloc.dart';
import '../network/network_info.dart';
import '../sync/connectivity_service.dart';
import '../sync/sync_service.dart';

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
  sl.registerLazySingleton<UserRepository>(() => UserRepository(sl()));

  // License
  sl.registerLazySingleton<LicenseRepository>(() => LicenseRepositoryImpl());
  sl.registerLazySingleton(() => ActivateLicense(sl()));
  sl.registerLazySingleton(() => VerifyLicense(sl()));
  sl.registerLazySingleton(() => CheckLicenseStatus(sl()));

  // Network
  sl.registerLazySingleton(() => Connectivity());
  sl.registerLazySingleton<NetworkInfo>(() => NetworkInfoImpl(sl()));

  // BLoCs
  sl.registerFactory(() => ProductBloc(sl()));
  sl.registerFactory(() => BillingBloc(sl()));
  sl.registerFactory(() => SalesBloc(sl()));
  sl.registerFactory(() => ExpenseBloc(sl()));
  sl.registerFactory(() => MastersBloc(sl()));
  sl.registerFactory(() => PurchaseBloc(sl()));
  sl.registerFactory(() => HeldBillBloc(sl()));
  sl.registerFactory(() => UserBloc(sl()));
  sl.registerFactory(() => LicenseBloc(
        checkLicenseStatus: sl(),
        verifyLicense: sl(),
        activateLicense: sl(),
        repository: sl(),
      ));

  // Sync — init connectivity and wire sync service
  await ConnectivityService.instance.init();
  SyncService.instance.init(sl<LicenseRepository>());
}