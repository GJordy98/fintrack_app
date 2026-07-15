/// Registre central des identifiants Hive (typeId) et des noms de boîtes.
///
/// IMPORTANT : un `typeId` ne doit JAMAIS être réutilisé ni changé une fois
/// des données écrites en production — sinon corruption des données existantes.
/// Modèles : 1–19. Enums : 20–39.
class HiveTypeIds {
  HiveTypeIds._();

  // --- Modèles (1–19) ---
  static const int account = 1;
  static const int category = 2;
  static const int transaction = 3;
  static const int recurringRule = 4;
  static const int budget = 5;
  static const int goal = 6;
  static const int goalStatusHistory = 7;
  static const int contribution = 8;
  static const int contributionEvent = 9;
  static const int debt = 10;
  static const int debtRepayment = 11;
  static const int incomeProfile = 12;
  static const int dayBudget = 13;
  static const int fixedCharge = 14;

  // --- Enums (20–39) ---
  static const int syncStatus = 20;
  static const int accountType = 21;
  static const int categoryKind = 22;
  static const int transactionType = 23;
  static const int recurrenceFrequency = 24;
  static const int goalStatus = 26;
  static const int contributionEventKind = 27;
  static const int eventStatus = 28;
  static const int debtDirection = 29;
  static const int debtStatus = 30;
  static const int repaymentStatus = 31;
}

/// Noms des boîtes Hive (une par agrégat).
class HiveBoxes {
  HiveBoxes._();

  static const String accounts = 'accounts';
  static const String categories = 'categories';
  static const String transactions = 'transactions';
  static const String recurringRules = 'recurring_rules';
  static const String budgets = 'budgets';
  static const String goals = 'goals';
  static const String goalStatusHistory = 'goal_status_history';
  static const String contributions = 'contributions';
  static const String contributionEvents = 'contribution_events';
  static const String debts = 'debts';
  static const String debtRepayments = 'debt_repayments';
  static const String incomeProfiles = 'income_profiles';
  static const String dayBudgets = 'day_budgets';
  static const String fixedCharges = 'fixed_charges';

  /// Boîte clé/valeur non typée pour les préférences.
  static const String settings = 'app_settings';

  /// File d'attente non typée des logs à remonter au serveur (admin). Persiste
  /// les entrées non encore envoyées pour survivre au hors-ligne / redémarrage.
  static const String pendingLogs = 'pending_logs';
}
