import '../models/category.dart';
import 'base_repository.dart';

class CategoryRepository extends BaseRepository<Category> {
  CategoryRepository(super.box);

  @override
  String keyOf(Category entity) => entity.id;

  List<Category> getActive() =>
      getAll().where((c) => !c.archived).toList();

  List<Category> byKind(CategoryKind kind) =>
      getActive().where((c) => c.kind == kind).toList();
}
