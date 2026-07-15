import 'package:flutter/material.dart';

import '../../data/models/account.dart';
import '../../data/models/category.dart';

/// Reconstruit un IconData Material à partir d'un codePoint stocké.
IconData materialIcon(int codePoint) =>
    IconData(codePoint, fontFamily: 'MaterialIcons');

extension CategoryVisuals on Category {
  IconData get icon => materialIcon(iconCodePoint);
  Color get color => Color(colorValue);
}

extension AccountVisuals on AccountType {
  String get label => switch (this) {
        AccountType.cash => 'Espèces',
        AccountType.mobileMoney => 'Mobile Money',
        AccountType.bank => 'Banque',
        AccountType.other => 'Autre',
      };

  IconData get icon => switch (this) {
        AccountType.cash => Icons.payments_outlined,
        AccountType.mobileMoney => Icons.smartphone_outlined,
        AccountType.bank => Icons.account_balance_outlined,
        AccountType.other => Icons.account_balance_wallet_outlined,
      };
}
