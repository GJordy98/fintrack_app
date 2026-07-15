import 'package:hive/hive.dart';

import '../hive_config.dart';
import 'sync_status.dart';

part 'budget.g.dart';

/// Enveloppe budgétaire pour une catégorie sur un mois donné (module 3.2).
@HiveType(typeId: HiveTypeIds.budget)
class Budget extends HiveObject {
  Budget({
    required this.id,
    required this.categoryId,
    required this.month,
    required this.allocated,
    this.rollover = false,
    this.alertThresholdPercent = 80,
    required this.updatedAt,
    this.syncStatus = SyncStatus.dirty,
  });

  @HiveField(0)
  final String id;

  @HiveField(1)
  String categoryId;

  /// Mois au format 'YYYY-MM'.
  @HiveField(2)
  String month;

  /// Montant alloué à l'enveloppe (FCFA).
  @HiveField(3)
  int allocated;

  /// true = reporter le solde restant sur le mois suivant ; false = remise à 0.
  @HiveField(4)
  bool rollover;

  /// Seuil (%) déclenchant l'alerte de dépassement (barre orange).
  @HiveField(5)
  int alertThresholdPercent;

  @HiveField(6)
  DateTime updatedAt;

  @HiveField(7)
  SyncStatus syncStatus;
}
