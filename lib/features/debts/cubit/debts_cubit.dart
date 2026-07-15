import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';

import '../../../data/models/debt.dart';
import '../../../data/models/debt_repayment.dart';
import '../../../data/models/sync_status.dart';
import '../../../data/models/transaction.dart';
import '../../../data/repositories/account_repository.dart';
import '../../../data/repositories/debt_repository.dart';
import '../../../data/repositories/transaction_repository.dart';

class DebtView extends Equatable {
  const DebtView({
    required this.debt,
    required this.remaining,
    required this.nextRepayment,
    required this.hasOverdue,
  });

  final Debt debt;
  final int remaining;
  final DebtRepayment? nextRepayment;
  final bool hasOverdue;

  @override
  List<Object?> get props =>
      [debt.id, remaining, debt.status, nextRepayment?.id, hasOverdue];
}

class DebtsState extends Equatable {
  const DebtsState({this.loading = true, this.debts = const []});
  final bool loading;
  final List<DebtView> debts;

  List<DebtView> get iOwe =>
      debts.where((d) => d.debt.direction == DebtDirection.iOwe).toList();
  List<DebtView> get owedToMe =>
      debts.where((d) => d.debt.direction == DebtDirection.owedToMe).toList();

  int get totalIOwe => iOwe.fold(0, (s, d) => s + d.remaining);
  int get totalOwedToMe => owedToMe.fold(0, (s, d) => s + d.remaining);

  @override
  List<Object?> get props => [loading, debts];
}

class DebtsCubit extends Cubit<DebtsState> {
  DebtsCubit(this._repo, this._transactions, this._accounts)
      : super(const DebtsState()) {
    _sub = _repo.watch().listen((_) => _reload());
    _rSub = _repo.watchRepayments().listen((_) => _reload());
    _reload();
  }

  final DebtRepository _repo;
  final TransactionRepository _transactions;
  final AccountRepository _accounts;
  static const _uuid = Uuid();
  late final StreamSubscription _sub;
  late final StreamSubscription _rSub;

  void _reload() {
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    final views = _repo.getAll().map((d) {
      final reps = _repo.repaymentsFor(d.id);
      DebtRepayment? next;
      var overdue = false;
      for (final r in reps) {
        if (r.status == RepaymentStatus.paid) continue;
        if (r.dueDate.isBefore(todayDate)) overdue = true;
        next ??= r;
      }
      return DebtView(
        debt: d,
        remaining: _repo.remaining(d),
        nextRepayment: next,
        hasOverdue: overdue,
      );
    }).toList()
      ..sort((a, b) {
        // Actives d'abord, puis par prochaine échéance.
        final sa = a.debt.status.index.compareTo(b.debt.status.index);
        if (sa != 0) return sa;
        final da = a.nextRepayment?.dueDate;
        final db = b.nextRepayment?.dueDate;
        if (da == null && db == null) return 0;
        if (da == null) return 1;
        if (db == null) return -1;
        return da.compareTo(db);
      });
    emit(DebtsState(loading: false, debts: views));
  }

  List<DebtRepayment> repaymentsFor(String debtId) =>
      _repo.repaymentsFor(debtId);

  Future<Debt> addDebt({
    required DebtDirection direction,
    required String counterparty,
    required int principal,
    String? reason,
    required DateTime contractedDate,
    String? accountId,
  }) async {
    final now = DateTime.now();
    final debt = Debt(
      id: _uuid.v4(),
      direction: direction,
      counterparty: counterparty.trim(),
      principal: principal,
      reason: reason,
      contractedDate: contractedDate,
      accountId: accountId,
      createdAt: now,
      updatedAt: now,
      syncStatus: SyncStatus.dirty,
    );
    await _repo.save(debt);
    return debt;
  }

  Future<void> updateDebt(Debt d) async {
    d
      ..updatedAt = DateTime.now()
      ..syncStatus = SyncStatus.dirty;
    await _repo.save(d);
  }

  Future<void> deleteDebt(String id) => _repo.deleteWithRepayments(id);

  /// Ajoute une échéance de remboursement à une date choisie par l'utilisateur.
  Future<void> addRepayment(
    Debt d, {
    required DateTime dueDate,
    required int amount,
  }) async {
    await _repo.saveRepayment(DebtRepayment(
      id: _uuid.v4(),
      debtId: d.id,
      dueDate: dueDate,
      amount: amount,
      updatedAt: DateTime.now(),
    ));
  }

  Future<void> deleteRepayment(DebtRepayment r) async {
    if (r.transactionId != null) {
      await _transactions.delete(r.transactionId!);
    }
    await _repo.deleteRepayment(r.id);
    await _refreshSettlement(r.debtId);
  }

  /// Marque une échéance payée : crée la transaction et met à jour le statut.
  Future<void> markPaid(DebtRepayment r) async {
    if (r.status == RepaymentStatus.paid) return;
    final debt = _repo.getById(r.debtId);
    if (debt == null) return;
    final accountId = debt.accountId ?? _fallbackAccountId();
    if (accountId == null) return;
    final now = DateTime.now();
    // « je dois » -> sortie ; « on me doit » -> entrée.
    final isIncome = debt.direction == DebtDirection.owedToMe;
    final tx = AppTransaction(
      id: _uuid.v4(),
      amount: r.amount,
      type: isIncome ? TransactionType.income : TransactionType.expense,
      accountId: accountId,
      note: 'Remboursement : ${debt.counterparty}',
      date: DateTime.now(),
      createdAt: now,
      updatedAt: now,
      syncStatus: SyncStatus.dirty,
    );
    await _transactions.save(tx);
    r
      ..status = RepaymentStatus.paid
      ..paidDate = now
      ..transactionId = tx.id
      ..updatedAt = now;
    await _repo.saveRepayment(r);
    await _refreshSettlement(debt.id);
  }

  Future<void> markUnpaid(DebtRepayment r) async {
    if (r.transactionId != null) {
      await _transactions.delete(r.transactionId!);
    }
    r
      ..status = RepaymentStatus.planned
      ..paidDate = null
      ..transactionId = null
      ..updatedAt = DateTime.now();
    await _repo.saveRepayment(r);
    await _refreshSettlement(r.debtId);
  }

  /// Met à jour le statut soldé / actif selon le reste à payer.
  Future<void> _refreshSettlement(String debtId) async {
    final debt = _repo.getById(debtId);
    if (debt == null) return;
    final remaining = _repo.remaining(debt);
    final shouldBeSettled = remaining <= 0;
    final isSettled = debt.status == DebtStatus.settled;
    if (shouldBeSettled != isSettled) {
      debt.status = shouldBeSettled ? DebtStatus.settled : DebtStatus.active;
      await updateDebt(debt);
    }
  }

  String? _fallbackAccountId() {
    final active = _accounts.getActive();
    return active.isEmpty ? null : active.first.id;
  }

  @override
  Future<void> close() {
    _sub.cancel();
    _rSub.cancel();
    return super.close();
  }
}
