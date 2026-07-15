import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

import '../../data/settings_service.dart';

/// Sécurité de l'app : code PIN (haché) + déverrouillage biométrique
/// (module 3.8). Le hash du PIN est stocké dans le stockage sécurisé Android
/// (Keystore), jamais en clair.
class SecurityService {
  SecurityService(this._settings);

  final SettingsService _settings;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  final LocalAuthentication _localAuth = LocalAuthentication();

  static const _kHash = 'pin_hash';
  static const _kSalt = 'pin_salt';

  bool get isLockEnabled => _settings.lockEnabled;
  bool get isBiometricEnabled => _settings.biometricEnabled;

  String _hash(String pin, String salt) =>
      sha256.convert(utf8.encode('$salt::$pin')).toString();

  String _newSalt() {
    final rnd = Random.secure();
    final bytes = List<int>.generate(16, (_) => rnd.nextInt(256));
    return base64Url.encode(bytes);
  }

  /// Définit (ou change) le code PIN et active le verrouillage.
  Future<void> setPin(String pin) async {
    final salt = _newSalt();
    await _storage.write(key: _kSalt, value: salt);
    await _storage.write(key: _kHash, value: _hash(pin, salt));
    await _settings.setLockEnabled(true);
  }

  Future<bool> verifyPin(String pin) async {
    final salt = await _storage.read(key: _kSalt);
    final hash = await _storage.read(key: _kHash);
    if (salt == null || hash == null) return false;
    return _hash(pin, salt) == hash;
  }

  Future<bool> hasPin() async => (await _storage.read(key: _kHash)) != null;

  /// Désactive le verrouillage et efface le PIN.
  Future<void> disableLock() async {
    await _storage.delete(key: _kHash);
    await _storage.delete(key: _kSalt);
    await _settings.setLockEnabled(false);
    await _settings.setBiometricEnabled(false);
  }

  Future<void> setBiometricEnabled(bool value) =>
      _settings.setBiometricEnabled(value);

  /// La biométrie est-elle disponible sur l'appareil ?
  Future<bool> canUseBiometrics() async {
    try {
      final supported = await _localAuth.isDeviceSupported();
      final canCheck = await _localAuth.canCheckBiometrics;
      return supported && canCheck;
    } catch (_) {
      return false;
    }
  }

  /// Lance l'authentification biométrique. Retourne true si réussie.
  Future<bool> authenticateBiometric() async {
    try {
      return await _localAuth.authenticate(
        localizedReason: 'Déverrouille FinTrack',
        biometricOnly: true,
        persistAcrossBackgrounding: true,
      );
    } catch (_) {
      return false;
    }
  }
}
