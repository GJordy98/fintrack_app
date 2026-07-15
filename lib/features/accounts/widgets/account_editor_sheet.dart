import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/money/currency.dart';
import '../../../core/utils/money_formatter.dart';
import '../../../core/utils/visuals.dart';
import '../../../data/models/account.dart';
import '../cubit/accounts_cubit.dart';

Future<void> showAccountEditor(BuildContext context, {Account? existing}) {
  final cubit = context.read<AccountsCubit>();
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => BlocProvider.value(
      value: cubit,
      child: _AccountEditorSheet(existing: existing),
    ),
  );
}

class _AccountEditorSheet extends StatefulWidget {
  const _AccountEditorSheet({this.existing});
  final Account? existing;

  @override
  State<_AccountEditorSheet> createState() => _AccountEditorSheetState();
}

class _AccountEditorSheetState extends State<_AccountEditorSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _balanceCtrl = TextEditingController();
  final _providerCtrl = TextEditingController();
  final _bankNameCtrl = TextEditingController();
  final _bankKindCtrl = TextEditingController();
  AccountType _type = AccountType.cash;

  // Suggestions rapides (l'utilisateur peut aussi taper les siennes).
  static const _providerSuggestions = [
    'Orange Money',
    'MTN MoMo',
    'Wave',
    'Moov Money',
  ];
  static const _bankKindSuggestions = ['Courant', 'Épargne'];

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _nameCtrl.text = e.name;
      _balanceCtrl.text = MoneyFormatter.toInput(e.initialBalance);
      _type = e.type;
      _providerCtrl.text = e.provider ?? '';
      _bankNameCtrl.text = e.bankName ?? '';
      _bankKindCtrl.text = e.bankAccountKind ?? '';
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _balanceCtrl.dispose();
    _providerCtrl.dispose();
    _bankNameCtrl.dispose();
    _bankKindCtrl.dispose();
    super.dispose();
  }

  String? _nullIfEmpty(String s) => s.trim().isEmpty ? null : s.trim();

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final cubit = context.read<AccountsCubit>();
    final balance = MoneyFormatter.parseToMinor(_balanceCtrl.text);
    final provider =
        _type == AccountType.mobileMoney ? _nullIfEmpty(_providerCtrl.text) : null;
    final bankName =
        _type == AccountType.bank ? _nullIfEmpty(_bankNameCtrl.text) : null;
    final bankKind =
        _type == AccountType.bank ? _nullIfEmpty(_bankKindCtrl.text) : null;

    if (widget.existing == null) {
      await cubit.addAccount(
        name: _nameCtrl.text,
        type: _type,
        initialBalance: balance,
        currencyCode: MoneyFormatter.appCurrencyCode,
        provider: provider,
        bankName: bankName,
        bankAccountKind: bankKind,
      );
    } else {
      final e = widget.existing!
        ..name = _nameCtrl.text.trim()
        ..type = _type
        ..initialBalance = balance
        ..currencyCode = MoneyFormatter.appCurrencyCode
        ..provider = provider
        ..bankName = bankName
        ..bankAccountKind = bankKind;
      await cubit.updateAccount(e);
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final currency = Currency.byCode(MoneyFormatter.appCurrencyCode);

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 8, 16, 16 + bottomInset),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(isEdit ? 'Modifier le compte' : 'Nouveau compte',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Nom du compte',
                  prefixIcon: Icon(Icons.badge_outlined),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Nom requis' : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<AccountType>(
                initialValue: _type,
                decoration: const InputDecoration(
                  labelText: 'Type',
                  prefixIcon: Icon(Icons.account_balance_wallet_outlined),
                ),
                items: AccountType.values
                    .map((t) => DropdownMenuItem(
                          value: t,
                          child: Row(children: [
                            Icon(t.icon, size: 20),
                            const SizedBox(width: 8),
                            Text(t.label),
                          ]),
                        ))
                    .toList(),
                onChanged: (v) =>
                    setState(() => _type = v ?? AccountType.cash),
              ),
              // Champs spécifiques Mobile Money.
              if (_type == AccountType.mobileMoney) ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: _providerCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Opérateur',
                    hintText: 'Orange Money, MTN MoMo, Wave...',
                    prefixIcon: Icon(Icons.smartphone_outlined),
                  ),
                ),
                Wrap(
                  spacing: 6,
                  children: _providerSuggestions
                      .map((s) => ActionChip(
                            label: Text(s),
                            onPressed: () =>
                                setState(() => _providerCtrl.text = s),
                          ))
                      .toList(),
                ),
              ],
              // Champs spécifiques banque.
              if (_type == AccountType.bank) ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: _bankNameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Nom de la banque',
                    hintText: 'Ex : Afriland, Ecobank, BICEC...',
                    prefixIcon: Icon(Icons.account_balance_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _bankKindCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Type de compte',
                    hintText: 'Courant, Épargne...',
                    prefixIcon: Icon(Icons.savings_outlined),
                  ),
                ),
                Wrap(
                  spacing: 6,
                  children: _bankKindSuggestions
                      .map((s) => ActionChip(
                            label: Text(s),
                            onPressed: () =>
                                setState(() => _bankKindCtrl.text = s),
                          ))
                      .toList(),
                ),
              ],
              const SizedBox(height: 12),
              TextFormField(
                controller: _balanceCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [MoneyInputFormatter()],
                decoration: InputDecoration(
                  labelText: 'Solde initial',
                  suffixText: currency.symbol,
                  prefixIcon: const Icon(Icons.tag),
                ),
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
