import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:fintrack_app/core/di/service_locator.dart';
import 'package:fintrack_app/app.dart';
import 'package:fintrack_app/features/auth/auth_repository.dart';
import 'package:fintrack_app/features/auth/cubit/auth_cubit.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'support/hive_test_setup.dart';

class FakeUser extends Fake implements User {
  @override
  String get uid => 'fake_uid';

  @override
  String get email => 'test@fintrack.com';
}

class FakeAuthRepository extends Fake implements AuthRepository {
  @override
  Stream<User?> get userStream => Stream.value(FakeUser());

  @override
  User? get currentUser => FakeUser();
}

void main() {
  late Directory dir;

  setUp(() async {
    await initializeDateFormatting('fr_FR');
    dir = await initHiveForTest();
    await setupServiceLocator();

    // Remplacer l'instance Auth par nos fakes de test
    sl.unregister<AuthCubit>();
    sl.unregister<AuthRepository>();
    final fakeRepo = FakeAuthRepository();
    sl.registerLazySingleton<AuthRepository>(() => fakeRepo);
    sl.registerLazySingleton<AuthCubit>(() => AuthCubit(fakeRepo));
  });

  tearDown(() async {
    await tearDownHiveForTest(dir);
  });

  testWidgets('L\'app démarre sur le shell avec les 5 onglets', (tester) async {
    await tester.pumpWidget(const FinTrackApp());
    await tester.pumpAndSettle();

    expect(find.text('Transactions'), findsOneWidget);
    expect(find.text('Budget'), findsOneWidget);
    expect(find.text('Objectifs'), findsOneWidget);
    expect(find.text('Plus'), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
  });
}
