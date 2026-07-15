/// Constantes globales de l'application FinTrack.
class AppConstants {
  AppConstants._();

  static const String appName = 'FinTrack';

  /// Version de l'app envoyée avec les logs admin. À garder en phase avec le
  /// champ `version:` du pubspec.yaml (surchargeable au build via
  /// `--dart-define=FINTRACK_APP_VERSION=x.y.z`).
  static const String appVersion = String.fromEnvironment(
    'FINTRACK_APP_VERSION',
    defaultValue: '1.0.0+1',
  );

  /// URL du serveur backend par défaut (sauvegarde/synchro cloud + déblocage
  /// premium). Pointe sur l'hébergement Render. Surchargeable :
  ///  - au build : `--dart-define=FINTRACK_API_URL=https://mon-serveur`,
  ///  - à l'exécution : Paramètres → Cloud → URL du serveur.
  /// ⚠️ Si Render assigne un sous-domaine différent (suffixe aléatoire quand
  /// le nom est déjà pris), remplacer l'URL ci-dessous et rebuild.
  static const String defaultApiBaseUrl = String.fromEnvironment(
    'FINTRACK_API_URL',
    defaultValue: 'https://fintrack-backend.onrender.com',
  );

  /// Devise par défaut (extensible — voir module 3.8 Paramètres).
  static const String defaultCurrencyCode = 'XAF';
  static const String defaultCurrencySymbol = 'FCFA';

  /// Locale par défaut pour le formatage des montants et des dates.
  static const String defaultLocale = 'fr_FR';
}
