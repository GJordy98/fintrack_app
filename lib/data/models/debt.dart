import 'package:hive/hive.dart';

import '../hive_config.dart';
import 'sync_status.dart';

part 'debt.g.dart';

/// Sens d'une dette (module 3bis).
@HiveType(typeId: HiveTypeIds.debtDirection)
enum DebtDirection {
  @HiveField(0)
  iOwe, // je dois
  @HiveField(1)
  owedToMe, // on me doit
}

/// État d'une dette.
@HiveType(typeId: HiveTypeIds.debtStatus)
enum DebtStatus {
  @HiveField(0)
  active,
  @HiveField(1)
  settled, // soldée
}

/// Une dette, avec un plan de remboursement à dates **librement choisies** par
/// l'utilisateur (matérialisées par des [DebtRepayment]) — module 3bis.
/// Le reste à payer se calcule = principal − somme des remboursements payés.
@HiveType(typeId: HiveTypeIds.debt)
class Debt extends HiveObject {
  Debt({
    required this.id,
    required this.direction,
    required this.counterparty,
    required this.principal,
    this.reason,
    required this.contractedDate,
    this.accountId,
    this.status = DebtStatus.active,
    required this.createdAt,
    required this.updatedAt,
    this.syncStatus = SyncStatus.dirty,
  });

  @HiveField(0)
  final String id;

  @HiveField(1)
  DebtDirection direction;

  /// Nom libre du créancier (si je dois) ou du débiteur (si on me doit).
  @HiveField(2)
  String counterparty;

  /// Montant initial de la dette (FCFA).
  @HiveField(3)
  int principal;

  @HiveField(4)
  String? reason;

  @HiveField(5)
  DateTime contractedDate;

  /// Compte par défaut pour les remboursements (optionnel).
  @HiveField(6)
  String? accountId;

  @HiveField(7)
  DebtStatus status;

  @HiveField(8)
  DateTime createdAt;

  @HiveField(9)
  DateTime updatedAt;

  @HiveField(10)
  SyncStatus syncStatus;
}
