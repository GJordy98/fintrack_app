import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../constants/app_constants.dart';
import '../money/currency.dart';

/// Formatage et saisie des montants.
///
/// IMPORTANT : tous les montants sont stockés en **centimes** (entier ×100).
/// L'affichage divise par 100 et applique le nombre de décimales de la devise
/// (FCFA : 0, EUR/USD : 2).
class MoneyFormatter {
  MoneyFormatter._();

  /// Devise par défaut de l'app (budgets, objectifs, planning...). Définie au
  /// démarrage depuis les réglages ; les comptes passent leur propre devise.
  static String appCurrencyCode = 'XAF';

  /// Symbole de la devise active (ex : FCFA, €, \$).
  static String get appSymbol => Currency.byCode(appCurrencyCode).symbol;

  static final Map<String, NumberFormat> _cache = {};

  static NumberFormat _formatFor(Currency c) {
    return _cache.putIfAbsent('${c.code}${c.decimalDigits}', () {
      final f = NumberFormat.decimalPattern(AppConstants.defaultLocale);
      f.minimumFractionDigits = c.decimalDigits;
      f.maximumFractionDigits = c.decimalDigits;
      return f;
    });
  }

  /// Ex (XAF) : 150000000 -> "1 500 000 FCFA" ; (EUR) 1250 -> "12,50 €".
  static String format(num minorUnits, {String? currencyCode, String? symbol}) {
    final currency = Currency.byCode(currencyCode ?? appCurrencyCode);
    final value = minorUnits / 100.0;
    final formatted = _formatFor(currency).format(value);
    return '$formatted ${symbol ?? currency.symbol}';
  }

  /// Version signée (utile pour les transactions) : "+1 000 FCFA".
  static String formatSigned(num minorUnits, {String? currencyCode}) {
    final sign = minorUnits > 0 ? '+' : (minorUnits < 0 ? '-' : '');
    return '$sign${format(minorUnits.abs(), currencyCode: currencyCode)}';
  }

  /// Convertit un texte saisi ("12,50", "15000") en centimes (entier).
  static int parseToMinor(String text) {
    final cleaned = text.trim().replaceAll(' ', '').replaceAll(',', '.');
    if (cleaned.isEmpty) return 0;
    final value = double.tryParse(cleaned);
    if (value == null) return 0;
    return (value * 100).round();
  }

  /// Texte à préremplir dans un champ à partir d'un montant en centimes.
  static String toInput(int minorUnits, {String? currencyCode}) {
    final currency = Currency.byCode(currencyCode);
    final value = minorUnits / 100.0;
    if (currency.decimalDigits == 0) return value.round().toString();
    return value.toStringAsFixed(currency.decimalDigits).replaceAll('.', ',');
  }
}

/// Autorise la saisie de montants décimaux (chiffres + un séparateur , ou .).
class MoneyInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text;
    if (text.isEmpty) return newValue;
    // Chiffres, avec au plus un séparateur décimal (virgule ou point).
    final regex = RegExp(r'^\d*([.,]\d{0,2})?$');
    if (regex.hasMatch(text)) return newValue;
    return oldValue;
  }
}
