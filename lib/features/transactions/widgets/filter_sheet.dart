import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../core/di/service_locator.dart';
import '../../../core/utils/visuals.dart';
import '../../../data/models/transaction.dart';
import '../../../data/repositories/account_repository.dart';
import '../../../data/repositories/category_repository.dart';
import '../cubit/transactions_cubit.dart';

Future<void> showFilterSheet(BuildContext context) {
  final cubit = context.read<TransactionsCubit>();
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => BlocProvider.value(
      value: cubit,
      child: const _FilterSheet(),
    ),
  );
}

class _FilterSheet extends StatelessWidget {
  const _FilterSheet();

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<TransactionsCubit>();
    final accounts = sl<AccountRepository>().getActive();
    final categories = sl<CategoryRepository>().getActive();

    return BlocBuilder<TransactionsCubit, TransactionsState>(
      buildWhen: (a, b) => a.filter != b.filter,
      builder: (context, state) {
        final filter = state.filter;
        return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Filtres', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            const Text('Type'),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('Tous'),
                  selected: filter.type == null,
                  onSelected: (_) =>
                      cubit.setFilter(filter.copyWith(type: () => null)),
                ),
                ChoiceChip(
                  label: const Text('Dépenses'),
                  selected: filter.type == TransactionType.expense,
                  onSelected: (_) => cubit.setFilter(
                      filter.copyWith(type: () => TransactionType.expense)),
                ),
                ChoiceChip(
                  label: const Text('Revenus'),
                  selected: filter.type == TransactionType.income,
                  onSelected: (_) => cubit.setFilter(
                      filter.copyWith(type: () => TransactionType.income)),
                ),
              ],
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String?>(
              initialValue: filter.accountId,
              decoration: const InputDecoration(labelText: 'Compte'),
              items: [
                const DropdownMenuItem(value: null, child: Text('Tous')),
                ...accounts.map((a) => DropdownMenuItem(
                      value: a.id,
                      child: Text(a.name),
                    )),
              ],
              onChanged: (v) =>
                  cubit.setFilter(filter.copyWith(accountId: () => v)),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String?>(
              initialValue: filter.categoryId,
              decoration: const InputDecoration(labelText: 'Catégorie'),
              items: [
                const DropdownMenuItem(value: null, child: Text('Toutes')),
                ...categories.map((c) => DropdownMenuItem(
                      value: c.id,
                      child: Row(children: [
                        Icon(c.icon, size: 18, color: c.color),
                        const SizedBox(width: 8),
                        Text(c.name),
                      ]),
                    )),
              ],
              onChanged: (v) =>
                  cubit.setFilter(filter.copyWith(categoryId: () => v)),
            ),
            const SizedBox(height: 16),
            const Text('Période'),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () async {
                      final d = await showDatePicker(
                        context: context,
                        initialDate: filter.from ?? DateTime.now(),
                        firstDate: DateTime(2015),
                        lastDate: DateTime(2100),
                      );
                      if (d != null) {
                        cubit.setFilter(filter.copyWith(from: () => d));
                      }
                    },
                    child: Text(filter.from == null
                        ? 'Début'
                        : DateFormat('d MMM yyyy', 'fr_FR').format(filter.from!)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () async {
                      final d = await showDatePicker(
                        context: context,
                        initialDate: filter.to ?? DateTime.now(),
                        firstDate: DateTime(2015),
                        lastDate: DateTime(2100),
                      );
                      if (d != null) {
                        cubit.setFilter(filter.copyWith(to: () => d));
                      }
                    },
                    child: Text(filter.to == null
                        ? 'Fin'
                        : DateFormat('d MMM yyyy', 'fr_FR').format(filter.to!)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      cubit.clearFilter();
                      Navigator.pop(context);
                    },
                    child: const Text('Réinitialiser'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Fermer'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
      },
    );
  }
}
