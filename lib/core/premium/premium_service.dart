import 'dart:async';

import 'package:in_app_purchase/in_app_purchase.dart';

import '../../data/settings_service.dart';
import '../logging/app_logger.dart';
import 'premium_config.dart';

/// Source de vérité de l'accès premium (freemium).
///
/// L'accès est accordé si l'UNE de ces trois sources est vraie :
///  1. [SettingsService.premiumPurchaseActive] — achat Google Play validé
///     localement (vérification serveur prévue plus tard) ;
///  2. [SettingsService.premiumBackendGranted] — déblocage accordé par l'admin
///     (champ `is_premium` renvoyé par `/api/me/`) ; sert aux comptes de test ;
///  3. [SettingsService.premiumDevOverride] — override manuel (debug).
///
/// Le service encapsule `in_app_purchase` et dégrade proprement quand le store
/// est indisponible (émulateur, pas de Play Services) : l'entitlement continue
/// de fonctionner via les sources serveur/override.
class PremiumService {
  PremiumService(this._settings, {InAppPurchase? iap}) : _iapOverride = iap;

  final SettingsService _settings;

  // Résolu paresseusement : évite de toucher au plugin natif tant qu'aucune
  // opération de store n'est demandée (utile en test unitaire).
  final InAppPurchase? _iapOverride;
  InAppPurchase get _iap => _iapOverride ?? InAppPurchase.instance;

  StreamSubscription<List<PurchaseDetails>>? _sub;
  final StreamController<bool> _controller = StreamController<bool>.broadcast();

  /// Émet le statut premium à chaque changement (achat, restauration,
  /// déblocage serveur, override).
  Stream<bool> get entitlementStream => _controller.stream;

  List<ProductDetails> _products = const [];
  List<ProductDetails> get products => _products;

  bool _storeAvailable = false;
  bool get storeAvailable => _storeAvailable;

  /// Vrai si l'utilisateur a accès aux fonctionnalités premium.
  bool get isPremium =>
      _settings.premiumPurchaseActive ||
      _settings.premiumBackendGranted ||
      _settings.premiumDevOverride;

  /// Prix localisé renvoyé par le store, sinon `null`.
  String? get storePrice => _products.isNotEmpty ? _products.first.price : null;

  /// Prix à afficher : store si connu, sinon libellé de repli.
  String get displayPrice => storePrice ?? PremiumConfig.priceFallback;

  Future<void> init() async {
    try {
      _storeAvailable = await _iap.isAvailable();
    } catch (e, s) {
      AppLogger.instance.error('IAP: isAvailable a échoué', e, s);
      _storeAvailable = false;
    }
    if (!_storeAvailable) return;

    _sub = _iap.purchaseStream.listen(
      _onPurchaseUpdates,
      onError: (Object e, StackTrace s) =>
          AppLogger.instance.error('IAP: purchaseStream', e, s),
    );
    await loadProducts();
    // Restaure les achats passés pour rétablir l'entitlement au démarrage.
    try {
      await _iap.restorePurchases();
    } catch (e, s) {
      AppLogger.instance.error('IAP: restore au démarrage', e, s);
    }
  }

  Future<void> loadProducts() async {
    if (!_storeAvailable) return;
    try {
      final resp = await _iap.queryProductDetails(PremiumConfig.productIds);
      if (resp.error != null) {
        AppLogger.instance.warning(
          'IAP: queryProductDetails erreur ${resp.error!.message}',
        );
      }
      if (resp.notFoundIDs.isNotEmpty) {
        AppLogger.instance.warning(
          'IAP: produits introuvables ${resp.notFoundIDs.join(",")} '
          '(non configurés dans la Play Console ?)',
        );
      }
      _products = resp.productDetails;
    } catch (e, s) {
      AppLogger.instance.error('IAP: queryProductDetails', e, s);
    }
  }

  /// Lance le flux d'achat. Retourne `false` si le produit est indisponible.
  Future<bool> buy() async {
    if (!_storeAvailable) return false;
    if (_products.isEmpty) {
      await loadProducts();
      if (_products.isEmpty) return false;
    }
    final param = PurchaseParam(productDetails: _products.first);
    try {
      // Les abonnements passent aussi par buyNonConsumable avec in_app_purchase.
      return await _iap.buyNonConsumable(purchaseParam: param);
    } catch (e, s) {
      AppLogger.instance.error('IAP: achat premium', e, s);
      return false;
    }
  }

  /// Restaure les achats (bouton « Restaurer » du paywall/paramètres).
  Future<void> restore() async {
    if (!_storeAvailable) return;
    try {
      await _iap.restorePurchases();
    } catch (e, s) {
      AppLogger.instance.error('IAP: restore', e, s);
    }
  }

  Future<void> _onPurchaseUpdates(List<PurchaseDetails> purchases) async {
    var active = _settings.premiumPurchaseActive;
    for (final p in purchases) {
      if (p.productID != PremiumConfig.subscriptionId) continue;
      if (p.status == PurchaseStatus.purchased ||
          p.status == PurchaseStatus.restored) {
        // Vérification LOCALE (le reçu Play suffit ici ; vérif serveur plus
        // tard via Google Play Developer API).
        active = true;
      } else if (p.status == PurchaseStatus.error) {
        AppLogger.instance.warning('IAP: achat en erreur ${p.error?.message}');
      }
      if (p.pendingCompletePurchase) {
        try {
          await _iap.completePurchase(p);
        } catch (e, s) {
          AppLogger.instance.error('IAP: completePurchase', e, s);
        }
      }
    }
    await _setPurchaseActive(active);
  }

  Future<void> _setPurchaseActive(bool v) async {
    if (_settings.premiumPurchaseActive != v) {
      await _settings.setPremiumPurchaseActive(v);
    }
    _controller.add(isPremium);
  }

  /// Applique le déblocage serveur (is_premium de `/api/me/`).
  Future<void> setBackendGranted(bool v) async {
    if (_settings.premiumBackendGranted != v) {
      await _settings.setPremiumBackendGranted(v);
      _controller.add(isPremium);
    }
  }

  /// Active/désactive l'override de test (débloque tout sans achat).
  Future<void> setDevOverride(bool v) async {
    await _settings.setPremiumDevOverride(v);
    _controller.add(isPremium);
  }

  void dispose() {
    _sub?.cancel();
    _controller.close();
  }
}
