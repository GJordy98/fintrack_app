import 'package:flutter_test/flutter_test.dart';

import 'package:fintrack_app/data/models/goal.dart';
import 'package:fintrack_app/features/goals/cubit/goals_cubit.dart';

void main() {
  // Régression : après un versement, l'objet Hive est muté EN PLACE. Le
  // GoalView doit tout de même être considéré comme différent (snapshot), sinon
  // l'UI ne se rafraîchit pas (bug « Verser n'incrémente pas »).
  test('GoalView reflète une mutation en place de currentAmount', () {
    final now = DateTime(2026, 1, 1);
    final goal = Goal(
      id: 'g1',
      name: 'Vélo',
      targetAmount: 100000,
      currentAmount: 0,
      createdAt: now,
      updatedAt: now,
    );
    final before = GoalView(goal: goal, monthlyNeeded: 0);

    goal.currentAmount += 5000; // mutation en place (comme contribute())
    final after = GoalView(goal: goal, monthlyNeeded: 0);

    expect(before == after, isFalse,
        reason: 'Le snapshot doit capturer l\'ancien montant');
  });
}
