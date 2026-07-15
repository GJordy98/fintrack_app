import 'package:hive/hive.dart';

import '../hive_config.dart';
import 'sync_status.dart';

part 'goal.g.dart';

/// Statut d'un objectif d'épargne. Pilote le feedback animé (module 3.6).
@HiveType(typeId: HiveTypeIds.goalStatus)
enum GoalStatus {
  @HiveField(0)
  inProgress, // en cours
  @HiveField(1)
  reached, // atteint
  @HiveField(2)
  missed, // manqué à l'échéance
}

/// Objectif d'épargne, alimenté par des versements manuels ou automatiques
/// (module 3.3). `currentAmount` est le total versé dans l'enveloppe virtuelle.
@HiveType(typeId: HiveTypeIds.goal)
class Goal extends HiveObject {
  Goal({
    required this.id,
    required this.name,
    required this.targetAmount,
    this.currentAmount = 0,
    this.targetDate,
    this.colorValue,
    this.iconCodePoint,
    this.priority = 0,
    this.status = GoalStatus.inProgress,
    required this.createdAt,
    required this.updatedAt,
    this.syncStatus = SyncStatus.dirty,
    this.monthlyContribution = 0,
  });

  @HiveField(0)
  final String id;

  @HiveField(1)
  String name;

  @HiveField(2)
  int targetAmount;

  @HiveField(3)
  int currentAmount;

  @HiveField(4)
  DateTime? targetDate;

  @HiveField(5)
  int? colorValue;

  @HiveField(6)
  int? iconCodePoint;

  /// Priorité pour l'affichage/allocation (0 = plus haute).
  @HiveField(7)
  int priority;

  @HiveField(8)
  GoalStatus status;

  @HiveField(9)
  DateTime createdAt;

  @HiveField(10)
  DateTime updatedAt;

  @HiveField(11)
  SyncStatus syncStatus;

  /// Épargne mensuelle prévue par l'utilisateur pour cet objectif quand il n'y
  /// a pas de date cible (sinon le versement mensuel est calculé). Sert au
  /// budget journalier (module Planning) pour réserver l'épargne.
  @HiveField(12, defaultValue: 0)
  int monthlyContribution;

  /// Reste à épargner pour atteindre la cible.
  int get remaining =>
      (targetAmount - currentAmount).clamp(0, targetAmount);

  /// Progression [0.0 – 1.0].
  double get progress =>
      targetAmount <= 0 ? 0 : (currentAmount / targetAmount).clamp(0.0, 1.0);
}
