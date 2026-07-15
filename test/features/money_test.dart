import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:fintrack_app/core/utils/money_formatter.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('fr_FR');
  });

  group('parseToMinor', () {
    test('gère les décimales avec virgule et point', () {
      expect(MoneyFormatter.parseToMinor('12,50'), 1250);
      expect(MoneyFormatter.parseToMinor('12.50'), 1250);
      expect(MoneyFormatter.parseToMinor('15000'), 1500000);
      expect(MoneyFormatter.parseToMinor('  '), 0);
      expect(MoneyFormatter.parseToMinor('0,99'), 99);
    });
  });

  group('format', () {
    test('FCFA : 0 décimale', () {
      expect(MoneyFormatter.format(1500000, currencyCode: 'XAF'),
          contains('1'));
      expect(MoneyFormatter.format(1500000, currencyCode: 'XAF'),
          endsWith('FCFA'));
    });

    test('EUR : 2 décimales et symbole €', () {
      final s = MoneyFormatter.format(1250, currencyCode: 'EUR');
      expect(s, '12,50 €');
    });

    test('USD : 2 décimales', () {
      final s = MoneyFormatter.format(999, currencyCode: 'USD');
      expect(s, '9,99 \$');
    });
  });

  group('toInput', () {
    test('re-préremplit correctement', () {
      expect(MoneyFormatter.toInput(1500000, currencyCode: 'XAF'), '15000');
      expect(MoneyFormatter.toInput(1250, currencyCode: 'EUR'), '12,50');
    });
  });

  group('MoneyInputFormatter', () {
    final f = MoneyInputFormatter();
    TextEditingValue apply(String oldT, String newT) => f.formatEditUpdate(
        TextEditingValue(text: oldT), TextEditingValue(text: newT));

    test('accepte chiffres et un séparateur, refuse le reste', () {
      expect(apply('12', '12,5').text, '12,5');
      expect(apply('12', '12a').text, '12'); // refuse lettre
      expect(apply('12,5', '12,50').text, '12,50');
      expect(apply('12,50', '12,500').text, '12,50'); // max 2 décimales
    });
  });
}
