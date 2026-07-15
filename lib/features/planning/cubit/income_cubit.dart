import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';

import '../../../data/models/income_profile.dart';
import '../../../data/models/recurring_rule.dart';
import '../../../data/models/sync_status.dart';
import '../../../data/repositories/income_repository.dart';

class IncomeState extends Equatable {
  const IncomeState({
    this.loading = true,
    this.incomes = const [],
    this.monthlyTotal = 0,
    this.revision = 0,
  });

  final bool loading;
  final List<IncomeProfile> incomes;
  final int monthlyTotal;
  final int revision;

  @override
  List<Object?> get props => [loading, incomes, monthlyTotal, revision];
}

class IncomeCubit extends Cubit<IncomeState> {
  IncomeCubit(this._repo) : super(const IncomeState()) {
    _sub = _repo.watch().listen((_) => _reload());
    _reload();
  }

  final IncomeRepository _repo;
  static const _uuid = Uuid();
  late final StreamSubscription _sub;

  void _reload() {
    emit(IncomeState(
      loading: false,
      incomes: _repo.getAll(),
      monthlyTotal: _repo.totalMonthlyIncome(),
      revision: state.revision + 1,
    ));
  }

  Future<void> addIncome({
    required String label,
    required int amount,
    required RecurrenceFrequency frequency,
  }) async {
    final now = DateTime.now();
    await _repo.save(IncomeProfile(
      id: _uuid.v4(),
      label: label.trim(),
      amount: amount,
      frequency: frequency,
      createdAt: now,
      updatedAt: now,
      syncStatus: SyncStatus.dirty,
    ));
  }

  Future<void> updateIncome(IncomeProfile p) async {
    p
      ..updatedAt = DateTime.now()
      ..syncStatus = SyncStatus.dirty;
    await _repo.save(p);
  }

  Future<void> deleteIncome(String id) => _repo.delete(id);

  @override
  Future<void> close() {
    _sub.cancel();
    return super.close();
  }
}
