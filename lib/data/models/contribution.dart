import 'package:hive/hive.dart';

import '../hive_config.dart';
import 'recurring_rule.dart';
import 'sync_status.dart';

part 'contribution.g.dart';

/// Une cotisation / tontine (njangi), vue **du point de vue de l'utilisateur
/// uniquement** (on ne modélise pas les autres membres) — module 3bis.
///
/// Elle porte le calendrier : les jours où l'utilisateur **cotise** (sortie)
/// et les jours où il **perçoit / « bouffe »** (entrée). Les occurrences
/// concrètes sont matérialisées par des [ContributionEvent].
@HiveType(typeId: HiveTypeIds.contribution)
class Contribution extends HiveObject {
  Contribution({
    required this.id,
    required this.name,
    required this.contributionAmount,
    this.expectedPayoutAmount = 0,
    required this.frequency,
    this.interval = 1,
    required this.accountId,
    required this.startDate,
    this.endDate,
    this.active = true,
    required this.createdAt,
    required this.updatedAt,
    this.syncStatus = SyncStatus.dirty,
  });

  @HiveField(0)
  final String id;

  @HiveField(1)
  String name;

  /// Montant versé à chaque échéance de cotisation.
  @HiveField(2)
  int contributionAmount;

  /// Montant attendu le jour où l'utilisateur perçoit son tour (le « pot »).
  @HiveField(3)
  int expectedPayoutAmount;

  @HiveField(4)
  RecurrenceFrequency frequency;

  @HiveField(5)
  int interval;

  @HiveField(6)
  String accountId;

  @HiveField(7)
  DateTime startDate;

  @HiveField(8)
  DateTime? endDate;

  @HiveField(9)
  bool active;

  @HiveField(10)
  DateTime createdAt;

  @HiveField(11)
  DateTime updatedAt;

  @HiveField(12)
  SyncStatus syncStatus;
}
