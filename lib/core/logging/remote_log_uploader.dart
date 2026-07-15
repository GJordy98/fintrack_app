import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;

import '../constants/app_constants.dart';
import '../../data/settings_service.dart';
import 'app_logger.dart';

/// Envoie silencieusement les avertissements/erreurs de l'app au serveur, où
/// seuls les administrateurs peuvent les consulter (dashboard Django `/admin`).
///
/// Rien n'est jamais affiché à l'utilisateur. L'envoi est « au mieux » :
/// - non bloquant pour l'app ;
/// - une file d'attente persistante (Hive) conserve les logs non envoyés pour
///   réessayer plus tard (hors-ligne, serveur injoignable, redémarrage).
class RemoteLogUploader {
  RemoteLogUploader(this._settings, this._queue);

  final SettingsService _settings;

  /// File persistante : chaque valeur est une Map prête pour l'API `/api/logs`.
  final Box _queue;

  /// Nombre max d'entrées envoyées par requête (cohérent avec le backend).
  static const int _batchSize = 100;

  /// Plafond de la file locale : on ne garde que les plus récents pour ne pas
  /// grossir indéfiniment si le serveur reste injoignable.
  static const int _maxQueue = 500;

  bool _flushing = false;

  String get _baseUrl {
    final url = _settings.serverBaseUrl ?? AppConstants.defaultApiBaseUrl;
    return url.endsWith('/') ? url.substring(0, url.length - 1) : url;
  }

  /// Met en file une entrée de log et tente un envoi immédiat (non bloquant).
  void enqueue(LogEntry entry) {
    try {
      // L'erreur peut contenir le message puis la stacktrace (séparés par un
      // saut de ligne) : on les sépare pour l'affichage admin.
      final raw = entry.message;
      final nl = raw.indexOf('\n');
      final message = nl == -1 ? raw : raw.substring(0, nl);
      final stack = nl == -1 ? '' : raw.substring(nl + 1);

      _queue.add({
        'level': entry.level.name,
        'message': message,
        'stacktrace': stack,
        'platform': _platform,
        'app_version': AppConstants.appVersion,
        'device_model': _deviceModel,
        'os_version': _osVersion,
        'client_time': entry.time.toIso8601String(),
      });
      _trim();
    } catch (_) {
      // Ne jamais laisser la journalisation casser l'app.
      return;
    }
    unawaited(flush());
  }

  /// Envoie tout ce qui est en file. Sûr à appeler souvent (garde anti-doublon).
  Future<void> flush() async {
    if (_flushing || _queue.isEmpty) return;
    _flushing = true;
    try {
      while (_queue.isNotEmpty) {
        final keys = _queue.keys.take(_batchSize).toList();
        final logs = <Map<String, dynamic>>[];
        for (final k in keys) {
          final v = _queue.get(k);
          if (v is Map) logs.add(Map<String, dynamic>.from(v));
        }
        if (logs.isEmpty) {
          await _queue.deleteAll(keys);
          continue;
        }

        final resp = await http
            .post(
              Uri.parse('$_baseUrl/api/logs/'),
              headers: await _headers(),
              body: jsonEncode({'logs': logs}),
            )
            .timeout(const Duration(seconds: 15));

        if (resp.statusCode == 200 || resp.statusCode == 201) {
          await _queue.deleteAll(keys);
        } else {
          // Serveur joignable mais refus : on arrête, on réessaiera plus tard.
          break;
        }
      }
    } catch (_) {
      // Hors-ligne / timeout : on garde la file pour un prochain essai.
    } finally {
      _flushing = false;
    }
  }

  void _trim() {
    while (_queue.length > _maxQueue) {
      _queue.deleteAt(0); // supprime le plus ancien
    }
  }

  Future<Map<String, String>> _headers() async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'ngrok-skip-browser-warning': 'true',
    };
    // L'app est utilisable sans connexion : on joint le token seulement si
    // l'utilisatrice est connectée (le log est alors associé à son compte).
    // Si Firebase n'est pas prêt, on envoie le log sans authentification.
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final token = await user.getIdToken();
        if (token != null) headers['Authorization'] = 'Bearer $token';
      }
    } catch (_) {
      // Firebase indisponible : envoi anonyme (le log reste utile à l'admin).
    }
    return headers;
  }

  // --- Contexte appareil (capturé une fois, sans dépendance native) ---
  static final String _platform = Platform.operatingSystem;
  static final String _osVersion = Platform.operatingSystemVersion;
  static const String _deviceModel = ''; // non disponible sans plugin dédié
}
