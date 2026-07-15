import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../models/category.dart';
import '../repositories/category_repository.dart';

/// Catégories prédéfinies créées au tout premier lancement (module 3.1).
/// L'utilisateur peut les archiver ou en ajouter des personnalisées.
class DefaultCategoriesSeeder {
  DefaultCategoriesSeeder(this._repo);

  final CategoryRepository _repo;
  static const _uuid = Uuid();

  Future<void> seedIfEmpty() async {
    if (_repo.count > 0) return;

    final now = DateTime.now();
    final defaults = <Category>[
      // Revenus
      _cat('Salaire', CategoryKind.income, Icons.payments, 0xFF2E7D32, now),
      _cat('Vente', CategoryKind.income, Icons.storefront, 0xFF388E3C, now),
      _cat('Cadeau reçu', CategoryKind.income, Icons.card_giftcard,
          0xFF43A047, now),
      _cat('Autre revenu', CategoryKind.income, Icons.attach_money,
          0xFF66BB6A, now),
      // Dépenses
      _cat('Alimentation', CategoryKind.expense, Icons.restaurant,
          0xFFEF6C00, now),
      _cat('Transport', CategoryKind.expense, Icons.directions_bus,
          0xFF1565C0, now),
      _cat('Logement', CategoryKind.expense, Icons.home, 0xFF6D4C41, now,
          isFixed: true),
      _cat('Factures', CategoryKind.expense, Icons.receipt_long, 0xFF00838F,
          now,
          isFixed: true),
      _cat('Santé', CategoryKind.expense, Icons.local_hospital,
          0xFFC62828, now),
      _cat('Éducation', CategoryKind.expense, Icons.school, 0xFF5E35B1, now),
      _cat('Loisirs', CategoryKind.expense, Icons.sports_esports,
          0xFFAD1457, now),
      _cat('Vêtements', CategoryKind.expense, Icons.checkroom,
          0xFF00695C, now),
      _cat('Famille', CategoryKind.expense, Icons.family_restroom,
          0xFF8E24AA, now),
      _cat('Autre dépense', CategoryKind.expense, Icons.more_horiz,
          0xFF546E7A, now),
    ];

    await _repo.saveAll(defaults);
  }

  Category _cat(
    String name,
    CategoryKind kind,
    IconData icon,
    int color,
    DateTime now, {
    bool isFixed = false,
  }) {
    return Category(
      id: _uuid.v4(),
      name: name,
      kind: kind,
      iconCodePoint: icon.codePoint,
      colorValue: color,
      isCustom: false,
      updatedAt: now,
      isFixed: isFixed,
    );
  }
}
