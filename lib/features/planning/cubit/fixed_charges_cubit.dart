import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';

import '../../../data/models/category.dart';
import '../../../data/models/fixed_charge.dart';
import '../../../data/models/recurring_rule.dart';
import '../../../data/models/sync_status.dart';
import '../../../data/repositories/category_repository.dart';
import '../../../data/repositories/fixed_charge_repository.dart';

class FixedChargesState extends Equatable {
  const FixedChargesState({
    this.loading = true,
    this.charges = const [],
    this.monthlyTotal = 0,
    this.expenseCategories = const [],
    this.revision = 0,
  });

  final bool loading;
  final List<FixedCharge> charges;
  final int monthlyTotal;
  final List<Category> expenseCategories;
  final int revision;

  @override
  List<Object?> get props =>
      [loading, charges, monthlyTotal, expenseCategories, revision];
}

class FixedChargesCubit extends Cubit<FixedChargesState> {
  FixedChargesCubit(this._repo, this._categories)
      : super(const FixedChargesState()) {
    _sub = _repo.watch().listen((_) => _reload());
    _catSub = _categories.watch().listen((_) => _reload());
    _reload();
  }

  final FixedChargeRepository _repo;
  final CategoryRepository _categories;
  static const _uuid = Uuid();
  late final StreamSubscription _sub;
  late final StreamSubscription _catSub;

  void _reload() {
    emit(FixedChargesState(
      loading: false,
      charges: _repo.getAll(),
      monthlyTotal: _repo.totalMonthly(),
      expenseCategories: _categories.byKind(CategoryKind.expense),
      revision: state.revision + 1,
    ));
  }

  Future<void> addCharge({
    required String label,
    required int amount,
    required RecurrenceFrequency frequency,
  }) async {
    final now = DateTime.now();
    await _repo.save(FixedCharge(
      id: _uuid.v4(),
      label: label.trim(),
      amount: amount,
      frequency: frequency,
      createdAt: now,
      updatedAt: now,
      syncStatus: SyncStatus.dirty,
    ));
  }

  Future<void> updateCharge(FixedCharge c) async {
    c
      ..updatedAt = DateTime.now()
      ..syncStatus = SyncStatus.dirty;
    await _repo.save(c);
  }

  Future<void> deleteCharge(String id) => _repo.delete(id);

  /// Bascule une catégorie en « charge fixe » (exclue du suivi quotidien).
  Future<void> toggleCategoryFixed(Category category, bool value) async {
    category
      ..isFixed = value
      ..updatedAt = DateTime.now()
      ..syncStatus = SyncStatus.dirty;
    await _categories.save(category);
  }

  @override
  Future<void> close() {
    _sub.cancel();
    _catSub.cancel();
    return super.close();
  }
}
