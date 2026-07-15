import '../models/transaction.dart';
import 'base_repository.dart';

class TransactionRepository extends BaseRepository<AppTransaction> {
  TransactionRepository(super.box);

  @override
  String keyOf(AppTransaction entity) => entity.id;

  /// Toutes les transactions triées de la plus récente à la plus ancienne.
  List<AppTransaction> getAllSorted() {
    final list = getAll();
    list.sort((a, b) => b.date.compareTo(a.date));
    return list;
  }

  List<AppTransaction> byAccount(String accountId) =>
      getAll().where((t) => t.accountId == accountId).toList();

  List<AppTransaction> byCategory(String categoryId) =>
      getAll().where((t) => t.categoryId == categoryId).toList();

  /// Transactions dont la date est dans l'intervalle [from, to] (inclus).
  List<AppTransaction> inPeriod(DateTime from, DateTime to) => getAll()
      .where((t) => !t.date.isBefore(from) && !t.date.isAfter(to))
      .toList();

  /// Total des dépenses pour une catégorie sur un mois 'YYYY-MM'.
  int spentForCategoryInMonth(String categoryId, String month) {
    var total = 0;
    for (final t in getAll()) {
      if (t.type != TransactionType.expense) continue;
      if (t.categoryId != categoryId) continue;
      final m =
          '${t.date.year.toString().padLeft(4, '0')}-${t.date.month.toString().padLeft(2, '0')}';
      if (m == month) total += t.amount;
    }
    return total;
  }
}
