import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

import 'hive_config.dart';
import 'models/account.dart';
import 'models/budget.dart';
import 'models/category.dart';
import 'models/contribution.dart';
import 'models/contribution_event.dart';
import 'models/day_budget.dart';
import 'models/debt.dart';
import 'models/debt_repayment.dart';
import 'models/goal.dart';
import 'models/income_profile.dart';
import 'models/recurring_rule.dart';
import 'models/transaction.dart';
import 'seed/default_account.dart';
import 'settings_service.dart';

/// Migration v2 : passage des montants en **centimes** (×100).
///
/// Auparavant les montants étaient stockés en unités entières (FCFA). Pour
/// gérer les décimales et les devises EUR/USD, tout est désormais en centimes.
/// On multiplie une seule fois les données existantes par 100.
Future<void> runMoneyMigrationV2(SettingsService settings) async {
  if (settings.moneyMigratedV2) return;

  final accounts = Hive.box<Account>(HiveBoxes.accounts);
  for (final a in accounts.values) {
    a.initialBalance *= 100;
    await a.save();
  }

  final txs = Hive.box<AppTransaction>(HiveBoxes.transactions);
  for (final t in txs.values) {
    t.amount *= 100;
    await t.save();
  }

  final rules = Hive.box<RecurringRule>(HiveBoxes.recurringRules);
  for (final r in rules.values) {
    r.amount *= 100;
    await r.save();
  }

  final budgets = Hive.box<Budget>(HiveBoxes.budgets);
  for (final b in budgets.values) {
    b.allocated *= 100;
    await b.save();
  }

  final goals = Hive.box<Goal>(HiveBoxes.goals);
  for (final g in goals.values) {
    g.targetAmount *= 100;
    g.currentAmount *= 100;
    g.monthlyContribution *= 100;
    await g.save();
  }

  final contributions = Hive.box<Contribution>(HiveBoxes.contributions);
  for (final c in contributions.values) {
    c.contributionAmount *= 100;
    c.expectedPayoutAmount *= 100;
    await c.save();
  }

  final events = Hive.box<ContributionEvent>(HiveBoxes.contributionEvents);
  for (final e in events.values) {
    e.amount *= 100;
    await e.save();
  }

  final debts = Hive.box<Debt>(HiveBoxes.debts);
  for (final d in debts.values) {
    d.principal *= 100;
    await d.save();
  }

  final repayments = Hive.box<DebtRepayment>(HiveBoxes.debtRepayments);
  for (final r in repayments.values) {
    r.amount *= 100;
    await r.save();
  }

  final dayBudgets = Hive.box<DayBudget>(HiveBoxes.dayBudgets);
  for (final d in dayBudgets.values) {
    d.planned *= 100;
    if (d.actual != null) d.actual = d.actual! * 100;
    await d.save();
  }

  final incomes = Hive.box<IncomeProfile>(HiveBoxes.incomeProfiles);
  for (final i in incomes.values) {
    i.amount *= 100;
    await i.save();
  }

  // Réglage épargne mensuelle (stocké dans la boîte de préférences).
  await settings.setMonthlySavingsTarget(settings.monthlySavingsTarget * 100);

  await settings.setMoneyMigratedV2(true);
}

/// Marque les catégories par défaut « Logement » et « Factures » comme charges
/// fixes sur les installations existantes (une seule fois).
Future<void> runFixedCategoriesMigration(SettingsService settings) async {
  if (settings.fixedCategoriesMigrated) return;
  const fixedNames = {'Logement', 'Factures'};
  final categories = Hive.box<Category>(HiveBoxes.categories);
  for (final c in categories.values) {
    if (!c.isCustom && fixedNames.contains(c.name) && !c.isFixed) {
      c.isFixed = true;
      await c.save();
    }
  }
  await settings.setFixedCategoriesMigrated(true);
}

/// Ajoute les comptes prédéfinis manquants (Orange Money, MTN MoMo, banque...)
/// aux installations existantes, sans dupliquer ceux déjà présents (par nom).
Future<void> runDefaultAccountsMigration(SettingsService settings) async {
  if (settings.defaultAccountsMigrated) return;
  final box = Hive.box<Account>(HiveBoxes.accounts);
  // Ne rien faire si aucun compte (le seed s'en charge au 1er lancement).
  if (box.isNotEmpty) {
    final existingNames = box.values.map((a) => a.name.toLowerCase()).toSet();
    const uuid = Uuid();
    final now = DateTime.now();
    for (final def in kDefaultAccounts) {
      if (existingNames.contains(def.name.toLowerCase())) continue;
      final a = Account(
        id: uuid.v4(),
        name: def.name,
        type: def.type,
        provider: def.provider,
        initialBalance: 0,
        createdAt: now,
        updatedAt: now,
      );
      await box.put(a.id, a);
    }
  }
  await settings.setDefaultAccountsMigrated(true);
}
