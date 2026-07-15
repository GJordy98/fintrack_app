import 'package:uuid/uuid.dart';

import '../models/account.dart';
import '../repositories/account_repository.dart';

/// Définition d'un compte prédéfini.
class DefaultAccountDef {
  const DefaultAccountDef(this.name, this.type, {this.provider});
  final String name;
  final AccountType type;
  final String? provider;
}

/// Comptes proposés par défaut (moyens de paiement courants au Cameroun).
/// Disponibles immédiatement dans le champ « Compte » des transactions.
const kDefaultAccounts = <DefaultAccountDef>[
  DefaultAccountDef('Espèces', AccountType.cash),
  DefaultAccountDef('Orange Money', AccountType.mobileMoney,
      provider: 'Orange Money'),
  DefaultAccountDef('MTN MoMo', AccountType.mobileMoney, provider: 'MTN MoMo'),
  DefaultAccountDef('Compte bancaire', AccountType.bank),
];

/// Crée les comptes par défaut au tout premier lancement pour que
/// l'utilisateur puisse saisir une transaction immédiatement (module 3.1).
class DefaultAccountSeeder {
  DefaultAccountSeeder(this._repo);

  final AccountRepository _repo;
  static const _uuid = Uuid();

  Future<void> seedIfEmpty() async {
    if (_repo.count > 0) return;
    final now = DateTime.now();
    for (final def in kDefaultAccounts) {
      await _repo.save(Account(
        id: _uuid.v4(),
        name: def.name,
        type: def.type,
        provider: def.provider,
        initialBalance: 0,
        createdAt: now,
        updatedAt: now,
      ));
    }
  }
}
