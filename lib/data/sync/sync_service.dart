import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import '../../core/constants/app_constants.dart';
import '../../core/logging/app_logger.dart';
import '../settings_service.dart';
import 'sync_buckets.dart';

/// Résultat d'une synchronisation.
class SyncResult {
  const SyncResult({
    required this.pushed,
    required this.pulled,
    this.error,
  });
  final int pushed;
  final int pulled;
  final String? error;

  bool get success => error == null;
}

/// Client de synchronisation cloud (sauvegarde + multi-appareil).
///
/// Local-first : la synchro n'est jamais bloquante. On envoie les entités
/// modifiées (`dirty`) puis on récupère les changements du serveur.
class SyncService {
  SyncService(this._settings);

  final SettingsService _settings;

  /// URL de base effective : celle saisie par l'utilisateur (Paramètres →
  /// Cloud) sinon l'URL par défaut (Render, cf. AppConstants). Sans slash final.
  String get baseUrl {
    final url = _settings.serverBaseUrl ?? AppConstants.defaultApiBaseUrl;
    return url.endsWith('/') ? url.substring(0, url.length - 1) : url;
  }

  bool _syncing = false;

  /// En-têtes d'authentification : token Firebase si connecté, sinon en-tête de
  /// dev (utile pour tester sans connexion).
  Future<Map<String, String>> _authHeaders() async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      // Évite la page d'avertissement HTML de ngrok (offre gratuite).
      'ngrok-skip-browser-warning': 'true',
    };
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final token = await user.getIdToken();
      if (token != null) headers['Authorization'] = 'Bearer $token';
    } else {
      // Mode dev sans connexion.
      headers['X-Dev-User'] = 'local';
    }
    return headers;
  }

  /// Lance une synchronisation complète (push puis pull). Retourne un résumé.
  Future<SyncResult> syncNow() async {
    if (_syncing) return const SyncResult(pushed: 0, pulled: 0);
    _syncing = true;
    AppLogger.instance.info('Sync: début (serveur $baseUrl)');
    try {
      final buckets = buildSyncBuckets();
      final headers = await _authHeaders();

      final pushed = await _push(buckets, headers);
      final pulled = await _pull(buckets, headers);

      AppLogger.instance
          .info('Sync OK — $pushed envoyé(s), $pulled reçu(s)');
      return SyncResult(pushed: pushed, pulled: pulled);
    } catch (e, st) {
      AppLogger.instance.error('Sync échouée', e, st);
      return SyncResult(pushed: 0, pulled: 0, error: e.toString());
    } finally {
      _syncing = false;
    }
  }

  /// Lit `/api/me/` et renvoie le champ `is_premium` accordé par l'admin.
  /// Renvoie `null` si l'appel échoue (hors-ligne, non connecté, erreur) —
  /// dans ce cas on ne modifie pas l'entitlement local.
  Future<bool?> fetchIsPremium() async {
    try {
      final headers = await _authHeaders();
      final resp = await http
          .get(Uri.parse('$baseUrl/api/me/'), headers: headers)
          .timeout(const Duration(seconds: 10));
      if (resp.statusCode != 200) return null;
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      final v = data['is_premium'];
      return v is bool ? v : null;
    } catch (e) {
      AppLogger.instance.warning('me/is_premium indisponible: $e');
      return null;
    }
  }

  Future<int> _push(List<ISyncBucket> buckets, Map<String, String> headers) async {
    final records = <Map<String, dynamic>>[];
    final byType = <String, List<String>>{};
    for (final b in buckets) {
      for (final item in b.collectDirty()) {
        records.add({
          'entity_type': b.type,
          'entity_id': item.entityId,
          'payload': item.payload,
          'client_updated_at': item.clientUpdatedAt.toIso8601String(),
          'deleted': false,
        });
        (byType[b.type] ??= []).add(item.entityId);
      }
    }
    if (records.isEmpty) return 0;

    final resp = await http.post(
      Uri.parse('$baseUrl/api/sync/push/'),
      headers: headers,
      body: jsonEncode({'records': records}),
    );
    if (resp.statusCode != 200) {
      throw Exception('Push échoué (${resp.statusCode}) : ${resp.body}');
    }
    // Marque les entités envoyées comme synchronisées.
    for (final b in buckets) {
      final ids = byType[b.type];
      if (ids != null) b.markSynced(ids);
    }
    return records.length;
  }

  Future<int> _pull(List<ISyncBucket> buckets, Map<String, String> headers) async {
    final since = _settings.lastSyncAt;
    final uri = Uri.parse('$baseUrl/api/sync/pull/')
        .replace(queryParameters: since == null ? null : {'since': since});

    final resp = await http.get(uri, headers: headers);
    if (resp.statusCode != 200) {
      throw Exception('Pull échoué (${resp.statusCode}) : ${resp.body}');
    }
    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    final records = (data['records'] as List).cast<Map<String, dynamic>>();

    final bucketByType = {for (final b in buckets) b.type: b};
    for (final r in records) {
      final b = bucketByType[r['entity_type']];
      if (b == null) continue;
      b.applyRemote(
        r['entity_id'] as String,
        (r['payload'] as Map).cast<String, dynamic>(),
        r['deleted'] == true,
        DateTime.parse(r['client_updated_at'] as String),
      );
    }

    // Mémorise l'horodatage serveur pour le prochain pull incrémental.
    final serverTime = data['server_time'] as String?;
    if (serverTime != null) await _settings.setLastSyncAt(serverTime);

    return records.length;
  }
}
