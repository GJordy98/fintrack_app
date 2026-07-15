import 'package:hive/hive.dart';

import '../hive_config.dart';
import 'sync_status.dart';

part 'contribution_event.g.dart';

/// Sens d'une échéance de cotisation (module 3bis).
@HiveType(typeId: HiveTypeIds.contributionEventKind)
enum ContributionEventKind {
  @HiveField(0)
  contribute, // jour où l'utilisateur cotise (sortie)
  @HiveField(1)
  receive, // jour où l'utilisateur perçoit / « bouffe » (entrée)
}

/// État d'une échéance datée (cotisation ou dette).
@HiveType(typeId: HiveTypeIds.eventStatus)
enum EventStatus {
  @HiveField(0)
  upcoming, // à venir
  @HiveField(1)
  done, // fait / réalisé
  @HiveField(2)
  missed, // manqué
}

/// Une occurrence datée d'une cotisation : soit l'utilisateur cotise, soit il
/// perçoit son tour. Génère une transaction rattachée quand elle est validée.
@HiveType(typeId: HiveTypeIds.contributionEvent)
class ContributionEvent extends HiveObject {
  ContributionEvent({
    required this.id,
    required this.contributionId,
    required this.date,
    required this.kind,
    required this.amount,
    this.status = EventStatus.upcoming,
    this.transactionId,
    required this.updatedAt,
    this.syncStatus = SyncStatus.dirty,
  });

  @HiveField(0)
  final String id;

  @HiveField(1)
  String contributionId;

  @HiveField(2)
  DateTime date;

  @HiveField(3)
  ContributionEventKind kind;

  @HiveField(4)
  int amount;

  @HiveField(5)
  EventStatus status;

  /// Transaction générée lorsque l'échéance est validée (payée / perçue).
  @HiveField(6)
  String? transactionId;

  @HiveField(7)
  DateTime updatedAt;

  @HiveField(8)
  SyncStatus syncStatus;

  /// Impact signé sur la trésorerie prévisionnelle.
  int get signedAmount =>
      kind == ContributionEventKind.receive ? amount : -amount;
}
