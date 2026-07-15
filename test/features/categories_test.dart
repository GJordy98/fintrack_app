import 'dart:io';

import 'package:fintrack_app/data/hive_config.dart';
import 'package:fintrack_app/data/models/category.dart';
import 'package:fintrack_app/data/repositories/category_repository.dart';
import 'package:fintrack_app/features/categories/cubit/categories_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import '../support/hive_test_setup.dart';

void main() {
  late Directory dir;
  late CategoryRepository repo;
  late CategoriesCubit cubit;

  setUp(() async {
    dir = await initHiveForTest();
    repo = CategoryRepository(Hive.box<Category>(HiveBoxes.categories));
    cubit = CategoriesCubit(repo);
  });

  tearDown(() async {
    await cubit.close();
    await tearDownHiveForTest(dir);
  });

  test('création d\'une catégorie personnalisée', () async {
    await cubit.addCategory(
      name: 'Coiffure',
      kind: CategoryKind.expense,
      iconCodePoint: 0xe1b1,
      colorValue: 0xFFAD1457,
    );
    final all = repo.getActive();
    expect(all.length, 1);
    expect(all.first.name, 'Coiffure');
    expect(all.first.isCustom, isTrue);
    expect(cubit.customCount, 1);
  });

  test('le compteur ne compte que les catégories personnalisées', () async {
    // Une prédéfinie (isCustom false) + une perso.
    await repo.save(Category(
      id: 'predef',
      name: 'Salaire',
      kind: CategoryKind.income,
      iconCodePoint: 0xe263,
      colorValue: 0xFF2E7D32,
      isCustom: false,
      updatedAt: DateTime(2026, 7, 15),
    ));
    await cubit.addCategory(
      name: 'Data',
      kind: CategoryKind.expense,
      iconCodePoint: 0xe1b1,
      colorValue: 0xFF1565C0,
    );
    expect(repo.getActive().length, 2);
    expect(cubit.customCount, 1);
  });

  test('archiver une catégorie perso libère un crédit de quota', () async {
    await cubit.addCategory(
      name: 'A',
      kind: CategoryKind.expense,
      iconCodePoint: 0xe1b1,
      colorValue: 0xFF1565C0,
    );
    await cubit.addCategory(
      name: 'B',
      kind: CategoryKind.expense,
      iconCodePoint: 0xe1b1,
      colorValue: 0xFFEF6C00,
    );
    expect(cubit.customCount, 2);

    final b = repo.getActive().firstWhere((c) => c.name == 'B');
    await cubit.archiveCategory(b);
    expect(cubit.customCount, 1);
    // La catégorie archivée n'apparaît plus dans les listes actives.
    expect(repo.getActive().any((c) => c.name == 'B'), isFalse);
  });

  test('modification d\'une catégorie perso', () async {
    await cubit.addCategory(
      name: 'Ancien',
      kind: CategoryKind.expense,
      iconCodePoint: 0xe1b1,
      colorValue: 0xFF1565C0,
    );
    final c = repo.getActive().first;
    await cubit.updateCategory(
      c,
      name: 'Nouveau',
      kind: CategoryKind.income,
      iconCodePoint: 0xe263,
      colorValue: 0xFF2E7D32,
    );
    final updated = repo.getById(c.id)!;
    expect(updated.name, 'Nouveau');
    expect(updated.kind, CategoryKind.income);
  });
}
