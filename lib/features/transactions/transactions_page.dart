import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../core/di/service_locator.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/money_formatter.dart';
import '../../core/utils/visuals.dart';
import '../../data/models/transaction.dart';
import '../../data/repositories/account_repository.dart';
import '../../data/repositories/category_repository.dart';
import 'cubit/transactions_cubit.dart';
import 'widgets/filter_sheet.dart';
import 'widgets/transaction_editor_sheet.dart';

class TransactionsPage extends StatelessWidget {
  const TransactionsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Transactions'),
        actions: [
          BlocBuilder<TransactionsCubit, TransactionsState>(
            buildWhen: (a, b) => a.filter != b.filter,
            builder: (context, state) {
              return IconButton(
                tooltip: 'Filtrer',
                onPressed: () => showFilterSheet(context),
                icon: Badge(
                  isLabelVisible: state.filter.isActive,
                  child: const Icon(Icons.filter_list),
                ),
              );
            },
          ),
        ],
      ),
      body: BlocBuilder<TransactionsCubit, TransactionsState>(
        builder: (context, state) {
          if (state.loading) {
            return const Center(child: CircularProgressIndicator());
          }
          final items = state.visible;
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Rechercher (note, montant)',
                    prefixIcon: const Icon(Icons.search),
                    isDense: true,
                    suffixIcon: state.filter.query.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () => context
                                .read<TransactionsCubit>()
                                .setFilter(state.filter.copyWith(query: '')),
                          ),
                  ),
                  onChanged: (v) => context
                      .read<TransactionsCubit>()
                      .setFilter(state.filter.copyWith(query: v)),
                ),
              ),
              if (items.isEmpty)
                Expanded(child: _EmptyState(hasFilter: state.filter.isActive))
              else
                Expanded(child: _TransactionList(items: items)),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showTransactionEditor(context),
        icon: const Icon(Icons.add),
        label: const Text('Ajouter'),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.hasFilter});
  final bool hasFilter;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.receipt_long_outlined,
              size: 56, color: theme.colorScheme.outline),
          const SizedBox(height: 12),
          Text(
            hasFilter
                ? 'Aucune transaction pour ce filtre'
                : 'Aucune transaction.\nAppuie sur « Ajouter » pour commencer.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class _TransactionList extends StatelessWidget {
  const _TransactionList({required this.items});
  final List<AppTransaction> items;

  @override
  Widget build(BuildContext context) {
    // Regroupement par jour.
    final groups = <String, List<AppTransaction>>{};
    for (final t in items) {
      final key = DateFormat('EEEE d MMMM yyyy', 'fr_FR').format(t.date);
      groups.putIfAbsent(key, () => []).add(t);
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: 96),
      children: [
        for (final entry in groups.entries) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text(
              entry.key,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
          ...entry.value.map((t) => _TransactionTile(tx: t)),
        ],
      ],
    );
  }
}

class _TransactionTile extends StatelessWidget {
  const _TransactionTile({required this.tx});
  final AppTransaction tx;

  @override
  Widget build(BuildContext context) {
    final category =
        tx.categoryId == null ? null : sl<CategoryRepository>().getById(tx.categoryId!);
    final account = sl<AccountRepository>().getById(tx.accountId);
    final isIncome = tx.type == TransactionType.income;
    final color = isIncome ? AppTheme.income : AppTheme.expense;

    return Dismissible(
      key: ValueKey(tx.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        color: AppTheme.expense,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (_) async {
        return await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Supprimer ?'),
                content: const Text('Cette transaction sera supprimée.'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Annuler'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('Supprimer'),
                  ),
                ],
              ),
            ) ??
            false;
      },
      onDismissed: (_) =>
          context.read<TransactionsCubit>().deleteTransaction(tx.id),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: (category?.color ?? color).withValues(alpha: 0.15),
          child: Icon(
            category?.icon ?? (isIncome ? Icons.south_west : Icons.north_east),
            color: category?.color ?? color,
          ),
        ),
        title: Text(category?.name ?? (isIncome ? 'Revenu' : 'Dépense')),
        subtitle: Text(
          [
            if (account != null) account.name,
            if (tx.note != null && tx.note!.isNotEmpty) tx.note!,
          ].join(' • '),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (tx.photoPath != null)
              const Padding(
                padding: EdgeInsets.only(right: 6),
                child: Icon(Icons.attach_file, size: 16),
              ),
            Text(
              MoneyFormatter.formatSigned(tx.signedAmount),
              style: TextStyle(color: color, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        onTap: () => showTransactionEditor(context, existing: tx),
      ),
    );
  }
}
