import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app.dart';
import 'core/constants/app_constants.dart';
import 'core/di/service_locator.dart';
import 'core/logging/app_logger.dart';
import 'core/logging/remote_log_uploader.dart';
import 'core/premium/premium_service.dart';
import 'core/utils/money_formatter.dart';
import 'core/notifications/notification_scheduler.dart';
import 'data/hive_config.dart';
import 'data/hive_registrar.dart';
import 'data/migrations.dart';
import 'data/recurring_generator.dart';
import 'data/settings_service.dart';
import 'data/sync/sync_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  // Journal interne + capture globale des erreurs.
  await AppLogger.instance.init();

  // Erreurs du framework Flutter (widgets, rendu…) → journal + Crashlytics.
  final previousOnError = FlutterError.onError;
  FlutterError.onError = (details) {
    AppLogger.instance.error(
      'FlutterError: ${details.exceptionAsString()}',
      details.exception,
      details.stack,
    );
    FirebaseCrashlytics.instance.recordFlutterError(details);
    previousOnError?.call(details);
  };

  // Erreurs asynchrones non capturées ailleurs → journal + Crashlytics (fatal).
  PlatformDispatcher.instance.onError = (error, stack) {
    AppLogger.instance.error('Erreur non capturée', error, stack);
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true;
  };

  await GoogleSignIn.instance.initialize();

  // Formatage FR pour dates et montants.
  await initializeDateFormatting(AppConstants.defaultLocale);

  // Stockage local (source de vérité hors-ligne).
  await Hive.initFlutter();
  HiveRegistrar.registerAdapters();
  await HiveRegistrar.openBoxes();

  // Migration des montants en centimes (une seule fois) avant tout accès.
  final settings = SettingsService(Hive.box(HiveBoxes.settings));
  await runMoneyMigrationV2(settings);
  await runFixedCategoriesMigration(settings);
  await runDefaultAccountsMigration(settings);
  MoneyFormatter.appCurrencyCode = settings.primaryCurrencyCode;

  // Injection de dépendances (repositories + seed).
  await setupServiceLocator();

  // Remontée des erreurs/avertissements au serveur (admin uniquement) : on
  // branche le journal sur l'envoi distant, on rejoue les erreurs déjà
  // capturées au démarrage précoce, puis on vide la file en attente. Les
  // lignes rechargées du fichier de log sont en niveau info (non ré-envoyées).
  final logUploader = sl<RemoteLogUploader>();
  AppLogger.instance.remoteSink = logUploader.enqueue;
  for (final e in AppLogger.instance.entries) {
    if (e.level == LogLevel.warning || e.level == LogLevel.error) {
      logUploader.enqueue(e);
    }
  }
  unawaited(logUploader.flush());

  // Premium : initialise le store (achats/restauration, non bloquant si
  // indisponible) et rafraîchit le déblocage éventuel accordé par l'admin.
  final premium = sl<PremiumService>();
  unawaited(premium.init());
  unawaited(_refreshBackendEntitlement(premium));

  // Génère les transactions récurrentes dues (salaire, loyer...) avant l'UI.
  // La génération automatique est une fonctionnalité premium : les comptes
  // gratuits gardent leurs règles mais elles ne sont pas générées toutes seules.
  if (premium.isPremium) {
    await sl<RecurringGenerator>().generateDue();
  }

  runApp(const FinTrackApp());

  // Notifications locales : demande la permission et programme les rappels
  // (non bloquant pour l'affichage).
  unawaited(sl<NotificationScheduler>().start());
}

/// Interroge `/api/me/` pour appliquer un éventuel déblocage premium accordé
/// par l'admin (comptes de test). Silencieux si hors-ligne / non connecté.
Future<void> _refreshBackendEntitlement(PremiumService premium) async {
  final granted = await sl<SyncService>().fetchIsPremium();
  if (granted != null) {
    await premium.setBackendGranted(granted);
  }
}
