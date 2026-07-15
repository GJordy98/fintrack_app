import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';

import '../../../data/models/day_budget.dart';
import '../../../data/models/goal.dart';
import '../../../data/models/sync_status.dart';
import '../../../data/models/transaction.dart';
import '../../../data/repositories/category_repository.dart';
import '../../../data/repositories/day_budget_repository.dart';
import '../../../data/repositories/fixed_charge_repository.dart';
import '../../../data/repositories/goal_repository.dart';
import '../../../data/repositories/income_repository.dart';
import '../../../data/repositories/transaction_repository.dart';
import '../../../data/settings_service.dart';
import '../../goals/cubit/goals_cubit.dart';

/// Une cellule du calendrier : le plan et le réel d'un jour.
class DayCell extends Equatable {
  const DayCell({
    required this.date,
    required this.planned,
    required this.reportedActual,
    required this.actualFromTx,
    required this.note,
    required this.settled,
  });

  final DateTime date;
  final int planned;
  final int? reportedActual;
  final int actualFromTx;
  final String? note;
  final bool settled;

  /// Réel effectif : ce que l'utilisateur a déclaré, sinon les transactions.
  int get effectiveActual => reportedActual ?? actualFromTx;

  @override
  List<Object?> get props =>
      [date, planned, reportedActual, actualFromTx, note, settled];
}

/// Résultat du bilan d'une journée (pour le feedback du soir).
class DayVerdict {
  const DayVerdict({
    required this.planned,
    required this.actual,
    required this.suggestedNextDaily,
  });
  final int planned;
  final int actual;
  final int suggestedNextDaily;

  bool get withinBudget => actual <= planned;
  int get delta => actual - planned; // >0 = dépassement
}

class DailyPlanState extends Equatable {
  const DailyPlanState({
    this.loading = true,
    required this.year,
    required this.month,
    this.monthlyIncome = 0,
    this.savingsFromGoals = 0,
    this.savingsFree = 0,
    this.monthlyFixed = 0,
    this.days = const [],
    this.revision = 0,
  });

  final bool loading;
  final int year;
  final int month;
  final int monthlyIncome;

  /// Épargne mensuelle réservée par les objectifs (date cible ou saisie).
  final int savingsFromGoals;

  /// Épargne mensuelle « libre » souhaitée en plus.
  final int savingsFree;

  /// Charges fixes mensuelles (loyer, factures...) réservées d'avance.
  final int monthlyFixed;

  final List<DayCell> days;
  final int revision;

  /// Épargne mensuelle totale mise de côté avant de répartir en dépenses.
  int get monthlySavings => savingsFromGoals + savingsFree;

  int get disposableMonthly => (monthlyIncome - monthlySavings - monthlyFixed)
      .clamp(0, monthlyIncome);

  int get daysInMonth => DateTime(year, month + 1, 0).day;

  int get suggestedDaily =>
      daysInMonth == 0 ? 0 : (disposableMonthly / daysInMonth).floor();

  int get totalPlanned => days.fold(0, (s, d) => s + d.planned);
  int get totalSpent =>
      days.where((d) => d.settled).fold(0, (s, d) => s + d.effectiveActual);

  bool isCurrentMonth({DateTime? now}) {
    final t = now ?? DateTime.now();
    return t.year == year && t.month == month;
  }

  // --- Progression (dépensé réel vs prévu) sur un intervalle de jours ---

  bool _inRange(DateTime d, DateTime start, DateTime end) =>
      !d.isBefore(start) && !d.isAfter(end);

  int plannedInRange(DateTime start, DateTime end) => days
      .where((c) => _inRange(c.date, start, end))
      .fold(0, (s, c) => s + c.planned);

  /// Dépensé réel sur l'intervalle (jusqu'à aujourd'hui inclus).
  int spentInRange(DateTime start, DateTime end, {DateTime? now}) {
    final today = now ?? DateTime.now();
    final cap = DateTime(today.year, today.month, today.day);
    return days
        .where((c) => _inRange(c.date, start, end) && !c.date.isAfter(cap))
        .fold(0, (s, c) => s + c.effectiveActual);
  }

  /// Prévu sur l'intervalle jusqu'à aujourd'hui (pour la notion de « rythme »).
  int plannedToDateInRange(DateTime start, DateTime end, {DateTime? now}) {
    final today = now ?? DateTime.now();
    final cap = DateTime(today.year, today.month, today.day);
    return days
        .where((c) => _inRange(c.date, start, end) && !c.date.isAfter(cap))
        .fold(0, (s, c) => s + c.planned);
  }

  DailyPlanState copyWith({
    bool? loading,
    int? year,
    int? month,
    int? monthlyIncome,
    int? savingsFromGoals,
    int? savingsFree,
    int? monthlyFixed,
    List<DayCell>? days,
    int? revision,
  }) {
    return DailyPlanState(
      loading: loading ?? this.loading,
      year: year ?? this.year,
      month: month ?? this.month,
      monthlyIncome: monthlyIncome ?? this.monthlyIncome,
      savingsFromGoals: savingsFromGoals ?? this.savingsFromGoals,
      savingsFree: savingsFree ?? this.savingsFree,
      monthlyFixed: monthlyFixed ?? this.monthlyFixed,
      days: days ?? this.days,
      revision: revision ?? this.revision,
    );
  }

  @override
  List<Object?> get props => [
        loading,
        year,
        month,
        monthlyIncome,
        savingsFromGoals,
        savingsFree,
        monthlyFixed,
        days,
        revision,
      ];
}

class DailyPlanCubit extends Cubit<DailyPlanState> {
  DailyPlanCubit(
    this._income,
    this._dayBudgets,
    this._goals,
    this._transactions,
    this._settings,
    this._fixed,
    this._categories,
    DateTime month,
  ) : super(DailyPlanState(year: month.year, month: month.month)) {
    _iSub = _income.watch().listen((_) => load());
    _dSub = _dayBudgets.watch().listen((_) => load());
    _tSub = _transactions.watch().listen((_) => load());
    _gSub = _goals.watch().listen((_) => load());
    _fSub = _fixed.watch().listen((_) => load());
    _cSub = _categories.watch().listen((_) => load());
    load();
  }

  final IncomeRepository _income;
  final DayBudgetRepository _dayBudgets;
  final GoalRepository _goals;
  final TransactionRepository _transactions;
  final SettingsService _settings;
  final FixedChargeRepository _fixed;
  final CategoryRepository _categories;
  static const _uuid = Uuid();
  late final StreamSubscription _iSub;
  late final StreamSubscription _dSub;
  late final StreamSubscription _tSub;
  late final StreamSubscription _gSub;
  late final StreamSubscription _fSub;
  late final StreamSubscription _cSub;

  void load() {
    final year = state.year;
    final month = state.month;
    final monthlyIncome = _income.totalMonthlyIncome();
    final savingsFromGoals = _savingsFromGoals();
    final savingsFree = _settings.monthlySavingsTarget;
    final monthlyFixed = _fixed.totalMonthly();
    // Catégories considérées comme charges fixes (exclues du suivi quotidien).
    final fixedCategoryIds = {
      for (final c in _categories.getAll())
        if (c.isFixed) c.id,
    };

    final daysInMonth = DateTime(year, month + 1, 0).day;
    final txs = _transactions.getAll();
    final cells = <DayCell>[];
    for (var day = 1; day <= daysInMonth; day++) {
      final date = DateTime(year, month, day);
      final plan = _dayBudgets.forDay(date);
      cells.add(DayCell(
        date: date,
        planned: plan?.planned ?? 0,
        reportedActual: plan?.actual,
        actualFromTx: _spentOn(date, txs, fixedCategoryIds),
        note: plan?.note,
        settled: plan?.settled ?? false,
      ));
    }

    emit(state.copyWith(
      loading: false,
      monthlyIncome: monthlyIncome,
      savingsFromGoals: savingsFromGoals,
      savingsFree: savingsFree,
      monthlyFixed: monthlyFixed,
      days: cells,
      revision: state.revision + 1,
    ));
  }

  int _savingsFromGoals() {
    var total = 0;
    for (final g in _goals.getAll()) {
      if (g.status != GoalStatus.inProgress) continue;
      total += GoalsCubit.effectiveMonthlySaving(g);
    }
    return total;
  }

  /// Définit l'épargne mensuelle « libre » souhaitée et recalcule le budget.
  Future<void> setMonthlySavingsTarget(int amount) async {
    await _settings.setMonthlySavingsTarget(amount);
    load();
  }

  /// Dépenses réelles d'un jour, HORS charges fixes (factures exclues du suivi
  /// des dépenses quotidiennes).
  int _spentOn(DateTime date, List<AppTransaction> txs, Set<String> fixedCatIds) {
    var total = 0;
    for (final t in txs) {
      if (t.type != TransactionType.expense) continue;
      if (t.categoryId != null && fixedCatIds.contains(t.categoryId)) continue;
      if (t.date.year == date.year &&
          t.date.month == date.month &&
          t.date.day == date.day) {
        total += t.amount;
      }
    }
    return total;
  }

  void setMonth(int year, int month) {
    emit(state.copyWith(year: year, month: month));
    load();
  }

  DayBudget _ensureDay(DateTime date) {
    final existing = _dayBudgets.forDay(date);
    if (existing != null) return existing;
    final now = DateTime.now();
    return DayBudget(
      id: _uuid.v4(),
      date: DateTime(date.year, date.month, date.day),
      updatedAt: now,
    );
  }

  Future<void> setPlanned(DateTime date, int planned, {String? note}) async {
    final d = _ensureDay(date)
      ..planned = planned
      ..note = note
      ..updatedAt = DateTime.now()
      ..syncStatus = SyncStatus.dirty;
    await _dayBudgets.save(d);
  }

  /// Remplit tous les jours non encore validés avec l'allocation suggérée.
  Future<void> autoFill() async {
    final suggested = state.suggestedDaily;
    for (final cell in state.days) {
      if (cell.settled) continue;
      final d = _ensureDay(cell.date)
        ..planned = suggested
        ..updatedAt = DateTime.now()
        ..syncStatus = SyncStatus.dirty;
      await _dayBudgets.save(d);
    }
  }

  /// Bilan du soir : enregistre le réel dépensé et renvoie un verdict.
  Future<DayVerdict> reportActual(DateTime date, int actual) async {
    final d = _ensureDay(date)
      ..actual = actual
      ..settled = true
      ..updatedAt = DateTime.now()
      ..syncStatus = SyncStatus.dirty;
    await _dayBudgets.save(d);

    return DayVerdict(
      planned: d.planned,
      actual: actual,
      suggestedNextDaily: _suggestedForRemaining(date),
    );
  }

  /// Recalcule l'allocation pour les jours restants du mois afin de tenir
  /// l'enveloppe disponible malgré les écarts déjà constatés.
  int _suggestedForRemaining(DateTime after) {
    final disposable = state.disposableMonthly;
    var spentSoFar = 0;
    var remainingDays = 0;
    for (final cell in state.days) {
      final isSettledOrBefore =
          cell.settled || !cell.date.isAfter(after);
      if (isSettledOrBefore) {
        spentSoFar += cell.settled ? cell.effectiveActual : 0;
      }
      if (cell.date.isAfter(after) && !cell.settled) {
        remainingDays++;
      }
    }
    if (remainingDays <= 0) return 0;
    final remaining = (disposable - spentSoFar).clamp(0, disposable);
    return (remaining / remainingDays).floor();
  }

  @override
  Future<void> close() {
    _iSub.cancel();
    _dSub.cancel();
    _tSub.cancel();
    _gSub.cancel();
    _fSub.cancel();
    _cSub.cancel();
    return super.close();
  }
}
