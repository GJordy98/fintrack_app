import 'package:hive/hive.dart';

import '../hive_config.dart';
import 'sync_status.dart';

part 'category.g.dart';

/// Nature d'une catégorie : revenu ou dépense (module 3.1).
@HiveType(typeId: HiveTypeIds.categoryKind)
enum CategoryKind {
  @HiveField(0)
  income,
  @HiveField(1)
  expense,
}

/// Catégorie de transaction (prédéfinie ou personnalisée), avec icône/couleur.
@HiveType(typeId: HiveTypeIds.category)
class Category extends HiveObject {
  Category({
    required this.id,
    required this.name,
    required this.kind,
    required this.iconCodePoint,
    required this.colorValue,
    this.isCustom = false,
    this.archived = false,
    required this.updatedAt,
    this.syncStatus = SyncStatus.dirty,
    this.isFixed = false,
  });

  @HiveField(0)
  final String id;

  @HiveField(1)
  String name;

  @HiveField(2)
  CategoryKind kind;

  @HiveField(3)
  int iconCodePoint;

  @HiveField(4)
  int colorValue;

  @HiveField(5)
  bool isCustom;

  @HiveField(6)
  bool archived;

  @HiveField(7)
  DateTime updatedAt;

  @HiveField(8)
  SyncStatus syncStatus;

  /// true = charge fixe / facture (loyer, électricité, eau...). Ces dépenses
  /// sont réservées d'avance et exclues du suivi des dépenses quotidiennes.
  @HiveField(9, defaultValue: false)
  bool isFixed;
}
