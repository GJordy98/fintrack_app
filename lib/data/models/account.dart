import 'package:hive/hive.dart';

import '../hive_config.dart';
import 'sync_status.dart';

part 'account.g.dart';

/// Type de compte (multi-comptes, module 3.1).
@HiveType(typeId: HiveTypeIds.accountType)
enum AccountType {
  @HiveField(0)
  cash, // espèces
  @HiveField(1)
  mobileMoney, // Mobile Money (Orange Money, MTN MoMo...)
  @HiveField(2)
  bank, // banque
  @HiveField(3)
  other,
}

/// Un compte de l'utilisateur. Le solde courant n'est PAS stocké :
/// il se calcule = soldeInitial + somme des transactions du compte.
@HiveType(typeId: HiveTypeIds.account)
class Account extends HiveObject {
  Account({
    required this.id,
    required this.name,
    required this.type,
    this.initialBalance = 0,
    this.currencyCode = 'XAF',
    this.colorValue,
    this.iconCodePoint,
    this.archived = false,
    required this.createdAt,
    required this.updatedAt,
    this.syncStatus = SyncStatus.dirty,
    this.provider,
    this.bankName,
    this.bankAccountKind,
  });

  @HiveField(0)
  final String id;

  @HiveField(1)
  String name;

  @HiveField(2)
  AccountType type;

  /// Solde d'ouverture, en unité entière (FCFA sans décimales).
  @HiveField(3)
  int initialBalance;

  @HiveField(4)
  String currencyCode;

  @HiveField(5)
  int? colorValue;

  @HiveField(6)
  int? iconCodePoint;

  @HiveField(7)
  bool archived;

  @HiveField(8)
  DateTime createdAt;

  @HiveField(9)
  DateTime updatedAt;

  @HiveField(10)
  SyncStatus syncStatus;

  /// Opérateur Mobile Money (ex : Orange Money, MTN MoMo, Wave).
  @HiveField(11)
  String? provider;

  /// Nom de la banque (pour un compte bancaire).
  @HiveField(12)
  String? bankName;

  /// Type de compte bancaire (ex : Courant, Épargne).
  @HiveField(13)
  String? bankAccountKind;
}
