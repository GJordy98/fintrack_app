import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';

import '../../../data/models/goal.dart';
import '../../../data/models/goal_status_history.dart';
import '../../../data/models/sync_status.dart';
import '../../../data/repositories/goal_repository.dart';

/// Un objectif enrichi de sa trajectoire calculée.
///
/// IMPORTANT : on fige des instantanés (snapshots) des valeurs mutables dans
/// les `props`. Les objets Hive sont modifiés en place ; si l'égalité lisait
/// `goal.currentAmount` en direct, l'ancien et le nouvel état pointeraient vers
/// le même objet muté et paraîtraient identiques (pas de rebuild).
class GoalView extends Equatable {
  GoalView({required this.goal, required this.monthlyNeeded})
      : _current = goal.currentAmount,
        _target = goal.targetAmount,
        _status = goal.status.index;

  final Goal goal;

  /// Montant à épargner chaque mois pour tenir la date cible (0 si pas de date
  /// ou objectif déjà atteint).
  final int monthlyNeeded;

  final int _current;
  final int _target;
  final int _status;

  @override
  List<Object?> get props =>
      [goal.id, _current, _target, _status, monthlyNeeded];
}

class GoalsState extends Equatable {
  const GoalsState({this.loading = true, this.goals = const []});

  final bool loading;
  final List<GoalView> goals;

  @override
  List<Object?> get props => [loading, goals];
}

class GoalsCubit extends Cubit<GoalsState> {
  GoalsCubit(this._repo) : super(const GoalsState()) {
    _sub = _repo.watch().listen((_) => _reload());
    evaluateDueGoals();
    _reload();
  }

  final GoalRepository _repo;
  static const _uuid = Uuid();
  late final StreamSubscription _sub;

  /// Nombre de mois (au moins 1) entre aujourd'hui et une date cible future.
  static int monthsUntil(DateTime target, {DateTime? from}) {
    final now = from ?? DateTime.now();
    var months =
        (target.year - now.year) * 12 + (target.month - now.month);
    if (target.day > now.day) months += 1; // arrondi au mois entamé
    return months < 1 ? 1 : months;
  }

  /// Épargne mensuelle effective réservée pour un objectif : le versement
  /// calculé s'il a une date cible, sinon l'épargne mensuelle saisie.
  static int effectiveMonthlySaving(Goal g, {DateTime? from}) {
    if (g.targetDate != null) return computeMonthlyNeeded(g, from: from);
    return g.monthlyContribution;
  }

  static int computeMonthlyNeeded(Goal g, {DateTime? from}) {
    if (g.targetDate == null) return 0;
    final remaining = g.remaining;
    if (remaining <= 0) return 0;
    final months = monthsUntil(g.targetDate!, from: from);
    return (remaining / months).ceil();
  }

  void _reload() {
    final views = _repo.getAll().map((g) {
      return GoalView(goal: g, monthlyNeeded: computeMonthlyNeeded(g));
    }).toList()
      ..sort((a, b) {
        // En cours d'abord (par priorité), puis atteints, puis manqués.
        final byStatus = a.goal.status.index.compareTo(b.goal.status.index);
        if (byStatus != 0) return byStatus;
        return a.goal.priority.compareTo(b.goal.priority);
      });
    emit(GoalsState(loading: false, goals: views));
  }

  Future<void> addGoal({
    required String name,
    required int targetAmount,
    DateTime? targetDate,
    int initialAmount = 0,
    int monthlyContribution = 0,
    int? colorValue,
    int? iconCodePoint,
  }) async {
    final now = DateTime.now();
    await _repo.save(Goal(
      id: _uuid.v4(),
      name: name.trim(),
      targetAmount: targetAmount,
      currentAmount: initialAmount,
      targetDate: targetDate,
      monthlyContribution: monthlyContribution,
      colorValue: colorValue,
      iconCodePoint: iconCodePoint,
      createdAt: now,
      updatedAt: now,
      syncStatus: SyncStatus.dirty,
    ));
  }

  Future<void> updateGoal(Goal goal) async {
    goal
      ..updatedAt = DateTime.now()
      ..syncStatus = SyncStatus.dirty;
    await _repo.save(goal);
  }

  Future<void> deleteGoal(String id) => _repo.delete(id);

  /// Évalue les objectifs dont la date cible est passée sans être atteints :
  /// les marque « manqués » et historise le changement (déclenche le feedback
  /// animé, module 3.6). Idempotent.
  Future<void> evaluateDueGoals({DateTime? now}) async {
    final today = now ?? DateTime.now();
    for (final g in _repo.getAll()) {
      if (g.status != GoalStatus.inProgress) continue;
      if (g.targetDate == null) continue;
      if (g.targetDate!.isAfter(today)) continue;
      if (g.currentAmount >= g.targetAmount) continue; // atteint -> géré ailleurs
      g.status = GoalStatus.missed;
      await _repo.addStatusHistory(GoalStatusHistory(
        id: _uuid.v4(),
        goalId: g.id,
        status: GoalStatus.missed,
        date: today,
        amountAtEvaluation: g.currentAmount,
      ));
      await updateGoal(g);
    }
  }

  /// Verse [amount] dans l'enveloppe virtuelle de l'objectif.
  /// Détecte l'atteinte et historise le changement de statut (pour le feedback
  /// animé de la Phase 5).
  Future<void> contribute(Goal goal, int amount) async {
    if (amount <= 0) return;
    goal.currentAmount += amount;
    final justReached = goal.status != GoalStatus.reached &&
        goal.currentAmount >= goal.targetAmount;
    if (justReached) {
      goal.status = GoalStatus.reached;
      await _repo.addStatusHistory(GoalStatusHistory(
        id: _uuid.v4(),
        goalId: goal.id,
        status: GoalStatus.reached,
        date: DateTime.now(),
        amountAtEvaluation: goal.currentAmount,
      ));
    }
    await updateGoal(goal);
  }

  /// Retire [amount] de l'enveloppe (correction / retrait).
  Future<void> withdraw(Goal goal, int amount) async {
    if (amount <= 0) return;
    goal.currentAmount = (goal.currentAmount - amount).clamp(0, goal.currentAmount);
    if (goal.currentAmount < goal.targetAmount &&
        goal.status == GoalStatus.reached) {
      goal.status = GoalStatus.inProgress;
    }
    await updateGoal(goal);
  }

  @override
  Future<void> close() {
    _sub.cancel();
    return super.close();
  }
}
