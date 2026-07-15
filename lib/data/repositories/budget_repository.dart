import '../models/budget.dart';
import 'base_repository.dart';

class BudgetRepository extends BaseRepository<Budget> {
  BudgetRepository(super.box);

  @override
  String keyOf(Budget entity) => entity.id;

  /// Enveloppes définies pour un mois donné ('YYYY-MM').
  List<Budget> forMonth(String month) =>
      getAll().where((b) => b.month == month).toList();

  /// Enveloppe d'une catégorie pour un mois donné, si elle existe.
  Budget? forCategoryAndMonth(String categoryId, String month) {
    for (final b in getAll()) {
      if (b.categoryId == categoryId && b.month == month) return b;
    }
    return null;
  }
}
