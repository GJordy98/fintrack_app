import '../models/day_budget.dart';
import 'base_repository.dart';

class DayBudgetRepository extends BaseRepository<DayBudget> {
  DayBudgetRepository(super.box);

  @override
  String keyOf(DayBudget entity) => entity.id;

  /// Plan d'un jour précis (par sa clé 'YYYY-MM-DD'), s'il existe.
  DayBudget? forDay(DateTime date) {
    final key = DayBudget.keyFor(date);
    for (final d in getAll()) {
      if (d.dayKey == key) return d;
    }
    return null;
  }

  /// Tous les plans d'un mois donné.
  List<DayBudget> forMonth(int year, int month) => getAll()
      .where((d) => d.date.year == year && d.date.month == month)
      .toList();
}
