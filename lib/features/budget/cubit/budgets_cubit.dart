import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';

import '../../../core/notifications/notification_service.dart';
import '../../../core/utils/money_formatter.dart';
import '../../../data/models/budget.dart';
import '../../../data/models/category.dart';
import '../../../data/models/sync_status.dart';
import '../../../data/repositories/budget_repository.dart';
import '../../../data/repositories/category_repository.dart';
import '../../../data/repositories/transaction_repository.dart';

/// Une enveloppe budgétaire avec sa consommation calculée.
class BudgetView extends Equatable {
  const BudgetView({
    required this.budget,
    required this.category,
    required this.spent,
  });

  final Budget budget;
  final Category? category;
  final int spent;

  int get allocated => budget.allocated;
  int get remaining => allocated - spent;
  double get ratio =>
      allocated <= 0 ? 0 : (spent / allocated).clamp(0.0, 1.0);
  bool get isOver => spent > allocated;
  bool get isWarning =>
      !isOver && allocated > 0 && spent / allocated >= budget.alertThresholdPercent / 100;

  @override
  List<Object?> get props => [budget.id, spent, allocated, category?.id];
}

class BudgetsState extends Equatable {
  const BudgetsState({
    this.loading = true,
    required this.month,
    this.budgets = const [],
  });

  final bool loading;
  final String month; // 'YYYY-MM'
  final List<BudgetView> budgets;

  int get totalAllocated =>
      budgets.fold(0, (s, b) => s + b.allocated);
  int get totalSpent => budgets.fold(0, (s, b) => s + b.spent);

  BudgetsState copyWith({
    bool? loading,
    String? month,
    List<BudgetView>? budgets,
  }) {
    return BudgetsState(
      loading: loading ?? this.loading,
      month: month ?? this.month,
      budgets: budgets ?? this.budgets,
    );
  }

  @override
  List<Object?> get props => [loading, month, budgets];
}

class BudgetsCubit extends Cubit<BudgetsState> {
  BudgetsCubit(
    this._budgets,
    this._transactions,
    this._categories,
    String month, {
    NotificationService? notifications,
  })  : _notifications = notifications,
        super(BudgetsState(month: month)) {
    _bSub = _budgets.watch().listen((_) => load());
    _tSub = _transactions.watch().listen((_) => load());
    load();
  }

  final BudgetRepository _budgets;
  final TransactionRepository _transactions;
  final CategoryRepository _categories;
  final NotificationService? _notifications;
  static const _uuid = Uuid();
  late final StreamSubscription _bSub;
  late final StreamSubscription _tSub;

  /// Enveloppes déjà signalées comme dépassées (évite les alertes répétées).
  final Set<String> _alertedOver = {};
  bool _firstLoad = true;

  static String monthKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}';

  void load() {
    final month = state.month;
    final views = _budgets.forMonth(month).map((b) {
      final spent = _transactions.spentForCategoryInMonth(b.categoryId, month);
      return BudgetView(
        budget: b,
        category: _categories.getById(b.categoryId),
        spent: spent,
      );
    }).toList()
      ..sort((a, b) => b.ratio.compareTo(a.ratio));
    emit(state.copyWith(loading: false, budgets: views));
    _checkOverspend(views);
  }

  /// Émet une notification quand une enveloppe passe en dépassement.
  void _checkOverspend(List<BudgetView> views) {
    final nowOver = views.where((v) => v.isOver).map((v) => v.budget.id).toSet();
    if (!_firstLoad) {
      for (final v in views) {
        if (v.isOver && !_alertedOver.contains(v.budget.id)) {
          _notifications?.showNow(
            id: 500000 + (v.budget.id.hashCode & 0x7ffff),
            title: 'Budget dépassé — ${v.category?.name ?? 'Catégorie'}',
            body:
                'Tu as dépassé ton enveloppe de ${MoneyFormatter.format(-v.remaining)}.',
          );
        }
      }
    }
    _alertedOver
      ..clear()
      ..addAll(nowOver);
    _firstLoad = false;
  }

  void setMonth(String month) {
    emit(state.copyWith(month: month));
    load();
  }

  Future<void> upsertBudget({
    String? id,
    required String categoryId,
    required int allocated,
    bool rollover = false,
    int alertThresholdPercent = 80,
  }) async {
    final now = DateTime.now();
    await _budgets.save(Budget(
      id: id ?? _uuid.v4(),
      categoryId: categoryId,
      month: state.month,
      allocated: allocated,
      rollover: rollover,
      alertThresholdPercent: alertThresholdPercent,
      updatedAt: now,
      syncStatus: SyncStatus.dirty,
    ));
  }

  Future<void> deleteBudget(String id) => _budgets.delete(id);

  @override
  Future<void> close() {
    _bSub.cancel();
    _tSub.cancel();
    return super.close();
  }
}
