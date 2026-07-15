import 'package:hive_flutter/hive_flutter.dart';

import 'hive_config.dart';
import 'models/account.dart';
import 'models/budget.dart';
import 'models/category.dart';
import 'models/contribution.dart';
import 'models/contribution_event.dart';
import 'models/day_budget.dart';
import 'models/debt.dart';
import 'models/debt_repayment.dart';
import 'models/fixed_charge.dart';
import 'models/goal.dart';
import 'models/income_profile.dart';
import 'models/goal_status_history.dart';
import 'models/recurring_rule.dart';
import 'models/sync_status.dart';
import 'models/transaction.dart';

/// Enregistre tous les adaptateurs Hive et ouvre les boîtes.
/// À appeler une seule fois au démarrage (après `Hive.initFlutter()`).
class HiveRegistrar {
  HiveRegistrar._();

  static void registerAdapters() {
    // Enums
    _register(SyncStatusAdapter());
    _register(AccountTypeAdapter());
    _register(CategoryKindAdapter());
    _register(TransactionTypeAdapter());
    _register(RecurrenceFrequencyAdapter());
    _register(GoalStatusAdapter());
    _register(ContributionEventKindAdapter());
    _register(EventStatusAdapter());
    _register(DebtDirectionAdapter());
    _register(DebtStatusAdapter());
    _register(RepaymentStatusAdapter());

    // Modèles
    _register(AccountAdapter());
    _register(CategoryAdapter());
    _register(AppTransactionAdapter());
    _register(RecurringRuleAdapter());
    _register(BudgetAdapter());
    _register(GoalAdapter());
    _register(GoalStatusHistoryAdapter());
    _register(ContributionAdapter());
    _register(ContributionEventAdapter());
    _register(DebtAdapter());
    _register(DebtRepaymentAdapter());
    _register(IncomeProfileAdapter());
    _register(DayBudgetAdapter());
    _register(FixedChargeAdapter());
  }

  static Future<void> openBoxes() async {
    await Future.wait([
      Hive.openBox<Account>(HiveBoxes.accounts),
      Hive.openBox<Category>(HiveBoxes.categories),
      Hive.openBox<AppTransaction>(HiveBoxes.transactions),
      Hive.openBox<RecurringRule>(HiveBoxes.recurringRules),
      Hive.openBox<Budget>(HiveBoxes.budgets),
      Hive.openBox<Goal>(HiveBoxes.goals),
      Hive.openBox<GoalStatusHistory>(HiveBoxes.goalStatusHistory),
      Hive.openBox<Contribution>(HiveBoxes.contributions),
      Hive.openBox<ContributionEvent>(HiveBoxes.contributionEvents),
      Hive.openBox<Debt>(HiveBoxes.debts),
      Hive.openBox<DebtRepayment>(HiveBoxes.debtRepayments),
      Hive.openBox<IncomeProfile>(HiveBoxes.incomeProfiles),
      Hive.openBox<DayBudget>(HiveBoxes.dayBudgets),
      Hive.openBox<FixedCharge>(HiveBoxes.fixedCharges),
      Hive.openBox(HiveBoxes.settings),
      Hive.openBox(HiveBoxes.pendingLogs),
    ]);
  }

  static void _register<T>(TypeAdapter<T> adapter) {
    if (!Hive.isAdapterRegistered(adapter.typeId)) {
      Hive.registerAdapter(adapter);
    }
  }
}
