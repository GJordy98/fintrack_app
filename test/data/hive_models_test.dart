import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:fintrack_app/data/hive_config.dart';
import 'package:fintrack_app/data/models/account.dart';
import 'package:fintrack_app/data/models/category.dart';
import 'package:fintrack_app/data/models/contribution_event.dart';
import 'package:fintrack_app/data/models/debt.dart';
import 'package:fintrack_app/data/models/goal.dart';
import 'package:fintrack_app/data/models/sync_status.dart';
import 'package:fintrack_app/data/models/transaction.dart';
import 'package:fintrack_app/data/repositories/account_repository.dart';
import 'package:fintrack_app/data/repositories/category_repository.dart';
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

  group('Round-trip des adaptateurs Hive', () {
    test('Account survit à un write/read via l\'adaptateur', () async {
      final box = Hive.box<Account>(HiveBoxes.accounts);
      final now = DateTime(2026, 1, 15);
      await box.put(
        'a1',
        Account(
          id: 'a1',
          name: 'Mobile Money',
          type: AccountType.mobileMoney,
          initialBalance: 25000,
          createdAt: now,
          updatedAt: now,
        ),
      );

      final read = box.get('a1')!;
      expect(read.name, 'Mobile Money');
      expect(read.type, AccountType.mobileMoney);
      expect(read.initialBalance, 25000);
      expect(read.currencyCode, 'XAF');
      expect(read.syncStatus, SyncStatus.dirty);
    });

    test('Enums (Debt, ContributionEvent) round-trip correctement', () async {
      final debtBox = Hive.box<Debt>(HiveBoxes.debts);
      final now = DateTime(2026, 2, 1);
      await debtBox.put(
        'd1',
        Debt(
          id: 'd1',
          direction: DebtDirection.iOwe,
          counterparty: 'Jean',
          principal: 50000,
          contractedDate: now,
          createdAt: now,
          updatedAt: now,
        ),
      );
      expect(debtBox.get('d1')!.direction, DebtDirection.iOwe);

      final evt = ContributionEvent(
        id: 'e1',
        contributionId: 'c1',
        date: now,
        kind: ContributionEventKind.receive,
        amount: 100000,
        updatedAt: now,
      );
      expect(evt.signedAmount, 100000);
      expect(
        ContributionEvent(
          id: 'e2',
          contributionId: 'c1',
          date: now,
          kind: ContributionEventKind.contribute,
          amount: 10000,
          updatedAt: now,
        ).signedAmount,
        -10000,
      );
    });
  });

  group('Repositories CRUD', () {
    test('CategoryRepository filtre par nature', () async {
      final repo =
          CategoryRepository(Hive.box<Category>(HiveBoxes.categories));
      final now = DateTime(2026, 1, 1);
      await repo.save(Category(
        id: 'c1',
        name: 'Salaire',
        kind: CategoryKind.income,
        iconCodePoint: 1,
        colorValue: 1,
        updatedAt: now,
      ));
      await repo.save(Category(
        id: 'c2',
        name: 'Transport',
        kind: CategoryKind.expense,
        iconCodePoint: 2,
        colorValue: 2,
        updatedAt: now,
      ));

      expect(repo.count, 2);
      expect(repo.byKind(CategoryKind.income).single.name, 'Salaire');
      expect(repo.byKind(CategoryKind.expense).single.name, 'Transport');

      await repo.delete('c2');
      expect(repo.count, 1);
    });

    test('AccountRepository calcule le solde courant et consolidé', () async {
      final accounts =
          AccountRepository(Hive.box<Account>(HiveBoxes.accounts));
      final txRepo =
          TransactionRepository(Hive.box<AppTransaction>(HiveBoxes.transactions));
      final now = DateTime(2026, 3, 1);

      final cash = Account(
        id: 'cash',
        name: 'Espèces',
        type: AccountType.cash,
        initialBalance: 10000,
        createdAt: now,
        updatedAt: now,
      );
      await accounts.save(cash);

      await txRepo.save(AppTransaction(
        id: 't1',
        amount: 5000,
        type: TransactionType.income,
        accountId: 'cash',
        date: now,
        createdAt: now,
        updatedAt: now,
      ));
      await txRepo.save(AppTransaction(
        id: 't2',
        amount: 3000,
        type: TransactionType.expense,
        accountId: 'cash',
        date: now,
        createdAt: now,
        updatedAt: now,
      ));

      final all = txRepo.getAll();
      expect(accounts.currentBalance(cash, all), 12000); // 10000 +5000 -3000
      expect(accounts.consolidatedBalance(all), 12000);
    });

    test('Goal calcule progression et reste', () {
      final now = DateTime(2026, 1, 1);
      final goal = Goal(
        id: 'g1',
        name: 'Vélo',
        targetAmount: 200000,
        currentAmount: 50000,
        createdAt: now,
        updatedAt: now,
      );
      expect(goal.remaining, 150000);
      expect(goal.progress, closeTo(0.25, 0.0001));
    });
  });
}
