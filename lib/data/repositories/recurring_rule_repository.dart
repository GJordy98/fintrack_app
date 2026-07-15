import '../models/recurring_rule.dart';
import 'base_repository.dart';

class RecurringRuleRepository extends BaseRepository<RecurringRule> {
  RecurringRuleRepository(super.box);

  @override
  String keyOf(RecurringRule entity) => entity.id;

  List<RecurringRule> getActive() => getAll().where((r) => r.active).toList();

  List<RecurringRule> getAllSorted() {
    final list = getAll();
    list.sort((a, b) => a.nextRun.compareTo(b.nextRun));
    return list;
  }
}
