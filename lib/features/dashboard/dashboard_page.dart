import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../core/di/service_locator.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/money_formatter.dart';
import '../../core/utils/visuals.dart';
import '../../data/models/transaction.dart';
import '../../data/repositories/category_repository.dart';
import '../accounts/accounts_page.dart';
import '../accounts/cubit/accounts_cubit.dart';
import '../transactions/cubit/transactions_cubit.dart';
import '../transactions/widgets/transaction_editor_sheet.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Accueil')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          _BalanceCard(),
          SizedBox(height: 16),
          _AccountsStrip(),
          SizedBox(height: 16),
          _RecentTransactions(),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showTransactionEditor(context),
        icon: const Icon(Icons.add),
        label: const Text('Ajouter'),
      ),
    );
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return BlocBuilder<AccountsCubit, AccountsState>(
      builder: (context, state) {
        return Card(
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AccountsPage()),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Solde consolidé',
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            )),
                        const SizedBox(height: 8),
                        Text(
                          MoneyFormatter.format(state.consolidatedBalance),
                          style: theme.textTheme.headlineMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _AccountsStrip extends StatelessWidget {
  const _AccountsStrip();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AccountsCubit, AccountsState>(
      builder: (context, state) {
        if (state.accounts.isEmpty) return const SizedBox.shrink();
        return SizedBox(
          height: 96,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: state.accounts.length,
            separatorBuilder: (_, i) => const SizedBox(width: 12),
            itemBuilder: (context, i) {
              final v = state.accounts[i];
              return Card(
                child: Container(
                  width: 160,
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(children: [
                        Icon(v.account.type.icon, size: 18),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(v.account.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.labelLarge),
                        ),
                      ]),
                      Text(
                        MoneyFormatter.format(v.balance),
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _RecentTransactions extends StatelessWidget {
  const _RecentTransactions();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TransactionsCubit, TransactionsState>(
      builder: (context, state) {
        final recent = state.all.take(6).toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Transactions récentes',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            if (recent.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text(
                    'Aucune transaction pour l\'instant.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              )
            else
              ...recent.map((t) => _MiniTxTile(tx: t)),
          ],
        );
      },
    );
  }
}

class _MiniTxTile extends StatelessWidget {
  const _MiniTxTile({required this.tx});
  final AppTransaction tx;

  @override
  Widget build(BuildContext context) {
    final category = tx.categoryId == null
        ? null
        : sl<CategoryRepository>().getById(tx.categoryId!);
    final isIncome = tx.type == TransactionType.income;
    final color = isIncome ? AppTheme.income : AppTheme.expense;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      leading: CircleAvatar(
        backgroundColor: (category?.color ?? color).withValues(alpha: 0.15),
        child: Icon(
          category?.icon ?? (isIncome ? Icons.south_west : Icons.north_east),
          color: category?.color ?? color,
          size: 20,
        ),
      ),
      title: Text(category?.name ?? (isIncome ? 'Revenu' : 'Dépense')),
      subtitle: Text(DateFormat('d MMM', 'fr_FR').format(tx.date)),
      trailing: Text(
        MoneyFormatter.formatSigned(tx.signedAmount),
        style: TextStyle(color: color, fontWeight: FontWeight.bold),
      ),
      onTap: () => showTransactionEditor(context, existing: tx),
    );
  }
}
