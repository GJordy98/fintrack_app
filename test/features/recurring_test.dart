import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:fintrack_app/data/hive_config.dart';
import 'package:fintrack_app/data/models/recurring_rule.dart';
import 'package:fintrack_app/data/models/transaction.dart';
import 'package:fintrack_app/data/recurring_generator.dart';
import 'package:fintrack_app/data/repositories/recurring_rule_repository.dart';
import 'package:fintrack_app/data/repositories/transaction_repository.dart';

import '../support/hive_test_setup.dart';

void main() {
  late Directory dir;
  setUp(() async {
    dir = await initHiveForTest();
  });
  tearDown(() async {
    await tearDownHiveForTest(dir);
  });

  test('RecurringGenerator rattrape les échéances mensuelles passées', () async {
    final rules =
        RecurringRuleRepository(Hive.box<RecurringRule>(HiveBoxes.recurringRules));
    final txRepo =
        TransactionRepository(Hive.box<AppTransaction>(HiveBoxes.transactions));
    final now = DateTime(2026, 4, 15);
    final start = DateTime(2026, 1, 15); // 3 mois avant + le mois courant

    await rules.save(RecurringRule(
      id: 'r1',
      label: 'Salaire',
      amount: 150000,
      type: TransactionType.income,
      accountId: 'a1',
      frequency: RecurrenceFrequency.monthly,
      startDate: start,
      nextRun: start,
      updatedAt: start,
    ));

    final generator = RecurringGenerator(rules, txRepo);
    final created = await generator.generateDue(now: now);

    // 15 janv, 15 fév, 15 mars, 15 avr = 4 occurrences
    expect(created, 4);
    expect(txRepo.count, 4);
    // nextRun avance au 15 mai (futur).
    expect(rules.getById('r1')!.nextRun, DateTime(2026, 5, 15));

    // Relancer ne crée aucun doublon.
    final again = await generator.generateDue(now: now);
    expect(again, 0);
    expect(txRepo.count, 4);
  });
}
