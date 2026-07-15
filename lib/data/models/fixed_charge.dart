import 'package:hive/hive.dart';

import '../hive_config.dart';
import 'recurring_rule.dart';
import 'sync_status.dart';

part 'fixed_charge.g.dart';

/// Une charge fixe récurrente (loyer, électricité, eau, abonnement...).
///
/// Comme le salaire côté revenus, ces obligations sont réservées d'avance dans
/// le budget et exclues du suivi des dépenses quotidiennes.
@HiveType(typeId: HiveTypeIds.fixedCharge)
class FixedCharge extends HiveObject {
  FixedCharge({
    required this.id,
    required this.label,
    required this.amount,
    required this.frequency,
    this.active = true,
    required this.createdAt,
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
  RecurrenceFrequency frequency;

  @HiveField(4)
  bool active;

  @HiveField(5)
  DateTime createdAt;

  @HiveField(6)
  DateTime updatedAt;

  @HiveField(7)
  SyncStatus syncStatus;

  /// Équivalent mensuel de la charge.
  int get monthlyEquivalent {
    switch (frequency) {
      case RecurrenceFrequency.daily:
        return (amount * 365 / 12).round();
      case RecurrenceFrequency.weekly:
        return (amount * 52 / 12).round();
      case RecurrenceFrequency.biweekly:
        return (amount * 26 / 12).round();
      case RecurrenceFrequency.monthly:
        return amount;
      case RecurrenceFrequency.yearly:
        return (amount / 12).round();
    }
  }
}
