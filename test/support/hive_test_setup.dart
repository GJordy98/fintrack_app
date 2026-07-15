import 'dart:io';

import 'package:hive/hive.dart';
import 'package:fintrack_app/data/hive_registrar.dart';
import 'package:fintrack_app/core/di/service_locator.dart';

/// Initialise Hive dans un dossier temporaire isolé pour les tests, enregistre
/// les adaptateurs et ouvre les boîtes. Retourne le dossier pour le nettoyage.
Future<Directory> initHiveForTest() async {
  final dir = await Directory.systemTemp.createTemp('fintrack_test_');
  Hive.init(dir.path);
  HiveRegistrar.registerAdapters();
  await HiveRegistrar.openBoxes();
  return dir;
}

/// Ferme Hive, réinitialise get_it et supprime le dossier temporaire.
Future<void> tearDownHiveForTest(Directory dir) async {
  await sl.reset();
  await Hive.close();
  if (dir.existsSync()) {
    await dir.delete(recursive: true);
  }
}
