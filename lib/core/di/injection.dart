import 'package:get_it/get_it.dart';

import '../../data/datasources/local/app_database.dart';
import '../../data/datasources/local/hive_cache_datasource.dart';
import '../../data/datasources/local/local_expense_datasource.dart';
import '../../data/datasources/remote/gemini_datasource.dart';
import '../../data/repositories/expense_repository_impl.dart';
import '../../domain/repositories/expense_repository.dart';
import '../../domain/usecases/expense_usecases.dart';
import '../../presentation/blocs/expense/expense_bloc.dart';
import '../../presentation/blocs/settings/settings_cubit.dart';
import '../network/dio_client.dart';

final sl = GetIt.instance;

Future<void> configureDependencies() async {
  // ── External ───────────────────────────────────────────────────────────────
  sl.registerSingleton(DioClient.createDio());

  // ── Database ───────────────────────────────────────────────────────────────
  final db = AppDatabase();
  sl.registerSingleton(db);

  // ── Data Sources ───────────────────────────────────────────────────────────
  sl.registerSingleton<LocalExpenseDataSource>(
    LocalExpenseDataSourceImpl(db),
  );

  final cacheDs = HiveCacheDataSourceImpl();
  await cacheDs.init();
  sl.registerSingleton<CacheDataSource>(cacheDs);

  sl.registerLazySingleton<RemoteAiDataSource>(
        () => GeminiDataSourceImpl(sl()),
  );

  // ── Repository ─────────────────────────────────────────────────────────────
  sl.registerLazySingleton<ExpenseRepository>(
        () => ExpenseRepositoryImpl(sl(), sl(), sl()),
  );

  // ── Use Cases: CRUD ────────────────────────────────────────────────────────
  sl.registerLazySingleton(() => GetAllExpensesUseCase(sl()));
  sl.registerLazySingleton(() => SaveExpenseUseCase(sl()));
  sl.registerLazySingleton(() => UpdateExpenseUseCase(sl()));
  sl.registerLazySingleton(() => DeleteExpenseUseCase(sl()));
  sl.registerLazySingleton(() => GetExpenseSummaryUseCase(sl()));

  // ── Use Cases: AI เดิม ─────────────────────────────────────────────────────
  sl.registerLazySingleton(() => CategorizeWithAiUseCase(sl()));
  sl.registerLazySingleton(() => SummarizeWithAiUseCase(sl()));

  // ── Use Cases: AI ใหม่ ─────────────────────────────────────────────────────
  sl.registerLazySingleton(() => ExtractReceiptDataUseCase(sl()));
  sl.registerLazySingleton(() => AnalyzeSpendingPatternUseCase(sl()));
  sl.registerLazySingleton(() => GenerateBudgetAdviceUseCase(sl()));
  sl.registerLazySingleton(() => DetectAnomaliesUseCase(sl()));

  // ── BLoCs ──────────────────────────────────────────────────────────────────
  sl.registerFactory(
        () => ExpenseBloc(
      getAllExpenses: sl(),
      saveExpense: sl(),
      updateExpense: sl(),
      deleteExpense: sl(),
      getSummary: sl(),
      categorizeWithAi: sl(),
      summarizeWithAi: sl(),
      extractReceiptData: sl(),
      analyzeSpending: sl(),
      generateBudget: sl(),
      detectAnomalies: sl(),
    ),
  );

  sl.registerLazySingleton(() => SettingsCubit());
}