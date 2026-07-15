import 'package:hive/hive.dart';

import '../models/goal.dart';
import '../models/goal_status_history.dart';
import 'base_repository.dart';

class GoalRepository extends BaseRepository<Goal> {
  GoalRepository(super.box, this._history);

  final Box<GoalStatusHistory> _history;

  @override
  String keyOf(Goal entity) => entity.id;

  List<Goal> byStatus(GoalStatus status) =>
      getAll().where((g) => g.status == status).toList();

  // --- Historique de statut (alimente le feedback animé, Phase 5) ---

  Future<void> addStatusHistory(GoalStatusHistory entry) =>
      _history.put(entry.id, entry);

  List<GoalStatusHistory> historyForGoal(String goalId) {
    final list =
        _history.values.where((h) => h.goalId == goalId).toList();
    list.sort((a, b) => b.date.compareTo(a.date));
    return list;
  }

  /// Entrées de statut non encore « acquittées » (animation pas encore vue).
  List<GoalStatusHistory> unacknowledgedHistory() =>
      _history.values.where((h) => !h.acknowledged).toList();

  Future<void> acknowledgeHistory(GoalStatusHistory entry) async {
    entry.acknowledged = true;
    await _history.put(entry.id, entry);
  }
}
