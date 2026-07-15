import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../../core/di/service_locator.dart';
import '../../../core/money/currency.dart';
import '../../../core/utils/money_formatter.dart';
import '../../../core/utils/visuals.dart';
import '../../../data/models/account.dart';
import '../../../data/models/category.dart';
import '../../../data/models/transaction.dart';
import '../../../data/repositories/account_repository.dart';
import '../../../data/repositories/category_repository.dart';
import '../cubit/transactions_cubit.dart';

/// Ouvre la feuille de saisie/édition d'une transaction.
Future<void> showTransactionEditor(
  BuildContext context, {
  AppTransaction? existing,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => TransactionEditorSheet(existing: existing),
  );
}

class TransactionEditorSheet extends StatefulWidget {
  const TransactionEditorSheet({super.key, this.existing});

  final AppTransaction? existing;

  @override
  State<TransactionEditorSheet> createState() => _TransactionEditorSheetState();
}

class _TransactionEditorSheetState extends State<TransactionEditorSheet> {
  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();

  late TransactionType _type;
  String? _categoryId;
  String? _accountId;
  late DateTime _date;
  String? _photoPath;

  List<Category> get _categories =>
      sl<CategoryRepository>().byKind(
        _type == TransactionType.expense
            ? CategoryKind.expense
            : CategoryKind.income,
      );

  List<Account> get _accounts => sl<AccountRepository>().getActive();

  String get _currencySymbol =>
      Currency.byCode(MoneyFormatter.appCurrencyCode).symbol;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _type = e?.type ?? TransactionType.expense;
    _categoryId = e?.categoryId;
    final accounts = _accounts;
    _accountId = e?.accountId ?? (accounts.isEmpty ? null : accounts.first.id);
    _date = e?.date ?? DateTime.now();
    _photoPath = e?.photoPath;
    if (e != null) {
      _amountCtrl.text = MoneyFormatter.toInput(e.amount);
      _noteCtrl.text = e.note ?? '';
    }
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  void _onTypeChanged(TransactionType type) {
    setState(() {
      _type = type;
      // La catégorie doit rester cohérente avec le type.
      if (!_categories.any((c) => c.id == _categoryId)) _categoryId = null;
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2015),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1280,
      imageQuality: 70,
    );
    if (file != null) setState(() => _photoPath = file.path);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_accountId == null) return;
    final amount = MoneyFormatter.parseToMinor(_amountCtrl.text);
    final note = _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim();
    final cubit = context.read<TransactionsCubit>();

    if (widget.existing == null) {
      await cubit.addTransaction(
        amount: amount,
        type: _type,
        accountId: _accountId!,
        categoryId: _categoryId,
        note: note,
        date: _date,
        photoPath: _photoPath,
      );
    } else {
      final e = widget.existing!
        ..amount = amount
        ..type = _type
        ..accountId = _accountId!
        ..categoryId = _categoryId
        ..note = note
        ..date = _date
        ..photoPath = _photoPath;
      await cubit.updateTransaction(e);
    }
    if (mounted) Navigator.of(context).pop();
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
                isEdit ? 'Modifier la transaction' : 'Nouvelle transaction',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              SegmentedButton<TransactionType>(
                segments: const [
                  ButtonSegment(
                    value: TransactionType.expense,
                    label: Text('Dépense'),
                    icon: Icon(Icons.remove_circle_outline),
                  ),
                  ButtonSegment(
                    value: TransactionType.income,
                    label: Text('Revenu'),
                    icon: Icon(Icons.add_circle_outline),
                  ),
                ],
                selected: {_type},
                onSelectionChanged: (s) => _onTypeChanged(s.first),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _amountCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [MoneyInputFormatter()],
                autofocus: !isEdit,
                decoration: InputDecoration(
                  labelText: 'Montant',
                  suffixText: _currencySymbol,
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
              DropdownButtonFormField<String>(
                initialValue:
                    _categories.any((c) => c.id == _categoryId) ? _categoryId : null,
                decoration: const InputDecoration(
                  labelText: 'Catégorie',
                  prefixIcon: Icon(Icons.category_outlined),
                ),
                items: _categories
                    .map((c) => DropdownMenuItem(
                          value: c.id,
                          child: Row(
                            children: [
                              Icon(c.icon, color: c.color, size: 20),
                              const SizedBox(width: 8),
                              Text(c.name),
                            ],
                          ),
                        ))
                    .toList(),
                onChanged: (v) => setState(() => _categoryId = v),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _accounts.any((a) => a.id == _accountId)
                    ? _accountId
                    : null,
                decoration: const InputDecoration(
                  labelText: 'Compte',
                  prefixIcon: Icon(Icons.account_balance_wallet_outlined),
                ),
                items: _accounts
                    .map((a) => DropdownMenuItem(
                          value: a.id,
                          child: Row(
                            children: [
                              Icon(a.type.icon, size: 20),
                              const SizedBox(width: 8),
                              Text(a.name),
                            ],
                          ),
                        ))
                    .toList(),
                validator: (v) => v == null ? 'Choisis un compte' : null,
                onChanged: (v) => setState(() => _accountId = v),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickDate,
                      icon: const Icon(Icons.calendar_today_outlined),
                      label: Text(
                        DateFormat('d MMM yyyy', 'fr_FR').format(_date),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filledTonal(
                    onPressed: _pickPhoto,
                    icon: Icon(
                      _photoPath == null
                          ? Icons.add_a_photo_outlined
                          : Icons.check_circle,
                    ),
                    tooltip: 'Justificatif',
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _noteCtrl,
                decoration: const InputDecoration(
                  labelText: 'Note (optionnel)',
                  prefixIcon: Icon(Icons.notes_outlined),
                ),
                textInputAction: TextInputAction.done,
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
      ),
    );
  }
}
