import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:fintrack_app/core/utils/recurrence.dart';
import 'package:fintrack_app/data/hive_config.dart';
import 'package:fintrack_app/data/models/contribution.dart';
import 'package:fintrack_app/data/models/contribution_event.dart';
import 'package:fintrack_app/data/models/debt.dart';
import 'package:fintrack_app/data/models/debt_repayment.dart';
import 'package:fintrack_app/data/models/recurring_rule.dart';
import 'package:fintrack_app/data/repositories/contribution_repository.dart';
import 'package:fintrack_app/data/repositories/debt_repository.dart';

import '../support/hive_test_setup.dart';

void main() {
  group('generateOccurrences', () {
    test('génère N dates mensuelles espacées d\'un mois', () {
      final dates = generateOccurrences(
        start: DateTime(2026, 1, 15),
        freq: RecurrenceFrequency.monthly,
        maxOccurrences: 3,
      );
      expect(dates.length, 3);
      expect(dates[0], DateTime(2026, 1, 15));
      expect(dates[1], DateTime(2026, 2, 15));
      expect(dates[2], DateTime(2026, 3, 15));
    });

    test('s\'arrête à la date de fin', () {
      final dates = generateOccurrences(
        start: DateTime(2026, 1, 1),
        freq: RecurrenceFrequency.weekly,
        end: DateTime(2026, 1, 20),
        maxOccurrences: 100,
      );
      // 1, 8, 15 (22 dépasse le 20)
      expect(dates.length, 3);
    });
  });

  group('Repositories Phase 3bis', () {
    late Directory dir;
    setUp(() async {
      dir = await initHiveForTest();
    });
    tearDown(() async {
      await tearDownHiveForTest(dir);
    });

    test('ContributionRepository.netBalance = perçu(done) − cotisé(done)', () async {
      final repo = ContributionRepository(
        Hive.box<Contribution>(HiveBoxes.contributions),
        Hive.box<ContributionEvent>(HiveBoxes.contributionEvents),
      );
      final now = DateTime(2026, 1, 1);
      await repo.saveEvents([
        ContributionEvent(
          id: 'e1',
          contributionId: 'c1',
          date: now,
          kind: ContributionEventKind.contribute,
          amount: 10000,
          status: EventStatus.done,
          updatedAt: now,
        ),
        ContributionEvent(
          id: 'e2',
          contributionId: 'c1',
          date: now,
          kind: ContributionEventKind.receive,
          amount: 50000,
          status: EventStatus.done,
          updatedAt: now,
        ),
        ContributionEvent(
          id: 'e3',
          contributionId: 'c1',
          date: now,
          kind: ContributionEventKind.contribute,
          amount: 10000,
          status: EventStatus.upcoming, // ignoré (pas encore fait)
          updatedAt: now,
        ),
      ]);
      expect(repo.netBalance('c1'), 40000); // 50000 - 10000
    });

    test('DebtRepository.remaining = principal − remboursements payés', () async {
      final repo = DebtRepository(
        Hive.box<Debt>(HiveBoxes.debts),
        Hive.box<DebtRepayment>(HiveBoxes.debtRepayments),
      );
      final now = DateTime(2026, 1, 1);
      final debt = Debt(
        id: 'd1',
        direction: DebtDirection.iOwe,
        counterparty: 'Paul',
        principal: 100000,
        contractedDate: now,
        createdAt: now,
        updatedAt: now,
      );
      await repo.save(debt);
      await repo.saveRepayment(DebtRepayment(
        id: 'r1',
        debtId: 'd1',
        dueDate: now,
        amount: 30000,
        status: RepaymentStatus.paid,
        updatedAt: now,
      ));
      await repo.saveRepayment(DebtRepayment(
        id: 'r2',
        debtId: 'd1',
        dueDate: now,
        amount: 20000,
        status: RepaymentStatus.planned, // pas encore payé
        updatedAt: now,
      ));
      expect(repo.paidTotal('d1'), 30000);
      expect(repo.remaining(debt), 70000);
    });
  });
}
