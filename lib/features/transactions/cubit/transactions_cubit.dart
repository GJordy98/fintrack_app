import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';

import '../../../data/models/sync_status.dart';
import '../../../data/models/transaction.dart';
import '../../../data/repositories/transaction_repository.dart';

/// Critères de filtrage (module 3.1 : période, catégorie, compte, montant).
class TransactionFilter extends Equatable {
  const TransactionFilter({
    this.query = '',
    this.accountId,
    this.categoryId,
    this.type,
    this.from,
    this.to,
  });

  final String query;
  final String? accountId;
  final String? categoryId;
  final TransactionType? type;
  final DateTime? from;
  final DateTime? to;

  bool get isActive =>
      query.isNotEmpty ||
      accountId != null ||
      categoryId != null ||
      type != null ||
      from != null ||
      to != null;

  TransactionFilter copyWith({
    String? query,
    String? Function()? accountId,
    String? Function()? categoryId,
    TransactionType? Function()? type,
    DateTime? Function()? from,
    DateTime? Function()? to,
  }) {
    return TransactionFilter(
      query: query ?? this.query,
      accountId: accountId != null ? accountId() : this.accountId,
      categoryId: categoryId != null ? categoryId() : this.categoryId,
      type: type != null ? type() : this.type,
      from: from != null ? from() : this.from,
      to: to != null ? to() : this.to,
    );
  }

  @override
  List<Object?> get props => [query, accountId, categoryId, type, from, to];
}

class TransactionsState extends Equatable {
  const TransactionsState({
    this.loading = true,
    this.all = const [],
    this.filter = const TransactionFilter(),
    this.revision = 0,
  });

  final bool loading;
  final List<AppTransaction> all;
  final TransactionFilter filter;

  /// Incrémenté à chaque rechargement pour forcer le rebuild même quand une
  /// transaction est modifiée en place (objet Hive muté, même référence).
  final int revision;

  /// Liste filtrée, déjà triée (plus récent d'abord).
  List<AppTransaction> get visible {
    return all.where((t) {
      final f = filter;
      if (f.accountId != null && t.accountId != f.accountId) return false;
      if (f.categoryId != null && t.categoryId != f.categoryId) return false;
      if (f.type != null && t.type != f.type) return false;
      if (f.from != null && t.date.isBefore(f.from!)) return false;
      if (f.to != null && t.date.isAfter(f.to!)) return false;
      if (f.query.isNotEmpty) {
        final q = f.query.toLowerCase();
        final note = (t.note ?? '').toLowerCase();
        if (!note.contains(q) && !t.amount.toString().contains(q)) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  TransactionsState copyWith({
    bool? loading,
    List<AppTransaction>? all,
    TransactionFilter? filter,
    int? revision,
  }) {
    return TransactionsState(
      loading: loading ?? this.loading,
      all: all ?? this.all,
      filter: filter ?? this.filter,
      revision: revision ?? this.revision,
    );
  }

  @override
  List<Object?> get props => [loading, all, filter, revision];
}

class TransactionsCubit extends Cubit<TransactionsState> {
  TransactionsCubit(this._repo) : super(const TransactionsState()) {
    _sub = _repo.watch().listen((_) => _reload());
    _reload();
  }

  final TransactionRepository _repo;
  static const _uuid = Uuid();
  late final StreamSubscription _sub;

  void _reload() {
    emit(state.copyWith(
        loading: false,
        all: _repo.getAllSorted(),
        revision: state.revision + 1));
  }

  Future<void> addTransaction({
    required int amount,
    required TransactionType type,
    required String accountId,
    String? categoryId,
    String? note,
    required DateTime date,
    String? photoPath,
  }) async {
    final now = DateTime.now();
    await _repo.save(AppTransaction(
      id: _uuid.v4(),
      amount: amount,
      type: type,
      accountId: accountId,
      categoryId: categoryId,
      note: note,
      date: date,
      photoPath: photoPath,
      createdAt: now,
      updatedAt: now,
      syncStatus: SyncStatus.dirty,
    ));
  }

  Future<void> updateTransaction(AppTransaction tx) async {
    tx
      ..updatedAt = DateTime.now()
      ..syncStatus = SyncStatus.dirty;
    await _repo.save(tx);
  }

  Future<void> deleteTransaction(String id) => _repo.delete(id);

  void setFilter(TransactionFilter filter) =>
      emit(state.copyWith(filter: filter));

  void clearFilter() =>
      emit(state.copyWith(filter: const TransactionFilter()));

  @override
  Future<void> close() {
    _sub.cancel();
    return super.close();
  }
}
