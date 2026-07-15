import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/utils/money_formatter.dart';
import '../../core/utils/recurrence.dart';
import '../../core/utils/visuals.dart';
import '../../data/models/fixed_charge.dart';
import '../../data/models/recurring_rule.dart';
import 'cubit/fixed_charges_cubit.dart';

class FixedChargesPage extends StatelessWidget {
  const FixedChargesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Charges fixes')),
      body: BlocBuilder<FixedChargesCubit, FixedChargesState>(
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
                      Text('Charges fixes / mois',
                          style: Theme.of(context).textTheme.labelLarge),
                      const SizedBox(height: 6),
                      Text(
                        MoneyFormatter.format(state.monthlyTotal),
                        style: Theme.of(context)
                            .textTheme
                            .headlineSmall
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Loyer, électricité, eau... réservés d\'avance, comme le salaire. Ils sont retirés du budget avant de calculer tes dépenses par jour.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
              ...state.charges.map((c) => ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.receipt_long)),
                    title: Text(c.label),
                    subtitle: Text(
                        '${MoneyFormatter.format(c.amount)} • ${frequencyLabel(c.frequency)}'),
                    trailing: Text('≈ ${MoneyFormatter.format(c.monthlyEquivalent)}/mois',
                        style: Theme.of(context).textTheme.bodySmall),
                    onTap: () => _showEditor(context, existing: c),
                  )),
              const Divider(height: 32),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                child: Text('Catégories exclues du suivi quotidien',
                    style: Theme.of(context).textTheme.titleSmall),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Text(
                  'Les dépenses de ces catégories (factures...) ne comptent pas dans tes dépenses du jour.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              ...state.expenseCategories.map((cat) => SwitchListTile(
                    secondary: Icon(cat.icon, color: cat.color),
                    title: Text(cat.name),
                    value: cat.isFixed,
                    onChanged: (v) => context
                        .read<FixedChargesCubit>()
                        .toggleCategoryFixed(cat, v),
                  )),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showEditor(context),
        icon: const Icon(Icons.add),
        label: const Text('Charge fixe'),
      ),
    );
  }

  void _showEditor(BuildContext context, {FixedCharge? existing}) {
    final cubit = context.read<FixedChargesCubit>();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => BlocProvider.value(
        value: cubit,
        child: _ChargeEditor(existing: existing),
      ),
    );
  }
}

class _ChargeEditor extends StatefulWidget {
  const _ChargeEditor({this.existing});
  final FixedCharge? existing;

  @override
  State<_ChargeEditor> createState() => _ChargeEditorState();
}

class _ChargeEditorState extends State<_ChargeEditor> {
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
    final cubit = context.read<FixedChargesCubit>();
    final amount = MoneyFormatter.parseToMinor(_amountCtrl.text);
    if (widget.existing == null) {
      await cubit.addCharge(
          label: _labelCtrl.text, amount: amount, frequency: _freq);
    } else {
      final e = widget.existing!
        ..label = _labelCtrl.text.trim()
        ..amount = amount
        ..frequency = _freq;
      await cubit.updateCharge(e);
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
                  child: Text(
                      isEdit ? 'Modifier la charge' : 'Nouvelle charge fixe',
                      style: Theme.of(context).textTheme.titleLarge),
                ),
                if (isEdit)
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () async {
                      await context
                          .read<FixedChargesCubit>()
                          .deleteCharge(widget.existing!.id);
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
                hintText: 'Loyer, Électricité, Eau...',
                prefixIcon: Icon(Icons.receipt_long_outlined),
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
