import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/security/security_service.dart';

enum AppLockStatus { unlocked, locked }

/// Gère l'état verrouillé/déverrouillé de l'application (module 3.8).
class AppLockCubit extends Cubit<AppLockStatus> {
  AppLockCubit(this._security)
      : super(_security.isLockEnabled
            ? AppLockStatus.locked
            : AppLockStatus.unlocked);

  final SecurityService _security;

  void unlock() => emit(AppLockStatus.unlocked);

  /// Verrouille si le verrouillage est activé (appelé quand l'app passe en
  /// arrière-plan).
  void lockIfEnabled() {
    if (_security.isLockEnabled && state != AppLockStatus.locked) {
      emit(AppLockStatus.locked);
    }
  }

  /// Après désactivation du verrouillage dans les paramètres.
  void onLockDisabled() => emit(AppLockStatus.unlocked);
}
