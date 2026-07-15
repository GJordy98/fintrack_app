import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'premium_service.dart';

class PremiumState extends Equatable {
  const PremiumState({
    required this.isPremium,
    required this.storeAvailable,
    required this.price,
    this.purchasePending = false,
  });

  final bool isPremium;
  final bool storeAvailable;
  final String price;
  final bool purchasePending;

  PremiumState copyWith({
    bool? isPremium,
    bool? storeAvailable,
    String? price,
    bool? purchasePending,
  }) {
    return PremiumState(
      isPremium: isPremium ?? this.isPremium,
      storeAvailable: storeAvailable ?? this.storeAvailable,
      price: price ?? this.price,
      purchasePending: purchasePending ?? this.purchasePending,
    );
  }

  @override
  List<Object?> get props => [isPremium, storeAvailable, price, purchasePending];
}

/// Expose le statut premium à tout l'arbre de widgets et pilote les actions
/// d'achat/restauration/override. S'abonne au flux d'entitlement du service.
class PremiumCubit extends Cubit<PremiumState> {
  PremiumCubit(this._service)
      : super(PremiumState(
          isPremium: _service.isPremium,
          storeAvailable: _service.storeAvailable,
          price: _service.displayPrice,
        )) {
    _sub = _service.entitlementStream.listen((_) => _refresh());
  }

  final PremiumService _service;
  late final StreamSubscription<bool> _sub;

  bool get isPremium => state.isPremium;

  void _refresh() {
    if (isClosed) return;
    emit(state.copyWith(
      isPremium: _service.isPremium,
      storeAvailable: _service.storeAvailable,
      price: _service.displayPrice,
      purchasePending: false,
    ));
  }

  /// Lance l'achat. Retourne `false` si le produit est indisponible (paywall
  /// affiche alors un message d'indisponibilité).
  Future<bool> buy() async {
    emit(state.copyWith(purchasePending: true));
    final ok = await _service.buy();
    if (!ok && !isClosed) emit(state.copyWith(purchasePending: false));
    return ok;
  }

  Future<void> restore() => _service.restore();

  Future<void> setDevOverride(bool v) => _service.setDevOverride(v);

  @override
  Future<void> close() {
    _sub.cancel();
    return super.close();
  }
}
