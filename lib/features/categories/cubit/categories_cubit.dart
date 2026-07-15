import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';

import '../../../data/models/category.dart';
import '../../../data/models/sync_status.dart';
import '../../../data/repositories/category_repository.dart';

class CategoriesState extends Equatable {
  const CategoriesState({
    this.loading = true,
    this.income = const [],
    this.expense = const [],
    this.customCount = 0,
    this.revision = 0,
  });

  final bool loading;

  /// Catégories actives de revenu / dépense (prédéfinies + personnalisées).
  final List<Category> income;
  final List<Category> expense;

  /// Nombre de catégories personnalisées actives (pour le quota gratuit).
  final int customCount;

  final int revision;

  @override
  List<Object?> get props => [loading, income, expense, customCount, revision];
}

/// Gère les catégories : liste et création/édition/archivage des catégories
/// PERSONNALISÉES. Les catégories prédéfinies (isCustom == false) sont
/// affichées mais non modifiables ici.
class CategoriesCubit extends Cubit<CategoriesState> {
  CategoriesCubit(this._repo) : super(const CategoriesState()) {
    _sub = _repo.watch().listen((_) => _reload());
    _reload();
  }

  final CategoryRepository _repo;
  static const _uuid = Uuid();
  late final StreamSubscription _sub;

  void _reload() {
    final active = _repo.getActive();
    emit(CategoriesState(
      loading: false,
      income: active.where((c) => c.kind == CategoryKind.income).toList(),
      expense: active.where((c) => c.kind == CategoryKind.expense).toList(),
      customCount: active.where((c) => c.isCustom).length,
      revision: state.revision + 1,
    ));
  }

  /// Nombre de catégories personnalisées actives (source de vérité pour le
  /// quota, lisible sans passer par l'état émis).
  int get customCount => _repo.getActive().where((c) => c.isCustom).length;

  Future<void> addCategory({
    required String name,
    required CategoryKind kind,
    required int iconCodePoint,
    required int colorValue,
  }) async {
    final now = DateTime.now();
    await _repo.save(Category(
      id: _uuid.v4(),
      name: name.trim(),
      kind: kind,
      iconCodePoint: iconCodePoint,
      colorValue: colorValue,
      isCustom: true,
      updatedAt: now,
      syncStatus: SyncStatus.dirty,
    ));
  }

  Future<void> updateCategory(
    Category c, {
    required String name,
    required CategoryKind kind,
    required int iconCodePoint,
    required int colorValue,
  }) async {
    c
      ..name = name.trim()
      ..kind = kind
      ..iconCodePoint = iconCodePoint
      ..colorValue = colorValue
      ..updatedAt = DateTime.now()
      ..syncStatus = SyncStatus.dirty;
    await _repo.save(c);
  }

  /// Retire une catégorie personnalisée. On l'ARCHIVE (soft delete) plutôt que
  /// de la supprimer, pour ne pas casser l'affichage des transactions qui la
  /// référencent. Elle disparaît des listes et libère un crédit de quota.
  Future<void> archiveCategory(Category c) async {
    c
      ..archived = true
      ..updatedAt = DateTime.now()
      ..syncStatus = SyncStatus.dirty;
    await _repo.save(c);
  }

  @override
  Future<void> close() {
    _sub.cancel();
    return super.close();
  }
}
