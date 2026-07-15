import 'package:hive/hive.dart';

import '../hive_config.dart';
import 'sync_status.dart';

part 'transaction.g.dart';

/// Sens d'un mouvement d'argent (module 3.1).
@HiveType(typeId: HiveTypeIds.transactionType)
enum TransactionType {
  @HiveField(0)
  income, // entrée
  @HiveField(1)
  expense, // sortie
}

/// Une transaction saisie manuellement par l'utilisateur.
/// `amount` est toujours positif ; le signe est porté par `type`.
@HiveType(typeId: HiveTypeIds.transaction)
class AppTransaction extends HiveObject {
  AppTransaction({
    required this.id,
    required this.amount,
    required this.type,
    required this.accountId,
    this.categoryId,
    this.note,
    required this.date,
    this.photoPath,
    this.recurringRuleId,
    required this.createdAt,
    required this.updatedAt,
    this.syncStatus = SyncStatus.dirty,
  });

  @HiveField(0)
  final String id;

  @HiveField(1)
  int amount;

  @HiveField(2)
  TransactionType type;

  @HiveField(3)
  String accountId;

  @HiveField(4)
  String? categoryId;

  @HiveField(5)
  String? note;

  @HiveField(6)
  DateTime date;

  /// Chemin local du justificatif (photo de reçu), synchronisé plus tard.
  @HiveField(7)
  String? photoPath;

  /// Renseigné si la transaction a été générée par une règle récurrente.
  @HiveField(8)
  String? recurringRuleId;

  @HiveField(9)
  DateTime createdAt;

  @HiveField(10)
  DateTime updatedAt;

  @HiveField(11)
  SyncStatus syncStatus;

  /// Impact signé sur le solde d'un compte.
  int get signedAmount => type == TransactionType.income ? amount : -amount;
}
