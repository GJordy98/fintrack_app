import 'package:flutter_test/flutter_test.dart';

import 'package:fintrack_app/features/forecast/forecast_engine.dart';
import 'package:fintrack_app/features/goals/cubit/goals_cubit.dart';
import 'package:fintrack_app/data/models/goal.dart';

void main() {
  final from = DateTime(2026, 1, 1);

  group('ForecastEngine.project', () {
    test('projette un flux mensuel constant', () {
      final points = ForecastEngine.project(
        startBalance: 100000,
        netMonthly: 20000,
        months: 3,
        from: from,
      );
      expect(points.length, 4); // point 0 + 3 mois
      expect(points.first.balance, 100000);
      expect(points[1].balance, 120000);
      expect(points[3].balance, 160000);
    });

    test('intègre les flux ponctuels datés (ex : perception de tontine)', () {
      final points = ForecastEngine.project(
        startBalance: 0,
        netMonthly: 0,
        months: 3,
        from: from,
        scheduled: [
          ScheduledFlow(date: DateTime(2026, 2, 15), amount: 50000),
        ],
      );
      // Le flux du 15 février tombe à l'offset mois 1 (janv -> fév).
      expect(points[1].balance, 50000);
      expect(points.last.balance, 50000);
    });
  });

  group('ForecastEngine.canAfford (simulateur d\'achat)', () {
    test('achat déjà possible', () {
      final r = ForecastEngine.canAfford(
        startBalance: 200000,
        price: 150000,
        netMonthly: 10000,
        from: from,
      );
      expect(r.reachable, true);
      expect(r.months, 0);
    });

    test('achat atteignable dans le futur', () {
      final r = ForecastEngine.canAfford(
        startBalance: 0,
        price: 100000,
        netMonthly: 25000,
        from: from,
      );
      expect(r.reachable, true);
      expect(r.months, 4); // 4 * 25000 = 100000
    });

    test('achat impossible si le flux net est nul ou négatif', () {
      final r = ForecastEngine.canAfford(
        startBalance: 10000,
        price: 100000,
        netMonthly: 0,
        from: from,
      );
      expect(r.reachable, false);
    });
  });

  group('GoalsCubit.computeMonthlyNeeded', () {
    test('calcule le versement mensuel pour tenir la date', () {
      final goal = Goal(
        id: 'g1',
        name: 'PC',
        targetAmount: 300000,
        currentAmount: 60000,
        targetDate: DateTime(2026, 7, 1), // 6 mois plus tard
        createdAt: from,
        updatedAt: from,
      );
      final needed = GoalsCubit.computeMonthlyNeeded(goal, from: from);
      // reste 240000 sur 6 mois = 40000 / mois
      expect(needed, 40000);
    });

    test('retourne 0 sans date cible', () {
      final goal = Goal(
        id: 'g2',
        name: 'Libre',
        targetAmount: 100000,
        createdAt: from,
        updatedAt: from,
      );
      expect(GoalsCubit.computeMonthlyNeeded(goal, from: from), 0);
    });
  });
}
