import 'package:get_it/get_it.dart';
import 'package:hive/hive.dart';

import '../../data/hive_config.dart';
import '../../data/models/account.dart';
import '../../data/models/budget.dart';
import '../../data/models/category.dart';
import '../../data/models/contribution.dart';
import '../../data/models/contribution_event.dart';
import '../../data/models/day_budget.dart';
import '../../data/models/debt.dart';
import '../../data/models/debt_repayment.dart';
import '../../data/models/fixed_charge.dart';
import '../../data/models/goal.dart';
import '../../data/models/goal_status_history.dart';
import '../../data/models/income_profile.dart';
import '../../data/models/recurring_rule.dart';
import '../../data/models/transaction.dart';
import '../../data/repositories/account_repository.dart';
import '../../data/repositories/budget_repository.dart';
import '../../data/repositories/category_repository.dart';
import '../../data/repositories/contribution_repository.dart';
import '../../data/repositories/day_budget_repository.dart';
import '../../data/repositories/debt_repository.dart';
import '../../data/repositories/fixed_charge_repository.dart';
import '../../data/repositories/goal_repository.dart';
import '../../data/repositories/income_repository.dart';
import '../../data/repositories/recurring_rule_repository.dart';
import '../../data/repositories/transaction_repository.dart';
import '../../data/recurring_generator.dart';
import '../../data/seed/default_account.dart';
import '../../data/seed/default_categories.dart';
import '../../data/settings_service.dart';
import '../../data/sync/sync_service.dart';
import '../logging/remote_log_uploader.dart';
import '../money/currency_cubit.dart';
import '../premium/premium_cubit.dart';
import '../premium/premium_service.dart';
import '../notifications/notification_scheduler.dart';
import '../notifications/notification_service.dart';
import '../security/security_service.dart';
import '../../features/lock/cubit/app_lock_cubit.dart';
import '../../features/accounts/cubit/accounts_cubit.dart';
import '../../features/budget/cubit/budgets_cubit.dart';
import '../../features/categories/cubit/categories_cubit.dart';
import '../../features/contributions/cubit/contributions_cubit.dart';
import '../../features/debts/cubit/debts_cubit.dart';
import '../../features/forecast/forecast_service.dart';
import '../../features/goals/cubit/goals_cubit.dart';
import '../../features/planning/cubit/daily_plan_cubit.dart';
import '../../features/planning/cubit/fixed_charges_cubit.dart';
import '../../features/planning/cubit/income_cubit.dart';
import '../../features/recurring/cubit/recurring_rules_cubit.dart';
import '../../features/stats/cubit/stats_cubit.dart';
import '../../features/stats/export_service.dart';
import '../../features/transactions/cubit/transactions_cubit.dart';
import '../../features/auth/auth_repository.dart';
import '../../features/auth/cubit/auth_cubit.dart';
import '../theme/theme_cubit.dart';

/// Conteneur d'injection de dépendances (get_it).
final GetIt sl = GetIt.instance;

/// À appeler APRÈS l'ouverture des boîtes Hive.
Future<void> setupServiceLocator() async {
  // --- Coeur ---
  sl.registerLazySingleton<ThemeCubit>(() => ThemeCubit());
  sl.registerLazySingleton<AuthRepository>(() => AuthRepository());
  sl.registerLazySingleton<AuthCubit>(() => AuthCubit(sl<AuthRepository>()));
  sl.registerLazySingleton<NotificationService>(() => NotificationService());
  sl.registerLazySingleton<SettingsService>(
    () => SettingsService(Hive.box(HiveBoxes.settings)),
  );
  sl.registerLazySingleton<CurrencyCubit>(
    () => CurrencyCubit(sl<SettingsService>()),
  );
  sl.registerLazySingleton<SecurityService>(
    () => SecurityService(sl<SettingsService>()),
  );
  sl.registerLazySingleton<SyncService>(
    () => SyncService(sl<SettingsService>()),
  );
  sl.registerLazySingleton<PremiumService>(
    () => PremiumService(sl<SettingsService>()),
  );

  // Remontée des erreurs/avertissements au serveur (visibles seulement par les
  // admins). On l'enregistre ici ; le branchement au journal et le premier
  // envoi sont faits depuis main.dart (hors chemin des tests, sans réseau).
  sl.registerLazySingleton<RemoteLogUploader>(
    () => RemoteLogUploader(
      sl<SettingsService>(),
      Hive.box(HiveBoxes.pendingLogs),
    ),
  );
  sl.registerLazySingleton<AppLockCubit>(
    () => AppLockCubit(sl<SecurityService>()),
  );

  // --- Repositories locaux ---
  sl.registerLazySingleton<AccountRepository>(
    () => AccountRepository(Hive.box<Account>(HiveBoxes.accounts)),
  );
  sl.registerLazySingleton<CategoryRepository>(
    () => CategoryRepository(Hive.box<Category>(HiveBoxes.categories)),
  );
  sl.registerLazySingleton<TransactionRepository>(
    () => TransactionRepository(
      Hive.box<AppTransaction>(HiveBoxes.transactions),
    ),
  );
  sl.registerLazySingleton<BudgetRepository>(
    () => BudgetRepository(Hive.box<Budget>(HiveBoxes.budgets)),
  );
  sl.registerLazySingleton<GoalRepository>(
    () => GoalRepository(
      Hive.box<Goal>(HiveBoxes.goals),
      Hive.box<GoalStatusHistory>(HiveBoxes.goalStatusHistory),
    ),
  );
  sl.registerLazySingleton<ContributionRepository>(
    () => ContributionRepository(
      Hive.box<Contribution>(HiveBoxes.contributions),
      Hive.box<ContributionEvent>(HiveBoxes.contributionEvents),
    ),
  );
  sl.registerLazySingleton<DebtRepository>(
    () => DebtRepository(
      Hive.box<Debt>(HiveBoxes.debts),
      Hive.box<DebtRepayment>(HiveBoxes.debtRepayments),
    ),
  );
  sl.registerLazySingleton<IncomeRepository>(
    () => IncomeRepository(Hive.box<IncomeProfile>(HiveBoxes.incomeProfiles)),
  );
  sl.registerLazySingleton<DayBudgetRepository>(
    () => DayBudgetRepository(Hive.box<DayBudget>(HiveBoxes.dayBudgets)),
  );
  sl.registerLazySingleton<FixedChargeRepository>(
    () => FixedChargeRepository(Hive.box<FixedCharge>(HiveBoxes.fixedCharges)),
  );
  sl.registerLazySingleton<RecurringRuleRepository>(
    () => RecurringRuleRepository(
        Hive.box<RecurringRule>(HiveBoxes.recurringRules)),
  );
  sl.registerLazySingleton<RecurringGenerator>(
    () => RecurringGenerator(
        sl<RecurringRuleRepository>(), sl<TransactionRepository>()),
  );

  // Données de départ au premier lancement.
  await DefaultCategoriesSeeder(sl<CategoryRepository>()).seedIfEmpty();
  await DefaultAccountSeeder(sl<AccountRepository>()).seedIfEmpty();

  // --- Cubits partagés (Phase 2) ---
  sl.registerLazySingleton<AccountsCubit>(
    () => AccountsCubit(sl<AccountRepository>(), sl<TransactionRepository>()),
  );
  sl.registerLazySingleton<TransactionsCubit>(
    () => TransactionsCubit(sl<TransactionRepository>()),
  );
  sl.registerLazySingleton<BudgetsCubit>(
    () => BudgetsCubit(
      sl<BudgetRepository>(),
      sl<TransactionRepository>(),
      sl<CategoryRepository>(),
      BudgetsCubit.monthKey(DateTime.now()),
      notifications: sl<NotificationService>(),
    ),
  );
  sl.registerLazySingleton<GoalsCubit>(
    () => GoalsCubit(sl<GoalRepository>()),
  );
  sl.registerLazySingleton<IncomeCubit>(
    () => IncomeCubit(sl<IncomeRepository>()),
  );
  sl.registerLazySingleton<DailyPlanCubit>(
    () => DailyPlanCubit(
      sl<IncomeRepository>(),
      sl<DayBudgetRepository>(),
      sl<GoalRepository>(),
      sl<TransactionRepository>(),
      sl<SettingsService>(),
      sl<FixedChargeRepository>(),
      sl<CategoryRepository>(),
      DateTime.now(),
    ),
  );
  sl.registerLazySingleton<FixedChargesCubit>(
    () => FixedChargesCubit(
      sl<FixedChargeRepository>(),
      sl<CategoryRepository>(),
    ),
  );
  sl.registerLazySingleton<RecurringRulesCubit>(
    () => RecurringRulesCubit(sl<RecurringRuleRepository>()),
  );
  sl.registerLazySingleton<PremiumCubit>(
    () => PremiumCubit(sl<PremiumService>()),
  );
  sl.registerLazySingleton<CategoriesCubit>(
    () => CategoriesCubit(sl<CategoryRepository>()),
  );
  sl.registerLazySingleton<StatsCubit>(
    () => StatsCubit(
      sl<TransactionRepository>(),
      sl<CategoryRepository>(),
      DateTime.now(),
    ),
  );
  sl.registerLazySingleton<ExportService>(
    () => ExportService(sl<CategoryRepository>(), sl<AccountRepository>()),
  );
  sl.registerLazySingleton<ContributionsCubit>(
    () => ContributionsCubit(
      sl<ContributionRepository>(),
      sl<TransactionRepository>(),
    ),
  );
  sl.registerLazySingleton<DebtsCubit>(
    () => DebtsCubit(
      sl<DebtRepository>(),
      sl<TransactionRepository>(),
      sl<AccountRepository>(),
    ),
  );

  // --- Notifications (Phase 4) ---
  sl.registerLazySingleton<NotificationScheduler>(
    () => NotificationScheduler(
      sl<NotificationService>(),
      sl<ContributionRepository>(),
      sl<DebtRepository>(),
      sl<GoalRepository>(),
      sl<SettingsService>(),
    ),
  );

  // --- Prévisions (Phase 3) : service pur assemblant les entrées locales ---
  sl.registerLazySingleton<ForecastService>(
    () => ForecastService(
      sl<AccountRepository>(),
      sl<TransactionRepository>(),
      () => Hive.box<ContributionEvent>(HiveBoxes.contributionEvents)
          .values
          .toList(),
      () => Hive.box<DebtRepayment>(HiveBoxes.debtRepayments).values.toList(),
      () => Hive.box<Debt>(HiveBoxes.debts).values.toList(),
    ),
  );
}
