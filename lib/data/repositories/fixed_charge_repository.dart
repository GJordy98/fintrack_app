import '../models/fixed_charge.dart';
import 'base_repository.dart';

class FixedChargeRepository extends BaseRepository<FixedCharge> {
  FixedChargeRepository(super.box);

  @override
  String keyOf(FixedCharge entity) => entity.id;

  List<FixedCharge> getActive() => getAll().where((c) => c.active).toList();

  /// Total mensuel des charges fixes actives (équivalent lissé).
  int totalMonthly() =>
      getActive().fold(0, (s, c) => s + c.monthlyEquivalent);
}
