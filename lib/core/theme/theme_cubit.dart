import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Gère le mode d'affichage (clair / sombre / système) — module 3.8.
///
/// En Phase 0 l'état est en mémoire. La persistance (Hive) sera branchée
/// avec le module Paramètres (Phase 7).
class ThemeCubit extends Cubit<ThemeMode> {
  ThemeCubit() : super(ThemeMode.system);

  void setMode(ThemeMode mode) => emit(mode);

  void toggleDark() {
    emit(state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark);
  }
}
