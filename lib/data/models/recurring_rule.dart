import 'package:hive/hive.dart';

import '../hive_config.dart';
import 'sync_status.dart';
import 'transaction.dart';

part 'recurring_rule.g.dart';

/// Fréquence d'une occurrence récurrente. Partagée par les transactions
/// récurrentes (3.1) et les cotisations (3bis).
@HiveType(typeId: HiveTypeIds.recurrenceFrequency)
enum RecurrenceFrequency {
  @HiveField(0)
  daily,
  @HiveField(1)
  weekly,
  @HiveField(2)
  biweekly,
  @HiveField(3)
  monthly,
  @HiveField(4)
  yearly,
}

/// Règle générant automatiquement des transactions (loyer, salaire, abo...).
@HiveType(typeId: HiveTypeIds.recurringRule)
class RecurringRule extends HiveObject {
  RecurringRule({
    required this.id,
    required this.label,
    required this.amount,
    required this.type,
    required this.accountId,
    this.categoryId,
    required this.frequency,
    this.interval = 1,
    required this.startDate,
    required this.nextRun,
    this.endDate,
    this.active = true,
    required this.updatedAt,
    this.syncStatus = SyncStatus.dirty,
  });

  @HiveField(0)
  final String id;

  @HiveField(1)
  String label;

  @HiveField(2)
  int amount;

  @HiveField(3)
  TransactionType type;

  @HiveField(4)
  String accountId;

  @HiveField(5)
  String? categoryId;

  @HiveField(6)
  RecurrenceFrequency frequency;

  /// Tous les N `frequency` (ex : toutes les 2 semaines -> biweekly=1 ou
  /// weekly avec interval=2).
  @HiveField(7)
  int interval;

  @HiveField(8)
  DateTime startDate;

  /// Prochaine date à laquelle une transaction doit être générée.
  @HiveField(9)
  DateTime nextRun;

  @HiveField(10)
  DateTime? endDate;

  @HiveField(11)
  bool active;

  @HiveField(12)
  DateTime updatedAt;

  @HiveField(13)
  SyncStatus syncStatus;
}
