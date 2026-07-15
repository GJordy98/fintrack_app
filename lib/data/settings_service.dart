import 'package:hive/hive.dart';

/// Préférences simples de l'application, stockées dans une boîte clé/valeur.
/// (Sera étendu au module Paramètres complet en Phase 7.)
class SettingsService {
  SettingsService(this._box);

  final Box _box;

  static const _kDailyEnabled = 'daily_reminder_enabled';
  static const _kDailyHour = 'daily_reminder_hour';
  static const _kDailyMinute = 'daily_reminder_minute';
  static const _kPermissionRequested = 'notif_permission_requested';
  static const _kMonthlySavingsTarget = 'monthly_savings_target';
  static const _kPrimaryCurrency = 'primary_currency';
  static const _kMoneyMigratedV2 = 'money_migrated_v2';
  static const _kFixedCategoriesV1 = 'fixed_categories_v1';
  static const _kDefaultAccountsV2 = 'default_accounts_v2';
  static const _kLockEnabled = 'lock_enabled';
  static const _kBiometricEnabled = 'biometric_enabled';
  static const _kLastSyncAt = 'last_sync_at';
  static const _kServerBaseUrl = 'server_base_url';
  static const _kPremiumPurchaseActive = 'premium_purchase_active';
  static const _kPremiumBackendGranted = 'premium_backend_granted';
  static const _kPremiumDevOverride = 'premium_dev_override';
  static const _kAnimMonth = 'anim_quota_month';
  static const _kAnimCount = 'anim_quota_count';

  bool get dailyReminderEnabled =>
      _box.get(_kDailyEnabled, defaultValue: true) as bool;
  Future<void> setDailyReminderEnabled(bool v) =>
      _box.put(_kDailyEnabled, v);

  int get dailyReminderHour =>
      _box.get(_kDailyHour, defaultValue: 20) as int;
  int get dailyReminderMinute =>
      _box.get(_kDailyMinute, defaultValue: 0) as int;
  Future<void> setDailyReminderTime(int hour, int minute) async {
    await _box.put(_kDailyHour, hour);
    await _box.put(_kDailyMinute, minute);
  }

  bool get permissionRequested =>
      _box.get(_kPermissionRequested, defaultValue: false) as bool;
  Future<void> setPermissionRequested(bool v) =>
      _box.put(_kPermissionRequested, v);

  /// Épargne mensuelle « libre » que l'utilisateur veut mettre de côté chaque
  /// mois (en plus de l'épargne engagée par ses objectifs).
  int get monthlySavingsTarget =>
      _box.get(_kMonthlySavingsTarget, defaultValue: 0) as int;
  Future<void> setMonthlySavingsTarget(int v) =>
      _box.put(_kMonthlySavingsTarget, v);

  /// Devise principale de l'app (budgets, objectifs, planning, prévisions).
  String get primaryCurrencyCode =>
      _box.get(_kPrimaryCurrency, defaultValue: 'XAF') as String;
  Future<void> setPrimaryCurrencyCode(String code) =>
      _box.put(_kPrimaryCurrency, code);

  bool get moneyMigratedV2 =>
      _box.get(_kMoneyMigratedV2, defaultValue: false) as bool;
  Future<void> setMoneyMigratedV2(bool v) => _box.put(_kMoneyMigratedV2, v);

  bool get fixedCategoriesMigrated =>
      _box.get(_kFixedCategoriesV1, defaultValue: false) as bool;
  Future<void> setFixedCategoriesMigrated(bool v) =>
      _box.put(_kFixedCategoriesV1, v);

  bool get defaultAccountsMigrated =>
      _box.get(_kDefaultAccountsV2, defaultValue: false) as bool;
  Future<void> setDefaultAccountsMigrated(bool v) =>
      _box.put(_kDefaultAccountsV2, v);

  /// Verrouillage de l'app (code PIN) activé.
  bool get lockEnabled => _box.get(_kLockEnabled, defaultValue: false) as bool;
  Future<void> setLockEnabled(bool v) => _box.put(_kLockEnabled, v);

  /// Déverrouillage par biométrie autorisé.
  bool get biometricEnabled =>
      _box.get(_kBiometricEnabled, defaultValue: false) as bool;
  Future<void> setBiometricEnabled(bool v) => _box.put(_kBiometricEnabled, v);

  /// Horodatage (ISO) de la dernière synchronisation cloud réussie.
  String? get lastSyncAt => _box.get(_kLastSyncAt) as String?;
  Future<void> setLastSyncAt(String? v) =>
      v == null ? _box.delete(_kLastSyncAt) : _box.put(_kLastSyncAt, v);

  /// URL du serveur de synchro saisie par l'utilisateur (ex: tunnel ngrok du
  /// moment). Vide → on retombe sur l'URL par défaut compilée dans l'app.
  String? get serverBaseUrl {
    final v = _box.get(_kServerBaseUrl) as String?;
    return (v == null || v.trim().isEmpty) ? null : v.trim();
  }

  Future<void> setServerBaseUrl(String? v) =>
      (v == null || v.trim().isEmpty)
          ? _box.delete(_kServerBaseUrl)
          : _box.put(_kServerBaseUrl, v.trim());

  // --- Premium (freemium) ---------------------------------------------------
  // L'accès premium est accordé si l'UNE de ces trois sources est vraie :
  //  - un achat Google Play validé (premiumPurchaseActive),
  //  - un déblocage accordé par l'admin côté serveur (premiumBackendGranted),
  //  - un override de test/dev (premiumDevOverride).
  // Voir PremiumService pour la logique de fusion.

  /// Achat Google Play actif (validé localement).
  bool get premiumPurchaseActive =>
      _box.get(_kPremiumPurchaseActive, defaultValue: false) as bool;
  Future<void> setPremiumPurchaseActive(bool v) =>
      _box.put(_kPremiumPurchaseActive, v);

  /// Premium accordé par l'admin (champ is_premium renvoyé par /api/me/).
  bool get premiumBackendGranted =>
      _box.get(_kPremiumBackendGranted, defaultValue: false) as bool;
  Future<void> setPremiumBackendGranted(bool v) =>
      _box.put(_kPremiumBackendGranted, v);

  /// Override manuel (comptes de test / debug). Débloque tout sans achat.
  bool get premiumDevOverride =>
      _box.get(_kPremiumDevOverride, defaultValue: false) as bool;
  Future<void> setPremiumDevOverride(bool v) =>
      _box.put(_kPremiumDevOverride, v);

  // --- Quota d'animations mensuel (palier gratuit) -------------------------
  // Le compteur se réinitialise automatiquement quand le mois change
  // ([monthKey] au format 'YYYY-MM').

  /// Nombre d'animations déjà jouées pour le mois [monthKey].
  int animationsUsedThisMonth(String monthKey) {
    if (_box.get(_kAnimMonth) != monthKey) return 0;
    return _box.get(_kAnimCount, defaultValue: 0) as int;
  }

  /// Incrémente le compteur d'animations du mois [monthKey] (réinitialise si
  /// le mois a changé).
  Future<void> recordAnimationShown(String monthKey) async {
    if (_box.get(_kAnimMonth) != monthKey) {
      await _box.put(_kAnimMonth, monthKey);
      await _box.put(_kAnimCount, 1);
    } else {
      await _box.put(_kAnimCount, animationsUsedThisMonth(monthKey) + 1);
    }
  }
}
