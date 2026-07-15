import '../models/account.dart';
import '../models/transaction.dart';
import 'base_repository.dart';

class AccountRepository extends BaseRepository<Account> {
  AccountRepository(super.box);

  @override
  String keyOf(Account entity) => entity.id;

  List<Account> getActive() =>
      getAll().where((a) => !a.archived).toList();

  /// Solde courant d'un compte = solde initial + somme signée des transactions.
  int currentBalance(Account account, Iterable<AppTransaction> transactions) {
    var balance = account.initialBalance;
    for (final t in transactions) {
      if (t.accountId == account.id) balance += t.signedAmount;
    }
    return balance;
  }

  /// Solde consolidé de tous les comptes actifs.
  int consolidatedBalance(Iterable<AppTransaction> transactions) {
    final txList = transactions.toList();
    var total = 0;
    for (final a in getActive()) {
      total += currentBalance(a, txList);
    }
    return total;
  }
}
