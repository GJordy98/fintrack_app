import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/premium/premium_config.dart';
import '../../core/utils/money_formatter.dart';
import '../../core/utils/visuals.dart';
import '../../data/models/account.dart';
import '../premium/premium_gate.dart';
import 'cubit/accounts_cubit.dart';
import 'widgets/account_editor_sheet.dart';

/// Sous-titre d'un compte : type + détails (opérateur / banque).
String _accountSubtitle(Account a) {
  final parts = <String>[a.type.label];
  if (a.provider != null && a.provider!.isNotEmpty) parts.add(a.provider!);
  if (a.bankName != null && a.bankName!.isNotEmpty) parts.add(a.bankName!);
  if (a.bankAccountKind != null && a.bankAccountKind!.isNotEmpty) {
    parts.add(a.bankAccountKind!);
  }
  return parts.join(' • ');
}

class AccountsPage extends StatelessWidget {
  const AccountsPage({super.key});

  /// Ouvre l'éditeur de compte ; au-delà du quota gratuit, passe par le paywall.
  Future<void> _addAccount(BuildContext context) async {
    final overQuota = context.read<AccountsCubit>().state.accounts.length >=
        PremiumConfig.freeAccountLimit;
    if (overQuota &&
        !await requirePremium(context, feature: 'Comptes illimités')) {
      return;
    }
    if (context.mounted) showAccountEditor(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Comptes')),
      body: BlocBuilder<AccountsCubit, AccountsState>(
        builder: (context, state) {
          if (state.loading) {
            return const Center(child: CircularProgressIndicator());
          }
          return ListView(
            padding: const EdgeInsets.only(bottom: 96),
            children: [
              Card(
                margin: const EdgeInsets.all(16),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Solde consolidé',
                          style: Theme.of(context).textTheme.labelLarge),
                      const SizedBox(height: 6),
                      Text(
                        MoneyFormatter.format(state.consolidatedBalance),
                        style: Theme.of(context)
                            .textTheme
                            .headlineSmall
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
              ...state.accounts.map((v) => ListTile(
                    leading: CircleAvatar(child: Icon(v.account.type.icon)),
                    title: Text(v.account.name),
                    subtitle: Text(_accountSubtitle(v.account)),
                    trailing: Text(
                      MoneyFormatter.format(v.balance),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    onTap: () =>
                        showAccountEditor(context, existing: v.account),
                  )),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addAccount(context),
        icon: const Icon(Icons.add),
        label: const Text('Compte'),
      ),
    );
  }
}
