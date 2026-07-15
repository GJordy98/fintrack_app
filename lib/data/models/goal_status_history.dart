import 'package:hive/hive.dart';

import '../hive_config.dart';
import 'goal.dart';
import 'sync_status.dart';

part 'goal_status_history.g.dart';

/// Historique des changements de statut d'un objectif.
///
/// Permet de rejouer le feedback animé (module 3.6) depuis l'historique, et de
/// le retrouver même après réinstallation (historisé côté serveur, module 4).
@HiveType(typeId: HiveTypeIds.goalStatusHistory)
class GoalStatusHistory extends HiveObject {
  GoalStatusHistory({
    required this.id,
    required this.goalId,
    required this.status,
    required this.date,
    required this.amountAtEvaluation,
    this.acknowledged = false,
    this.syncStatus = SyncStatus.dirty,
  });

  @HiveField(0)
  final String id;

  @HiveField(1)
  String goalId;

  @HiveField(2)
  GoalStatus status;

  /// Date d'évaluation du statut.
  @HiveField(3)
  DateTime date;

  /// Montant épargné au moment de l'évaluation (pour le message personnalisé).
  @HiveField(4)
  int amountAtEvaluation;

  /// true une fois l'animation vue par l'utilisateur (mais reste rejouable).
  @HiveField(5)
  bool acknowledged;

  @HiveField(6)
  SyncStatus syncStatus;
}
