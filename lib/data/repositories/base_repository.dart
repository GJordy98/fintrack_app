import 'package:hive/hive.dart';

/// Repository local générique adossé à une boîte Hive dont la clé est l'`id`
/// (String/UUID) de l'entité. Source de vérité hors-ligne (local-first).
abstract class BaseRepository<T extends HiveObject> {
  BaseRepository(this.box);

  final Box<T> box;

  /// Clé primaire de l'entité (son id).
  String keyOf(T entity);

  List<T> getAll() => box.values.toList();

  T? getById(String id) => box.get(id);

  bool exists(String id) => box.containsKey(id);

  int get count => box.length;

  Future<void> save(T entity) => box.put(keyOf(entity), entity);

  Future<void> saveAll(Iterable<T> entities) =>
      box.putAll({for (final e in entities) keyOf(e): e});

  Future<void> delete(String id) => box.delete(id);

  Future<void> clear() => box.clear();

  /// Flux réactif : émet à chaque modification de la boîte (pour les BLoC).
  Stream<BoxEvent> watch() => box.watch();
}
