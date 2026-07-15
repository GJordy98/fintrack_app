import '../models/income_profile.dart';
import 'base_repository.dart';

class IncomeRepository extends BaseRepository<IncomeProfile> {
  IncomeRepository(super.box);

  @override
  String keyOf(IncomeProfile entity) => entity.id;

  List<IncomeProfile> getActive() =>
      getAll().where((i) => i.active).toList();

  /// Revenu mensuel total (équivalent lissé de toutes les sources actives).
  int totalMonthlyIncome() =>
      getActive().fold(0, (s, i) => s + i.monthlyEquivalent);
}
