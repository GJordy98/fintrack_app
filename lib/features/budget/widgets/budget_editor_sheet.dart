import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/di/service_locator.dart';
import '../../../core/utils/money_formatter.dart';
import '../../../core/utils/visuals.dart';
import '../../../data/models/budget.dart';
import '../../../data/models/category.dart';
import '../../../data/repositories/category_repository.dart';
import '../cubit/budgets_cubit.dart';

Future<void> showBudgetEditor(BuildContext context, {Budget? existing}) {
  final cubit = context.read<BudgetsCubit>();
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => BlocProvider.value(
      value: cubit,
      child: _BudgetEditorSheet(existing: existing),
    ),
  );
}

class _BudgetEditorSheet extends StatefulWidget {
  const _BudgetEditorSheet({this.existing});
  final Budget? existing;

  @override
  State<_BudgetEditorSheet> createState() => _BudgetEditorSheetState();
}

class _BudgetEditorSheetState extends State<_BudgetEditorSheet> {
  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  String? _categoryId;
  bool _rollover = false;
  double _threshold = 80;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _categoryId = e?.categoryId;
    _rollover = e?.rollover ?? false;
    _threshold = (e?.alertThresholdPercent ?? 80).toDouble();
    if (e != null) _amountCtrl.text = MoneyFormatter.toInput(e.allocated);
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  List<Category> get _expenseCategories =>
      sl<CategoryRepository>().byKind(CategoryKind.expense);

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_categoryId == null) return;
    await context.read<BudgetsCubit>().upsertBudget(
          id: widget.existing?.id,
          categoryId: _categoryId!,
          allocated: MoneyFormatter.parseToMinor(_amountCtrl.text),
          rollover: _rollover,
          alertThresholdPercent: _threshold.round(),
        );
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
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                isEdit ? 'Modifier l\'enveloppe' : 'Nouvelle enveloppe',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _categoryId,
                decoration: const InputDecoration(
                  labelText: 'Catégorie',
                  prefixIcon: Icon(Icons.category_outlined),
                ),
                items: _expenseCategories
                    .map((c) => DropdownMenuItem(
                          value: c.id,
                          child: Row(children: [
                            Icon(c.icon, color: c.color, size: 20),
                            const SizedBox(width: 8),
                            Text(c.name),
                          ]),
                        ))
                    .toList(),
                validator: (v) => v == null ? 'Choisis une catégorie' : null,
                onChanged: isEdit
                    ? null
                    : (v) => setState(() => _categoryId = v),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _amountCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [MoneyInputFormatter()],
                decoration: InputDecoration(
                  labelText: 'Montant alloué',
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
              const SizedBox(height: 16),
              Text('Alerte à ${_threshold.round()} % de consommation'),
              Slider(
                value: _threshold,
                min: 50,
                max: 100,
                divisions: 10,
                label: '${_threshold.round()} %',
                onChanged: (v) => setState(() => _threshold = v),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Reporter le reste au mois suivant'),
                subtitle: const Text('Sinon, remise à zéro chaque mois'),
                value: _rollover,
                onChanged: (v) => setState(() => _rollover = v),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.check),
                label: Text(isEdit ? 'Enregistrer' : 'Ajouter'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
