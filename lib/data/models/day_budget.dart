import 'package:hive/hive.dart';

import '../hive_config.dart';
import 'sync_status.dart';

part 'day_budget.g.dart';

/// Plan de dépense pour un jour donné (module Planning journalier).
///
/// `planned` = ce que l'utilisateur prévoit de dépenser ce jour-là.
/// `actual` = ce qu'il déclare avoir réellement dépensé le soir (null tant que
/// non renseigné ; peut être pré-rempli depuis les transactions du jour).
/// `note` = libellé optionnel (ex : « Soirée »).
@HiveType(typeId: HiveTypeIds.dayBudget)
class DayBudget extends HiveObject {
  DayBudget({
    required this.id,
    required this.date,
    this.planned = 0,
    this.actual,
    this.note,
    this.settled = false,
    required this.updatedAt,
    this.syncStatus = SyncStatus.dirty,
  });

  @HiveField(0)
  final String id;

  /// Jour concerné (normalisé à minuit).
  @HiveField(1)
  DateTime date;

  @HiveField(2)
  int planned;

  @HiveField(3)
  int? actual;

  @HiveField(4)
  String? note;

  /// true une fois la journée « validée » le soir.
  @HiveField(5)
  bool settled;

  @HiveField(6)
  DateTime updatedAt;

  @HiveField(7)
  SyncStatus syncStatus;

  /// Clé jour 'YYYY-MM-DD'.
  static String keyFor(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String get dayKey => keyFor(date);
}
