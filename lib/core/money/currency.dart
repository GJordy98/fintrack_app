/// Devises supportées. Les montants sont stockés partout en **centimes**
/// (entier ×100), quelle que soit la devise, pour gérer les décimales sans
/// erreur d'arrondi. L'affichage applique le nombre de décimales de la devise.
class Currency {
  const Currency({
    required this.code,
    required this.symbol,
    required this.label,
    required this.decimalDigits,
  });

  final String code;
  final String symbol;
  final String label;
  final int decimalDigits;

  static const xaf = Currency(
    code: 'XAF',
    symbol: 'FCFA',
    label: 'Franc CFA',
    decimalDigits: 0,
  );
  static const eur = Currency(
    code: 'EUR',
    symbol: '€',
    label: 'Euro',
    decimalDigits: 2,
  );
  static const usd = Currency(
    code: 'USD',
    symbol: '\$',
    label: 'Dollar US',
    decimalDigits: 2,
  );

  static const all = [xaf, eur, usd];

  static Currency byCode(String? code) {
    return all.firstWhere(
      (c) => c.code == code,
      orElse: () => xaf,
    );
  }
}
