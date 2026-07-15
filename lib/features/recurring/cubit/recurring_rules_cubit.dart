import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';

import '../../../data/models/recurring_rule.dart';
import '../../../data/models/sync_status.dart';
import '../../../data/models/transaction.dart';
import '../../../data/repositories/recurring_rule_repository.dart';

class RecurringRulesState extends Equatable {
  const RecurringRulesState({
    this.loading = true,
    this.rules = const [],
    this.revision = 0,
  });

  final bool loading;
  final List<RecurringRule> rules;
  final int revision;

  @override
  List<Object?> get props => [loading, rules, revision];
}

class RecurringRulesCubit extends Cubit<RecurringRulesState> {
  RecurringRulesCubit(this._repo) : super(const RecurringRulesState()) {
    _sub = _repo.watch().listen((_) => _reload());
    _reload();
  }

  final RecurringRuleRepository _repo;
  static const _uuid = Uuid();
  late final StreamSubscription _sub;

  void _reload() {
    emit(RecurringRulesState(
      loading: false,
      rules: _repo.getAllSorted(),
      revision: state.revision + 1,
    ));
  }

  Future<void> addRule({
    required String label,
    required int amount,
    required TransactionType type,
    required String accountId,
    String? categoryId,
    required RecurrenceFrequency frequency,
    int interval = 1,
    required DateTime startDate,
    DateTime? endDate,
  }) async {
    final now = DateTime.now();
    await _repo.save(RecurringRule(
      id: _uuid.v4(),
      label: label.trim(),
      amount: amount,
      type: type,
      accountId: accountId,
      categoryId: categoryId,
      frequency: frequency,
      interval: interval,
      startDate: startDate,
      nextRun: startDate,
      endDate: endDate,
      updatedAt: now,
      syncStatus: SyncStatus.dirty,
    ));
  }

  Future<void> updateRule(RecurringRule rule) async {
    rule
      ..updatedAt = DateTime.now()
      ..syncStatus = SyncStatus.dirty;
    await _repo.save(rule);
  }

  Future<void> toggleActive(RecurringRule rule, bool active) async {
    rule.active = active;
    await updateRule(rule);
  }

  Future<void> deleteRule(String id) => _repo.delete(id);

  @override
  Future<void> close() {
    _sub.cancel();
    return super.close();
  }
}
