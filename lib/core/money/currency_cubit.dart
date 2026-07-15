import 'package:flutter_bloc/flutter_bloc.dart';

import '../utils/money_formatter.dart';
import '../../data/settings_service.dart';

/// Devise principale unique de l'application. La devise sélectionnée est
/// utilisée partout (comptes, transactions, budgets, objectifs, planning...).
class CurrencyCubit extends Cubit<String> {
  CurrencyCubit(this._settings) : super(_settings.primaryCurrencyCode) {
    MoneyFormatter.appCurrencyCode = state;
  }

  final SettingsService _settings;

  Future<void> setCurrency(String code) async {
    await _settings.setPrimaryCurrencyCode(code);
    MoneyFormatter.appCurrencyCode = code;
    emit(code);
  }
}
