/// Configuration du module Premium (freemium).
///
/// Périmètre choisi avec l'utilisatrice :
///  - PREMIUM : Prévisions & simulateur d'achat, Transactions récurrentes
///    automatiques, Export CSV/PDF, + quotas débloqués (objectifs, comptes,
///    catégories perso illimités).
///  - GRATUIT : tout le reste, y compris la sauvegarde/sync cloud, les
///    statistiques de base et la sécurité (PIN/biométrie).
///
/// Le PRIX réel et la période de facturation (1 200 FCFA / 2 mois) se
/// configurent dans la Google Play Console pour l'ID d'abonnement ci-dessous ;
/// l'app affiche le prix localisé renvoyé par le store, avec repli sur le
/// libellé [priceFallback].
class PremiumConfig {
  PremiumConfig._();

  /// Identifiant de l'abonnement dans la Play Console (à créer côté console).
  /// Abonnement avec un plan de base « tous les 2 mois » à 1 200 FCFA.
  static const String subscriptionId = 'fintrack_premium_2m';

  /// Ensemble des identifiants produit interrogés auprès du store.
  static const Set<String> productIds = {subscriptionId};

  /// Affiché tant que le store n'a pas renvoyé de prix localisé.
  static const String priceFallback = '1 200 FCFA / 2 mois';

  // --- Quotas du palier gratuit --------------------------------------------
  // Débloqués (illimités) en premium. Ajustables ici en une ligne.

  /// Nombre maximal d'objectifs pour un compte gratuit.
  static const int freeGoalLimit = 2;

  /// Nombre maximal de comptes pour un compte gratuit.
  /// Note : l'app seed 4 comptes par défaut ; ils sont conservés
  /// (« grandfathering ») et ce quota ne bloque que l'ajout de NOUVEAUX comptes.
  static const int freeAccountLimit = 3;

  /// Nombre maximal de catégories personnalisées (actives) pour un compte
  /// gratuit. Au-delà, la création passe par le paywall (page Catégories).
  static const int freeCustomCategoryLimit = 2;

  /// Nombre d'animations de feedback (réussite/encouragement d'objectif)
  /// autorisées par mois pour un compte gratuit. Illimité en premium.
  static const int freeAnimationsPerMonth = 4;

  /// Avantages listés sur l'écran de paywall.
  static const List<String> benefits = [
    'Prévisions de solde & simulateur d\'achat',
    'Transactions récurrentes automatiques (salaire, loyer…)',
    'Export CSV & PDF de tes données',
    'Objectifs illimités',
    'Comptes illimités',
    'Animations de réussite illimitées',
    'Soutiens le développement de FinTrack ❤️',
  ];
}
