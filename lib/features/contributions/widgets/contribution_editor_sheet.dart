import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../core/di/service_locator.dart';
import '../../../core/utils/money_formatter.dart';
import '../../../core/utils/recurrence.dart';
import '../../../core/utils/visuals.dart';
import '../../../data/models/account.dart';
import '../../../data/models/recurring_rule.dart';
import '../../../data/repositories/account_repository.dart';
import '../cubit/contributions_cubit.dart';

Future<void> showContributionEditor(BuildContext context) {
  final cubit = context.read<ContributionsCubit>();
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => BlocProvider.value(
      value: cubit,
      child: const _ContributionEditorSheet(),
    ),
  );
}

class _ContributionEditorSheet extends StatefulWidget {
  const _ContributionEditorSheet();

  @override
  State<_ContributionEditorSheet> createState() =>
      _ContributionEditorSheetState();
}

class _ContributionEditorSheetState extends State<_ContributionEditorSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _contribCtrl = TextEditingController();
  final _payoutCtrl = TextEditingController();
  RecurrenceFrequency _freq = RecurrenceFrequency.monthly;
  String? _accountId;
  DateTime _startDate = DateTime.now();

  List<Account> get _accounts => sl<AccountRepository>().getActive();

  @override
  void initState() {
    super.initState();
    _accountId = _accounts.isEmpty ? null : _accounts.first.id;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _contribCtrl.dispose();
    _payoutCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickStart() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2015),
      lastDate: DateTime(2100),
    );
    if (d != null) setState(() => _startDate = d);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_accountId == null) return;
    await context.read<ContributionsCubit>().addContribution(
          name: _nameCtrl.text,
          contributionAmount: MoneyFormatter.parseToMinor(_contribCtrl.text),
          expectedPayoutAmount: MoneyFormatter.parseToMinor(_payoutCtrl.text),
          frequency: _freq,
          accountId: _accountId!,
          startDate: _startDate,
        );
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 8, 16, 16 + bottomInset),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Nouvelle cotisation',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 4),
              Text(
                'Tontine / njangi — suivi de tes versements et de tes perceptions.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Nom de la cotisation',
                  hintText: 'Ex : Njangi du quartier',
                  prefixIcon: Icon(Icons.groups_outlined),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Nom requis' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _contribCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [MoneyInputFormatter()],
                decoration: InputDecoration(
                  labelText: 'Montant à cotiser (par échéance)',
                  suffixText: MoneyFormatter.appSymbol,
                  prefixIcon: const Icon(Icons.upload_outlined),
                ),
                validator: (v) {
                  if (MoneyFormatter.parseToMinor(v ?? '') <= 0) {
                    return 'Entre un montant valide';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _payoutCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [MoneyInputFormatter()],
                decoration: InputDecoration(
                  labelText: 'Montant attendu à la perception (optionnel)',
                  suffixText: MoneyFormatter.appSymbol,
                  prefixIcon: const Icon(Icons.download_outlined),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<RecurrenceFrequency>(
                initialValue: _freq,
                decoration: const InputDecoration(
                  labelText: 'Fréquence de cotisation',
                  prefixIcon: Icon(Icons.repeat),
                ),
                items: RecurrenceFrequency.values
                    .map((f) => DropdownMenuItem(
                          value: f,
                          child: Text(frequencyLabel(f)),
                        ))
                    .toList(),
                onChanged: (v) =>
                    setState(() => _freq = v ?? RecurrenceFrequency.monthly),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _accountId,
                decoration: const InputDecoration(
                  labelText: 'Compte',
                  prefixIcon: Icon(Icons.account_balance_wallet_outlined),
                ),
                items: _accounts
                    .map((a) => DropdownMenuItem(
                          value: a.id,
                          child: Row(children: [
                            Icon(a.type.icon, size: 20),
                            const SizedBox(width: 8),
                            Text(a.name),
                          ]),
                        ))
                    .toList(),
                validator: (v) => v == null ? 'Choisis un compte' : null,
                onChanged: (v) => setState(() => _accountId = v),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _pickStart,
                icon: const Icon(Icons.event_outlined),
                label: Text(
                  'Début : ${DateFormat('d MMM yyyy', 'fr_FR').format(_startDate)}',
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'On génère automatiquement tes 12 prochaines échéances de cotisation. Tu ajouteras tes jours de perception (« bouffe ») dans le détail.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.check),
                label: const Text('Créer la cotisation'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
