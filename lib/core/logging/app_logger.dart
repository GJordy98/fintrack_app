import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

enum LogLevel { debug, info, warning, error }

/// Une entrée de journal.
class LogEntry {
  LogEntry(this.time, this.level, this.message);
  final DateTime time;
  final LogLevel level;
  final String message;

  String format() {
    final t = time.toIso8601String().split('.').first.replaceFirst('T', ' ');
    return '$t  ${level.name.toUpperCase().padRight(7)} $message';
  }
}

/// Journal interne de l'application.
///
/// Capture les erreurs et événements clés en mémoire (pour l'affichage) et les
/// persiste dans un fichier (pour survivre à un redémarrage et être partagé).
/// Utilisable partout via [AppLogger.instance], y compris avant le démarrage
/// de l'injection de dépendances.
class AppLogger {
  AppLogger._();
  static final AppLogger instance = AppLogger._();

  static const int _maxEntries = 800; // taille du tampon mémoire
  static const int _maxFileBytes = 1024 * 1024; // 1 Mo : au-delà, on repart

  final List<LogEntry> _buffer = [];
  File? _file;
  bool _ready = false;

  /// Récepteur distant optionnel : reçoit les entrées à faire remonter au
  /// serveur (admin). Branché après l'initialisation du reste de l'app. Ne
  /// doit jamais lever d'exception (l'envoi est « au mieux », non bloquant).
  void Function(LogEntry entry)? remoteSink;

  /// Prépare le fichier de log. À appeler une fois au démarrage (non bloquant
  /// pour l'app : en cas d'échec, on continue en mémoire seule).
  Future<void> init() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/fintrack.log');
      if (await file.exists()) {
        // Purge si le fichier devient trop gros ; sinon on recharge la fin
        // pour garder l'historique entre deux lancements.
        if (await file.length() > _maxFileBytes) {
          await file.writeAsString('');
        } else {
          final lines = await file.readAsLines();
          for (final l in lines.length > _maxEntries
              ? lines.sublist(lines.length - _maxEntries)
              : lines) {
            _buffer.add(LogEntry(DateTime.now(), LogLevel.info, l));
          }
        }
      }
      _file = file;
      _ready = true;
      info('— Journal démarré —');
    } catch (e) {
      debugPrint('AppLogger init échoué : $e');
    }
  }

  void debug(String message) => _add(LogLevel.debug, message);
  void info(String message) => _add(LogLevel.info, message);
  void warning(String message) => _add(LogLevel.warning, message);

  void error(String message, [Object? error, StackTrace? stack]) {
    final b = StringBuffer(message);
    if (error != null) b.write(' | $error');
    if (stack != null) b.write('\n$stack');
    _add(LogLevel.error, b.toString());
  }

  void _add(LogLevel level, String message) {
    final entry = LogEntry(DateTime.now(), level, message);
    _buffer.add(entry);
    if (_buffer.length > _maxEntries) _buffer.removeAt(0);
    if (kDebugMode) debugPrint('[${level.name.toUpperCase()}] $message');
    if (_ready && _file != null) {
      // Écriture asynchrone « au mieux » : on ne bloque jamais l'appelant.
      _file!
          .writeAsString('${entry.format()}\n', mode: FileMode.append)
          .ignore();
    }
    // Remontée serveur (admin) des avertissements/erreurs uniquement, pour ne
    // pas noyer le dashboard sous les logs debug/info.
    final sink = remoteSink;
    if (sink != null &&
        (level == LogLevel.warning || level == LogLevel.error)) {
      try {
        sink(entry);
      } catch (_) {
        // L'échec de la remontée ne doit jamais affecter l'app.
      }
    }
  }

  /// Copie des entrées en mémoire (plus récentes en dernier).
  List<LogEntry> get entries => List.unmodifiable(_buffer);

  /// Chemin du fichier de log (pour le partage), null si non prêt.
  String? get filePath => _file?.path;

  Future<void> clear() async {
    _buffer.clear();
    if (_file != null) {
      try {
        await _file!.writeAsString('');
      } catch (_) {}
    }
    info('— Journal vidé —');
  }
}
