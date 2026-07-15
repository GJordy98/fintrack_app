import 'package:fintrack_app/core/premium/premium_config.dart';
import 'package:fintrack_app/core/premium/premium_service.dart';
import 'package:fintrack_app/data/hive_config.dart';
import 'package:fintrack_app/data/settings_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import '../support/hive_test_setup.dart';
import 'dart:io';

void main() {
  late Directory dir;
  late SettingsService settings;

  setUp(() async {
    dir = await initHiveForTest();
    settings = SettingsService(Hive.box(HiveBoxes.settings));
  });

  tearDown(() async {
    await tearDownHiveForTest(dir);
  });

  group('Entitlement premium', () {
    test('gratuit par défaut', () {
      final svc = PremiumService(settings);
      expect(svc.isPremium, isFalse);
    });

    test('déblocage par achat', () async {
      final svc = PremiumService(settings);
      await settings.setPremiumPurchaseActive(true);
      expect(svc.isPremium, isTrue);
    });

    test('déblocage par le serveur (compte de test)', () async {
      final svc = PremiumService(settings);
      await svc.setBackendGranted(true);
      expect(svc.isPremium, isTrue);
      expect(settings.premiumBackendGranted, isTrue);
    });

    test('déblocage par override de test', () async {
      final svc = PremiumService(settings);
      await svc.setDevOverride(true);
      expect(svc.isPremium, isTrue);
    });

    test('émet sur le flux quand l\'entitlement change', () async {
      final svc = PremiumService(settings);
      final events = <bool>[];
      final sub = svc.entitlementStream.listen(events.add);
      await svc.setBackendGranted(true);
      await svc.setDevOverride(true);
      await svc.setBackendGranted(false); // reste premium via l'override
      await Future<void>.delayed(Duration.zero);
      await sub.cancel();
      expect(events, [true, true, true]);
      expect(svc.isPremium, isTrue);
    });

    test('prix de repli quand le store n\'a pas de produit', () {
      final svc = PremiumService(settings);
      expect(svc.displayPrice, PremiumConfig.priceFallback);
    });
  });

  group('Quotas du palier gratuit', () {
    test('valeurs de configuration', () {
      expect(PremiumConfig.freeGoalLimit, 2);
      expect(PremiumConfig.freeAccountLimit, 3);
      expect(PremiumConfig.freeCustomCategoryLimit, 2);
      expect(PremiumConfig.freeAnimationsPerMonth, 4);
    });
  });

  group('Quota d\'animations mensuel', () {
    test('compteur à 0 par défaut puis incrémenté', () async {
      expect(settings.animationsUsedThisMonth('2026-07'), 0);
      await settings.recordAnimationShown('2026-07');
      await settings.recordAnimationShown('2026-07');
      expect(settings.animationsUsedThisMonth('2026-07'), 2);
    });

    test('se réinitialise au changement de mois', () async {
      await settings.recordAnimationShown('2026-07');
      await settings.recordAnimationShown('2026-07');
      expect(settings.animationsUsedThisMonth('2026-07'), 2);
      // Nouveau mois : compteur remis à 0.
      expect(settings.animationsUsedThisMonth('2026-08'), 0);
      await settings.recordAnimationShown('2026-08');
      expect(settings.animationsUsedThisMonth('2026-08'), 1);
      // L'ancien mois n'est plus le mois courant → 0.
      expect(settings.animationsUsedThisMonth('2026-07'), 0);
    });

    test('4 crédits gratuits puis épuisé', () async {
      const monthKey = '2026-07';
      for (var i = 0; i < PremiumConfig.freeAnimationsPerMonth; i++) {
        expect(
          settings.animationsUsedThisMonth(monthKey) <
              PremiumConfig.freeAnimationsPerMonth,
          isTrue,
        );
        await settings.recordAnimationShown(monthKey);
      }
      // Après 4, le quota gratuit est atteint.
      expect(
        settings.animationsUsedThisMonth(monthKey) <
            PremiumConfig.freeAnimationsPerMonth,
        isFalse,
      );
    });
  });
}
