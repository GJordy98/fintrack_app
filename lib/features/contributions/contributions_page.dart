import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/money_formatter.dart';
import '../../data/models/contribution_event.dart';
import 'contribution_detail_page.dart';
import 'cubit/contributions_cubit.dart';
import 'widgets/contribution_editor_sheet.dart';

class ContributionsPage extends StatelessWidget {
  const ContributionsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cotisations')),
      body: BlocBuilder<ContributionsCubit, ContributionsState>(
        builder: (context, state) {
          if (state.loading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state.contributions.isEmpty) {
            return const _Empty();
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 96),
            children:
                state.contributions.map((v) => _ContributionCard(view: v)).toList(),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showContributionEditor(context),
        icon: const Icon(Icons.add),
        label: const Text('Cotisation'),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty();
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.groups_outlined,
                size: 56, color: theme.colorScheme.outline),
            const SizedBox(height: 12),
            Text(
              'Aucune cotisation.\nAjoute ta tontine pour suivre tes jours de cotisation et de perception.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _ContributionCard extends StatelessWidget {
  const _ContributionCard({required this.view});
  final ContributionView view;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = view.contribution;
    final next = view.nextEvent;
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.15),
          child: Icon(Icons.groups, color: theme.colorScheme.primary),
        ),
        title: Text(c.name, style: theme.textTheme.titleMedium),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text('Cotisation : ${MoneyFormatter.format(c.contributionAmount)}'),
            if (next != null)
              Text(
                next.kind == ContributionEventKind.receive
                    ? 'Prochaine perception : ${DateFormat('d MMM', 'fr_FR').format(next.date)}'
                    : 'Prochaine cotisation : ${DateFormat('d MMM', 'fr_FR').format(next.date)}',
                style: TextStyle(
                  color: next.kind == ContributionEventKind.receive
                      ? AppTheme.income
                      : theme.colorScheme.onSurfaceVariant,
                ),
              ),
            Text('Solde du cycle : ${MoneyFormatter.formatSigned(view.netBalance)}',
                style: theme.textTheme.bodySmall),
          ],
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ContributionDetailPage(contributionId: c.id),
          ),
        ),
      ),
    );
  }
}
