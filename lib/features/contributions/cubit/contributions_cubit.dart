import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';

import '../../../core/utils/recurrence.dart';
import '../../../data/models/contribution.dart';
import '../../../data/models/contribution_event.dart';
import '../../../data/models/recurring_rule.dart';
import '../../../data/models/sync_status.dart';
import '../../../data/models/transaction.dart';
import '../../../data/repositories/contribution_repository.dart';
import '../../../data/repositories/transaction_repository.dart';

class ContributionView extends Equatable {
  const ContributionView({
    required this.contribution,
    required this.netBalance,
    required this.nextEvent,
    required this.upcomingCount,
  });

  final Contribution contribution;
  final int netBalance;
  final ContributionEvent? nextEvent;
  final int upcomingCount;

  @override
  List<Object?> get props =>
      [contribution.id, netBalance, nextEvent?.id, upcomingCount];
}

class ContributionsState extends Equatable {
  const ContributionsState({this.loading = true, this.contributions = const []});
  final bool loading;
  final List<ContributionView> contributions;

  @override
  List<Object?> get props => [loading, contributions];
}

class ContributionsCubit extends Cubit<ContributionsState> {
  ContributionsCubit(this._repo, this._transactions)
      : super(const ContributionsState()) {
    _sub = _repo.watch().listen((_) => _reload());
    _evSub = _repo.watchEvents().listen((_) => _reload());
    _reload();
  }

  final ContributionRepository _repo;
  final TransactionRepository _transactions;
  static const _uuid = Uuid();
  late final StreamSubscription _sub;
  late final StreamSubscription _evSub;

  void _reload() {
    final now = DateTime.now();
    final views = _repo.getAll().map((c) {
      final events = _repo.eventsFor(c.id);
      final upcoming = events
          .where((e) => e.status == EventStatus.upcoming)
          .toList();
      ContributionEvent? next;
      for (final e in upcoming) {
        if (!e.date.isBefore(DateTime(now.year, now.month, now.day))) {
          next = e;
          break;
        }
      }
      next ??= upcoming.isNotEmpty ? upcoming.first : null;
      return ContributionView(
        contribution: c,
        netBalance: _repo.netBalance(c.id),
        nextEvent: next,
        upcomingCount: upcoming.length,
      );
    }).toList()
      ..sort((a, b) {
        final da = a.nextEvent?.date;
        final db = b.nextEvent?.date;
        if (da == null && db == null) return 0;
        if (da == null) return 1;
        if (db == null) return -1;
        return da.compareTo(db);
      });
    emit(ContributionsState(loading: false, contributions: views));
  }

  List<ContributionEvent> eventsFor(String contributionId) =>
      _repo.eventsFor(contributionId);

  /// Crée une cotisation et génère automatiquement ses échéances de cotisation.
  Future<Contribution> addContribution({
    required String name,
    required int contributionAmount,
    required int expectedPayoutAmount,
    required RecurrenceFrequency frequency,
    int interval = 1,
    required String accountId,
    required DateTime startDate,
    DateTime? endDate,
    int occurrencesToGenerate = 12,
  }) async {
    final now = DateTime.now();
    final contribution = Contribution(
      id: _uuid.v4(),
      name: name.trim(),
      contributionAmount: contributionAmount,
      expectedPayoutAmount: expectedPayoutAmount,
      frequency: frequency,
      interval: interval,
      accountId: accountId,
      startDate: startDate,
      endDate: endDate,
      createdAt: now,
      updatedAt: now,
      syncStatus: SyncStatus.dirty,
    );
    await _repo.save(contribution);

    final dates = generateOccurrences(
      start: startDate,
      freq: frequency,
      interval: interval,
      end: endDate,
      maxOccurrences: occurrencesToGenerate,
    );
    await _repo.saveEvents(dates.map((d) => ContributionEvent(
          id: _uuid.v4(),
          contributionId: contribution.id,
          date: d,
          kind: ContributionEventKind.contribute,
          amount: contributionAmount,
          updatedAt: now,
        )));
    return contribution;
  }

  Future<void> updateContribution(Contribution c) async {
    c
      ..updatedAt = DateTime.now()
      ..syncStatus = SyncStatus.dirty;
    await _repo.save(c);
  }

  Future<void> deleteContribution(String id) => _repo.deleteWithEvents(id);

  /// Ajoute un jour de perception (« je bouffe la cotisation »).
  Future<void> addPayoutEvent(
    Contribution c, {
    required DateTime date,
    required int amount,
  }) async {
    await _repo.saveEvent(ContributionEvent(
      id: _uuid.v4(),
      contributionId: c.id,
      date: date,
      kind: ContributionEventKind.receive,
      amount: amount,
      updatedAt: DateTime.now(),
    ));
  }

  /// Ajoute manuellement un jour de cotisation supplémentaire.
  Future<void> addContributeEvent(
    Contribution c, {
    required DateTime date,
    required int amount,
  }) async {
    await _repo.saveEvent(ContributionEvent(
      id: _uuid.v4(),
      contributionId: c.id,
      date: date,
      kind: ContributionEventKind.contribute,
      amount: amount,
      updatedAt: DateTime.now(),
    ));
  }

  Future<void> deleteEvent(ContributionEvent e) async {
    if (e.transactionId != null) {
      await _transactions.delete(e.transactionId!);
    }
    await _repo.deleteEvent(e.id);
  }

  /// Valide une échéance : crée la transaction associée et marque « fait ».
  Future<void> markDone(ContributionEvent e) async {
    if (e.status == EventStatus.done) return;
    final c = _repo.getById(e.contributionId);
    if (c == null) return;
    final now = DateTime.now();
    final isReceive = e.kind == ContributionEventKind.receive;
    final tx = AppTransaction(
      id: _uuid.v4(),
      amount: e.amount,
      type: isReceive ? TransactionType.income : TransactionType.expense,
      accountId: c.accountId,
      note: '${isReceive ? 'Perception' : 'Cotisation'} : ${c.name}',
      date: e.date,
      createdAt: now,
      updatedAt: now,
      syncStatus: SyncStatus.dirty,
    );
    await _transactions.save(tx);
    e
      ..status = EventStatus.done
      ..transactionId = tx.id
      ..updatedAt = now;
    await _repo.saveEvent(e);
  }

  /// Annule la validation : supprime la transaction et repasse « à venir ».
  Future<void> markUpcoming(ContributionEvent e) async {
    if (e.transactionId != null) {
      await _transactions.delete(e.transactionId!);
    }
    e
      ..status = EventStatus.upcoming
      ..transactionId = null
      ..updatedAt = DateTime.now();
    await _repo.saveEvent(e);
  }

  @override
  Future<void> close() {
    _sub.cancel();
    _evSub.cancel();
    return super.close();
  }
}
