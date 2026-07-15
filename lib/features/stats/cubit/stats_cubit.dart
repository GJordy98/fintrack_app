import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../data/models/category.dart';
import '../../../data/models/transaction.dart';
import '../../../data/repositories/category_repository.dart';
import '../../../data/repositories/transaction_repository.dart';

/// Part d'une catégorie dans les dépenses.
class CategorySlice extends Equatable {
  const CategorySlice({
    required this.category,
    required this.amount,
    required this.ratio,
  });

  final Category? category;
  final int amount; // centimes
  final double ratio; // 0..1

  @override
  List<Object?> get props => [category?.id, amount, ratio];
}

/// Point mensuel : revenus et dépenses d'un mois.
class MonthPoint extends Equatable {
  const MonthPoint({
    required this.year,
    required this.month,
    required this.income,
    required this.expense,
  });

  final int year;
  final int month;
  final int income;
  final int expense;

  int get net => income - expense;

  @override
  List<Object?> get props => [year, month, income, expense];
}

class StatsState extends Equatable {
  const StatsState({
    this.loading = true,
    required this.year,
    required this.month,
    this.income = 0,
    this.expense = 0,
    this.breakdown = const [],
    this.series = const [],
    this.revision = 0,
  });

  final bool loading;
  final int year;
  final int month;
  final int income;
  final int expense;
  final List<CategorySlice> breakdown;
  final List<MonthPoint> series; // 6 derniers mois
  final int revision;

  int get net => income - expense;

  /// Taux d'épargne = (revenus - dépenses) / revenus, borné à [0,1] pour l'affichage.
  double get savingsRate =>
      income <= 0 ? 0 : ((income - expense) / income).clamp(-1.0, 1.0);

  StatsState copyWith({
    bool? loading,
    int? year,
    int? month,
    int? income,
    int? expense,
    List<CategorySlice>? breakdown,
    List<MonthPoint>? series,
    int? revision,
  }) {
    return StatsState(
      loading: loading ?? this.loading,
      year: year ?? this.year,
      month: month ?? this.month,
      income: income ?? this.income,
      expense: expense ?? this.expense,
      breakdown: breakdown ?? this.breakdown,
      series: series ?? this.series,
      revision: revision ?? this.revision,
    );
  }

  @override
  List<Object?> get props =>
      [loading, year, month, income, expense, breakdown, series, revision];
}

class StatsCubit extends Cubit<StatsState> {
  StatsCubit(this._transactions, this._categories, DateTime month)
      : super(StatsState(year: month.year, month: month.month)) {
    _sub = _transactions.watch().listen((_) => load());
    load();
  }

  final TransactionRepository _transactions;
  final CategoryRepository _categories;
  late final StreamSubscription _sub;

  static bool _inMonth(DateTime d, int year, int month) =>
      d.year == year && d.month == month;

  void load() {
    final year = state.year;
    final month = state.month;
    final txs = _transactions.getAll();

    var income = 0;
    var expense = 0;
    final byCategory = <String?, int>{};
    for (final t in txs) {
      if (!_inMonth(t.date, year, month)) continue;
      if (t.type == TransactionType.income) {
        income += t.amount;
      } else {
        expense += t.amount;
        byCategory[t.categoryId] = (byCategory[t.categoryId] ?? 0) + t.amount;
      }
    }

    final breakdown = byCategory.entries.map((e) {
      return CategorySlice(
        category: e.key == null ? null : _categories.getById(e.key!),
        amount: e.value,
        ratio: expense <= 0 ? 0 : e.value / expense,
      );
    }).toList()
      ..sort((a, b) => b.amount.compareTo(a.amount));

    // Historique des 6 derniers mois (incluant le mois courant).
    final series = <MonthPoint>[];
    for (var i = 5; i >= 0; i--) {
      final d = DateTime(year, month - i);
      var inc = 0;
      var exp = 0;
      for (final t in txs) {
        if (!_inMonth(t.date, d.year, d.month)) continue;
        if (t.type == TransactionType.income) {
          inc += t.amount;
        } else {
          exp += t.amount;
        }
      }
      series.add(MonthPoint(year: d.year, month: d.month, income: inc, expense: exp));
    }

    emit(state.copyWith(
      loading: false,
      income: income,
      expense: expense,
      breakdown: breakdown,
      series: series,
      revision: state.revision + 1,
    ));
  }

  void setMonth(int year, int month) {
    emit(state.copyWith(year: year, month: month));
    load();
  }

  /// Transactions du mois courant (pour l'export).
  List<AppTransaction> transactionsForMonth() {
    final list = _transactions
        .getAll()
        .where((t) => _inMonth(t.date, state.year, state.month))
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    return list;
  }

  @override
  Future<void> close() {
    _sub.cancel();
    return super.close();
  }
}
