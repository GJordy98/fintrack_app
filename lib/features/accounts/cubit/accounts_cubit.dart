import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';

import '../../../data/models/account.dart';
import '../../../data/models/sync_status.dart';
import '../../../data/repositories/account_repository.dart';
import '../../../data/repositories/transaction_repository.dart';

/// Un compte avec son solde courant calculé.
///
/// Les valeurs mutables sont figées en snapshots dans `props` (les objets Hive
/// sont modifiés en place — voir la même note dans GoalView).
class AccountView extends Equatable {
  AccountView(this.account, this.balance)
      : _name = account.name,
        _type = account.type.index,
        _initial = account.initialBalance,
        _currency = account.currencyCode,
        _updatedAt = account.updatedAt;
  final Account account;
  final int balance;
  final String _name;
  final int _type;
  final int _initial;
  final String _currency;
  final DateTime _updatedAt;

  @override
  List<Object?> get props =>
      [account.id, balance, _name, _type, _initial, _currency, _updatedAt];
}

class AccountsState extends Equatable {
  const AccountsState({
    this.loading = true,
    this.accounts = const [],
    this.consolidatedBalance = 0,
  });

  final bool loading;
  final List<AccountView> accounts;

  /// Solde consolidé, dans la devise unique de l'application.
  final int consolidatedBalance;

  AccountsState copyWith({
    bool? loading,
    List<AccountView>? accounts,
    int? consolidatedBalance,
  }) {
    return AccountsState(
      loading: loading ?? this.loading,
      accounts: accounts ?? this.accounts,
      consolidatedBalance: consolidatedBalance ?? this.consolidatedBalance,
    );
  }

  @override
  List<Object?> get props => [loading, accounts, consolidatedBalance];
}

class AccountsCubit extends Cubit<AccountsState> {
  AccountsCubit(this._accounts, this._transactions)
      : super(const AccountsState()) {
    _sub = _accounts.watch().listen((_) => load());
    _txSub = _transactions.watch().listen((_) => load());
    load();
  }

  final AccountRepository _accounts;
  final TransactionRepository _transactions;
  static const _uuid = Uuid();
  late final StreamSubscription _sub;
  late final StreamSubscription _txSub;

  void load() {
    final txs = _transactions.getAll();
    final views = _accounts
        .getActive()
        .map((a) => AccountView(a, _accounts.currentBalance(a, txs)))
        .toList();
    final consolidated = views.fold(0, (s, v) => s + v.balance);
    emit(state.copyWith(
      loading: false,
      accounts: views,
      consolidatedBalance: consolidated,
    ));
  }

  Future<void> addAccount({
    required String name,
    required AccountType type,
    int initialBalance = 0,
    String currencyCode = 'XAF',
    String? provider,
    String? bankName,
    String? bankAccountKind,
    int? colorValue,
    int? iconCodePoint,
  }) async {
    final now = DateTime.now();
    await _accounts.save(Account(
      id: _uuid.v4(),
      name: name.trim(),
      type: type,
      initialBalance: initialBalance,
      currencyCode: currencyCode,
      provider: provider,
      bankName: bankName,
      bankAccountKind: bankAccountKind,
      colorValue: colorValue,
      iconCodePoint: iconCodePoint,
      createdAt: now,
      updatedAt: now,
      syncStatus: SyncStatus.dirty,
    ));
  }

  Future<void> updateAccount(Account account) async {
    account
      ..updatedAt = DateTime.now()
      ..syncStatus = SyncStatus.dirty;
    await _accounts.save(account);
  }

  /// Archive un compte (on ne supprime pas pour préserver l'historique).
  Future<void> archiveAccount(Account account) async {
    account.archived = true;
    await updateAccount(account);
  }

  @override
  Future<void> close() {
    _sub.cancel();
    _txSub.cancel();
    return super.close();
  }
}
