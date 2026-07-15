import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/models/contribution_event.dart';
import '../../data/models/debt.dart';
import '../../data/models/debt_repayment.dart';
import '../../data/models/goal.dart';
import '../../data/repositories/contribution_repository.dart';
import '../../data/repositories/debt_repository.dart';
import '../../data/repositories/goal_repository.dart';
import '../../data/settings_service.dart';
import '../utils/money_formatter.dart';
import 'notification_service.dart';

/// Reprogramme l'ensemble des rappels locaux à partir des données courantes
/// (module 3.7). Appelé au démarrage et à chaque changement pertinent.
class NotificationScheduler {
  NotificationScheduler(
    this._notifications,
    this._contributions,
    this._debts,
    this._goals,
    this._settings,
  );

  final NotificationService _notifications;
  final ContributionRepository _contributions;
  final DebtRepository _debts;
  final GoalRepository _goals;
  final SettingsService _settings;

  // IDs réservés pour les rappels récurrents.
  static const int _dailyId = 1;
  static const int _goalsMonthlyId = 2;

  /// Ne programme que les échéances dans cette fenêtre (jours).
  static const int _horizonDays = 120;
  static const int _reminderHour = 9; // rappels d'échéance à 9h

  final List<StreamSubscription> _subs = [];
  bool _syncing = false;
  bool _pending = false;

  Future<void> start() async {
    await _notifications.init();
    if (!_settings.permissionRequested) {
      await _notifications.requestPermission();
      await _settings.setPermissionRequested(true);
    }
    _subs
      ..add(_contributions.watchEvents().listen((_) => _requestSync()))
      ..add(_debts.watchRepayments().listen((_) => _requestSync()))
      ..add(_goals.watch().listen((_) => _requestSync()));
    await syncAll();
  }

  void _requestSync() {
    if (_syncing) {
      _pending = true;
      return;
    }
    syncAll();
  }

  Future<void> syncAll() async {
    _syncing = true;
    try {
      await _notifications.cancelAll();
      await _scheduleDaily();
      await _scheduleContributions();
      await _scheduleDebts();
      await _scheduleGoalsMonthly();
    } finally {
      _syncing = false;
      if (_pending) {
        _pending = false;
        await syncAll();
      }
    }
  }

  Future<void> _scheduleDaily() async {
    if (!_settings.dailyReminderEnabled) return;
    await _notifications.scheduleDaily(
      id: _dailyId,
      time: TimeOfDay(
        hour: _settings.dailyReminderHour,
        minute: _settings.dailyReminderMinute,
      ),
      title: 'FinTrack',
      body: 'N\'oublie pas de noter tes dépenses et revenus du jour ✍️',
    );
  }

  Future<void> _scheduleContributions() async {
    final now = DateTime.now();
    final limit = now.add(const Duration(days: _horizonDays));
    for (final c in _contributions.getAll()) {
      for (final e in _contributions.eventsFor(c.id)) {
        if (e.status != EventStatus.upcoming) continue;
        if (e.date.isBefore(now) || e.date.isAfter(limit)) continue;
        final isReceive = e.kind == ContributionEventKind.receive;
        await _notifications.scheduleAt(
          id: _idOf(e.id),
          when: _atReminderHour(e.date),
          title: isReceive ? 'Perception — ${c.name}' : 'Cotisation — ${c.name}',
          body: isReceive
              ? 'C\'est ton tour ! Tu perçois ${MoneyFormatter.format(e.amount)} aujourd\'hui.'
              : 'Pense à cotiser ${MoneyFormatter.format(e.amount)} aujourd\'hui.',
        );
      }
    }
  }

  Future<void> _scheduleDebts() async {
    final now = DateTime.now();
    final limit = now.add(const Duration(days: _horizonDays));
    final byId = {for (final d in _debts.getAll()) d.id: d};
    for (final r in _debts.allRepayments()) {
      if (r.status == RepaymentStatus.paid) continue;
      if (r.dueDate.isBefore(now) || r.dueDate.isAfter(limit)) continue;
      final debt = byId[r.debtId];
      if (debt == null) continue;
      final iOwe = debt.direction == DebtDirection.iOwe;
      await _notifications.scheduleAt(
        id: _idOf(r.id),
        when: _atReminderHour(r.dueDate),
        title: iOwe
            ? 'Remboursement — ${debt.counterparty}'
            : 'À encaisser — ${debt.counterparty}',
        body: iOwe
            ? 'Échéance de ${MoneyFormatter.format(r.amount)} à rembourser aujourd\'hui.'
            : '${debt.counterparty} doit te rembourser ${MoneyFormatter.format(r.amount)} aujourd\'hui.',
      );
    }
  }

  Future<void> _scheduleGoalsMonthly() async {
    final hasActive =
        _goals.byStatus(GoalStatus.inProgress).isNotEmpty;
    if (!hasActive) return;
    // Rappel le 1er du mois à 9h.
    final now = DateTime.now();
    var next = DateTime(now.year, now.month + 1, 1, _reminderHour);
    if (DateTime(now.year, now.month, 1, _reminderHour).isAfter(now)) {
      next = DateTime(now.year, now.month, 1, _reminderHour);
    }
    await _notifications.scheduleAt(
      id: _goalsMonthlyId,
      when: next,
      title: 'Objectifs d\'épargne 🎯',
      body: 'Nouveau mois : pense à alimenter tes objectifs d\'épargne.',
    );
  }

  DateTime _atReminderHour(DateTime day) =>
      DateTime(day.year, day.month, day.day, _reminderHour);

  /// Convertit un id String en id de notification int stable et positif.
  int _idOf(String id) => id.hashCode & 0x7fffffff;

  Future<void> dispose() async {
    for (final s in _subs) {
      await s.cancel();
    }
    _subs.clear();
  }
}
