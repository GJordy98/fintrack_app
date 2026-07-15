import 'package:flutter/material.dart';

/// Thème FinTrack : clair + sombre (module 3.8).
///
/// Palette : vert « argent/croissance » comme couleur primaire, avec des
/// sémantiques réutilisées ailleurs (budget vert → orange → rouge, feedback
/// succès/échec).
class AppTheme {
  AppTheme._();

  // Couleurs de marque.
  static const Color seed = Color(0xFF1E8E5A); // vert FinTrack
  static const Color income = Color(0xFF2E7D32); // revenus / positif
  static const Color expense = Color(0xFFC62828); // dépenses / négatif

  // Sémantique budget (barre vert → orange → rouge).
  static const Color budgetOk = Color(0xFF2E7D32);
  static const Color budgetWarn = Color(0xFFF9A825);
  static const Color budgetOver = Color(0xFFC62828);

  static ThemeData light() => _base(Brightness.light);
  static ThemeData dark() => _base(Brightness.dark);

  static ThemeData _base(Brightness brightness) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: brightness,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: colorScheme.surface,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 1,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        filled: true,
      ),
      navigationBarTheme: NavigationBarThemeData(
        elevation: 3,
        labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
      ),
    );
  }
}
