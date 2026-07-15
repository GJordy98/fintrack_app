import 'package:hive/hive.dart';

import '../models/contribution.dart';
import '../models/contribution_event.dart';
import 'base_repository.dart';

/// Repository des cotisations (tontines) et de leurs échéances datées.
class ContributionRepository extends BaseRepository<Contribution> {
  ContributionRepository(super.box, this._events);

  final Box<ContributionEvent> _events;

  @override
  String keyOf(Contribution entity) => entity.id;

  List<Contribution> getActive() =>
      getAll().where((c) => c.active).toList();

  // --- Échéances ---

  Stream<BoxEvent> watchEvents() => _events.watch();

  Future<void> saveEvent(ContributionEvent e) => _events.put(e.id, e);

  Future<void> saveEvents(Iterable<ContributionEvent> events) =>
      _events.putAll({for (final e in events) e.id: e});

  Future<void> deleteEvent(String id) => _events.delete(id);

  ContributionEvent? getEvent(String id) => _events.get(id);

  List<ContributionEvent> eventsFor(String contributionId) {
    final list = _events.values
        .where((e) => e.contributionId == contributionId)
        .toList();
    list.sort((a, b) => a.date.compareTo(b.date));
    return list;
  }

  List<ContributionEvent> allEvents() => _events.values.toList();

  /// Supprime la cotisation et toutes ses échéances.
  Future<void> deleteWithEvents(String contributionId) async {
    final ids =
        eventsFor(contributionId).map((e) => e.id).toList(growable: false);
    for (final id in ids) {
      await _events.delete(id);
    }
    await delete(contributionId);
  }

  /// Solde net réalisé d'un cycle = perçu (done) − cotisé (done).
  int netBalance(String contributionId) {
    var net = 0;
    for (final e in eventsFor(contributionId)) {
      if (e.status == EventStatus.done) net += e.signedAmount;
    }
    return net;
  }
}
