import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/money_formatter.dart';
import '../../data/models/contribution.dart';
import '../../data/models/contribution_event.dart';
import 'cubit/contributions_cubit.dart';

class ContributionDetailPage extends StatelessWidget {
  const ContributionDetailPage({super.key, required this.contributionId});
  final String contributionId;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ContributionsCubit, ContributionsState>(
      builder: (context, state) {
        final cubit = context.read<ContributionsCubit>();
        final match = state.contributions
            .where((v) => v.contribution.id == contributionId)
            .toList();
        if (match.isEmpty) {
          return const Scaffold(
            body: Center(child: Text('Cotisation introuvable')),
          );
        }
        final view = match.first;
        final c = view.contribution;
        final events = cubit.eventsFor(contributionId);

        return Scaffold(
          appBar: AppBar(
            title: Text(c.name),
            actions: [
              PopupMenuButton<String>(
                icon: const Icon(Icons.add),
                onSelected: (v) {
                  if (v == 'payout') {
                    _addEvent(context, c, ContributionEventKind.receive);
                  } else {
                    _addEvent(context, c, ContributionEventKind.contribute);
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: 'payout',
                    child: ListTile(
                      leading: Icon(Icons.download_outlined),
                      title: Text('Jour de perception'),
                    ),
                  ),
                  PopupMenuItem(
                    value: 'contribute',
                    child: ListTile(
                      leading: Icon(Icons.upload_outlined),
                      title: Text('Jour de cotisation'),
                    ),
                  ),
                ],
              ),
            ],
          ),
          body: Column(
            children: [
              _Header(view: view),
              const Divider(height: 1),
              Expanded(
                child: events.isEmpty
                    ? const Center(child: Text('Aucune échéance.'))
                    : ListView.builder(
                        padding: const EdgeInsets.only(bottom: 24),
                        itemCount: events.length,
                        itemBuilder: (context, i) =>
                            _EventTile(event: events[i]),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _addEvent(
    BuildContext context,
    Contribution c,
    ContributionEventKind kind,
  ) async {
    final cubit = context.read<ContributionsCubit>();
    final isReceive = kind == ContributionEventKind.receive;
    final ctrl = TextEditingController(
      text: MoneyFormatter.toInput(
          isReceive ? c.expectedPayoutAmount : c.contributionAmount),
    );
    DateTime date = DateTime.now();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text(isReceive
              ? 'Jour de perception (« bouffe »)'
              : 'Jour de cotisation'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: ctrl,
                keyboardType: TextInputType.number,
                inputFormatters: [MoneyInputFormatter()],
                decoration: InputDecoration(
                  labelText: 'Montant',
                  suffixText: MoneyFormatter.appSymbol,
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                icon: const Icon(Icons.event_outlined),
                label: Text(DateFormat('d MMM yyyy', 'fr_FR').format(date)),
                onPressed: () async {
                  final d = await showDatePicker(
                    context: ctx,
                    initialDate: date,
                    firstDate: DateTime(2015),
                    lastDate: DateTime(2100),
                  );
                  if (d != null) setLocal(() => date = d);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Ajouter'),
            ),
          ],
        ),
      ),
    );

    if (result == true) {
      final amount = MoneyFormatter.parseToMinor(ctrl.text);
      if (amount <= 0) return;
      if (isReceive) {
        await cubit.addPayoutEvent(c, date: date, amount: amount);
      } else {
        await cubit.addContributeEvent(c, date: date, amount: amount);
      }
    }
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.view});
  final ContributionView view;

  @override
  Widget build(BuildContext context) {
    final c = view.contribution;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: _stat(context, 'Cotisation',
                MoneyFormatter.format(c.contributionAmount), AppTheme.expense),
          ),
          Expanded(
            child: _stat(context, 'Perception',
                MoneyFormatter.format(c.expectedPayoutAmount), AppTheme.income),
          ),
          Expanded(
            child: _stat(
                context,
                'Solde cycle',
                MoneyFormatter.formatSigned(view.netBalance),
                view.netBalance >= 0 ? AppTheme.income : AppTheme.expense),
          ),
        ],
      ),
    );
  }

  Widget _stat(BuildContext context, String label, String value, Color color) {
    return Column(
      children: [
        Text(label, style: Theme.of(context).textTheme.labelSmall),
        const SizedBox(height: 4),
        Text(value,
            textAlign: TextAlign.center,
            style: TextStyle(color: color, fontWeight: FontWeight.bold)),
      ],
    );
  }
}

class _EventTile extends StatelessWidget {
  const _EventTile({required this.event});
  final ContributionEvent event;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<ContributionsCubit>();
    final isReceive = event.kind == ContributionEventKind.receive;
    final color = isReceive ? AppTheme.income : AppTheme.expense;
    final done = event.status == EventStatus.done;

    return Dismissible(
      key: ValueKey(event.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        color: AppTheme.expense,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (_) => cubit.deleteEvent(event),
      child: ListTile(
        leading: Icon(
          isReceive ? Icons.download_outlined : Icons.upload_outlined,
          color: color,
        ),
        title: Text(isReceive ? 'Perception' : 'Cotisation'),
        subtitle: Text(DateFormat('EEEE d MMM yyyy', 'fr_FR').format(event.date)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              MoneyFormatter.formatSigned(event.signedAmount),
              style: TextStyle(color: color, fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 8),
            Checkbox(
              value: done,
              onChanged: (v) {
                if (v == true) {
                  cubit.markDone(event);
                } else {
                  cubit.markUpcoming(event);
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
