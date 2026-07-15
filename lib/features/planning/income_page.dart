import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/utils/money_formatter.dart';
import '../../core/utils/recurrence.dart';
import '../../data/models/income_profile.dart';
import '../../data/models/recurring_rule.dart';
import 'cubit/income_cubit.dart';

class IncomePage extends StatelessWidget {
  const IncomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mes revenus')),
      body: BlocBuilder<IncomeCubit, IncomeState>(
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
                      Text('Revenu mensuel estimé',
                          style: Theme.of(context).textTheme.labelLarge),
                      const SizedBox(height: 6),
                      Text(
                        MoneyFormatter.format(state.monthlyTotal),
                        style: Theme.of(context)
                            .textTheme
                            .headlineSmall
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      if (state.incomes.isEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            'Ajoute ton salaire pour calculer ton budget journalier.',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              ...state.incomes.map((i) => ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.payments)),
                    title: Text(i.label),
                    subtitle: Text(
                        '${MoneyFormatter.format(i.amount)} • ${frequencyLabel(i.frequency)}'),
                    trailing: Text(
                      '≈ ${MoneyFormatter.format(i.monthlyEquivalent)}/mois',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    onTap: () => _showEditor(context, existing: i),
                  )),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showEditor(context),
        icon: const Icon(Icons.add),
        label: const Text('Revenu'),
      ),
    );
  }

  void _showEditor(BuildContext context, {IncomeProfile? existing}) {
    final cubit = context.read<IncomeCubit>();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => BlocProvider.value(
        value: cubit,
        child: _IncomeEditor(existing: existing),
      ),
    );
  }
}

class _IncomeEditor extends StatefulWidget {
  const _IncomeEditor({this.existing});
  final IncomeProfile? existing;

  @override
  State<_IncomeEditor> createState() => _IncomeEditorState();
}

class _IncomeEditorState extends State<_IncomeEditor> {
  final _formKey = GlobalKey<FormState>();
  final _labelCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  RecurrenceFrequency _freq = RecurrenceFrequency.monthly;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _labelCtrl.text = e.label;
      _amountCtrl.text = MoneyFormatter.toInput(e.amount);
      _freq = e.frequency;
    } else {
      _labelCtrl.text = 'Salaire';
    }
  }

  @override
  void dispose() {
    _labelCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final cubit = context.read<IncomeCubit>();
    final amount = MoneyFormatter.parseToMinor(_amountCtrl.text);
    if (widget.existing == null) {
      await cubit.addIncome(
          label: _labelCtrl.text, amount: amount, frequency: _freq);
    } else {
      final e = widget.existing!
        ..label = _labelCtrl.text.trim()
        ..amount = amount
        ..frequency = _freq;
      await cubit.updateIncome(e);
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 8, 16, 16 + bottomInset),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(isEdit ? 'Modifier le revenu' : 'Nouveau revenu',
                      style: Theme.of(context).textTheme.titleLarge),
                ),
                if (isEdit)
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () async {
                      await context
                          .read<IncomeCubit>()
                          .deleteIncome(widget.existing!.id);
                      if (context.mounted) Navigator.pop(context);
                    },
                  ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _labelCtrl,
              decoration: const InputDecoration(
                labelText: 'Libellé',
                prefixIcon: Icon(Icons.badge_outlined),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Libellé requis' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _amountCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [MoneyInputFormatter()],
              decoration: InputDecoration(
                labelText: 'Montant',
                suffixText: MoneyFormatter.appSymbol,
                prefixIcon: const Icon(Icons.tag),
              ),
              validator: (v) {
                if (MoneyFormatter.parseToMinor(v ?? '') <= 0) {
                  return 'Entre un montant valide';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<RecurrenceFrequency>(
              initialValue: _freq,
              decoration: const InputDecoration(
                labelText: 'Fréquence',
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
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.check),
              label: Text(isEdit ? 'Enregistrer' : 'Ajouter'),
            ),
          ],
        ),
      ),
    );
  }
}
