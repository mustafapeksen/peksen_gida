import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peksen_gida/app.dart';
import 'package:peksen_gida/core/routing/app_router.dart';
import 'package:peksen_gida/features/auth/domain/account_repository.dart';
import 'package:peksen_gida/features/auth/domain/auth_repository.dart';
import 'package:peksen_gida/features/auth/presentation/auth_providers.dart';

class FakeAccounts implements AccountRepository, AuthRepository {
  FakeAccounts(this.role);
  AccountRole role;
  final events = StreamController<AuthSession>.broadcast();
  AuthSession session = const AuthSession.signedOut();
  int signInCalls = 0;
  bool failSignIn = false;
  bool denyProfile = false;
  Completer<void>? pending;

  @override
  Stream<AuthSession> watchSession() async* {
    yield session;
    yield* events.stream;
  }

  @override
  Future<void> signIn(String email, String password) async {
    signInCalls++;
    if (failSignIn) throw StateError('sensitive-server-detail');
    await pending?.future;
    session = const AuthSession.signedIn('fixture');
    events.add(session);
  }

  @override
  Future<void> signOut() async {
    session = const AuthSession.signedOut();
    events.add(session);
  }

  @override
  Future<AccountProfile> loadProfile(String userId) async {
    if (denyProfile) throw const AccountAccessException();
    return AccountProfile(id: userId, name: 'Sentetik hesap', role: role);
  }
}

Future<ProviderContainer> pumpAccount(
  WidgetTester tester,
  FakeAccounts fake,
) async {
  final container = ProviderContainer(
    overrides: [
      accountRepositoryProvider.overrideWith((_) async => fake),
      authRepositoryProvider.overrideWith((_) async => fake),
    ],
  );
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    container.dispose();
    await fake.events.close();
  });
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const PeksenGidaApp(),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

Future<void> submitLogin(WidgetTester tester) async {
  await tester.enterText(
    find.byKey(const ValueKey('login-email')),
    'fixture@peksen.invalid',
  );
  await tester.enterText(
    find.byKey(const ValueKey('login-password')),
    'synthetic-test-input',
  );
  await tester.ensureVisible(find.byKey(const ValueKey('login-submit')));
  await tester.tap(find.byKey(const ValueKey('login-submit')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'Giriş beklerken ekran kapanırsa disposed controller kullanılmaz',
    (tester) async {
      final fake = FakeAccounts(AccountRole.customer)
        ..pending = Completer<void>();
      await pumpAccount(tester, fake);
      await submitLogin(tester);
      await tester.pumpWidget(const SizedBox.shrink());
      fake.pending!.complete();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
  for (final role in AccountRole.values) {
    testWidgets(
      '${role.id}: giriş DB rolüne gider, çıkış korumalı yolu kapatır',
      (tester) async {
        final fake = FakeAccounts(role);
        final container = await pumpAccount(tester, fake);
        await submitLogin(tester);
        expect(find.text('Rolünüz: ${role.label}'), findsOneWidget);
        expect(
          container
              .read(appRouterProvider)
              .routeInformationProvider
              .value
              .uri
              .path,
          '/account',
        );
        await tester.tap(find.byKey(const ValueKey('account-sign-out')));
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('login-submit')), findsOneWidget);
        container.read(appRouterProvider).go('/account');
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('account-role')), findsNothing);
        expect(
          container
              .read(appRouterProvider)
              .routeInformationProvider
              .value
              .uri
              .path,
          '/',
        );
      },
    );
  }

  testWidgets('Anonim doğrudan hesap yolu girişe döner', (tester) async {
    final container = await pumpAccount(
      tester,
      FakeAccounts(AccountRole.customer),
    );
    container.read(appRouterProvider).go('/account');
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('login-submit')), findsOneWidget);
    expect(find.byKey(const ValueKey('account-role')), findsNothing);
  });

  testWidgets('Önizlemede Owner seçmek gerçek oturum veya rol sağlamaz', (
    tester,
  ) async {
    final fake = FakeAccounts(AccountRole.customer);
    final container = await pumpAccount(tester, fake);
    container.read(appRouterProvider).go('/preview/roles/owner');
    await tester.pumpAndSettle();
    expect(fake.session.status, AuthSessionStatus.signedOut);
    container.read(appRouterProvider).go('/account');
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('account-role')), findsNothing);
  });

  testWidgets('Boş alanlar ağa gönderilmez', (tester) async {
    final fake = FakeAccounts(AccountRole.customer);
    await pumpAccount(tester, fake);
    await tester.ensureVisible(find.byKey(const ValueKey('login-submit')));
    await tester.tap(find.byKey(const ValueKey('login-submit')));
    await tester.pumpAndSettle();
    expect(fake.signInCalls, 0);
    expect(find.text('E-posta ve parolanızı girin.'), findsOneWidget);
  });

  testWidgets('Hatalı giriş hassas ayrıntı göstermez ve parolayı temizler', (
    tester,
  ) async {
    final fake = FakeAccounts(AccountRole.customer)..failSignIn = true;
    await pumpAccount(tester, fake);
    await submitLogin(tester);
    expect(find.text(const SignInException().toString()), findsOneWidget);
    expect(find.textContaining('sensitive-server-detail'), findsNothing);
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('login-password')))
          .controller!
          .text,
      isEmpty,
    );
    expect(find.byKey(const ValueKey('account-role')), findsNothing);
  });

  testWidgets('Gönderim sürerken ikinci istek ve önizleme geçişi kapalıdır', (
    tester,
  ) async {
    final fake = FakeAccounts(AccountRole.customer)
      ..pending = Completer<void>();
    await pumpAccount(tester, fake);
    await submitLogin(tester);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const ValueKey('login-submit')))
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<OutlinedButton>(find.byKey(const ValueKey('preview-entry')))
          .onPressed,
      isNull,
    );
    expect(fake.signInCalls, 1);
    fake.pending!.complete();
    await tester.pumpAndSettle();
    expect(find.text('Rolünüz: Müşteri'), findsOneWidget);
  });

  testWidgets(
    'Pasif/eksik profil rol ekranına erişemez, çıkış kullanılabilir',
    (tester) async {
      final fake = FakeAccounts(AccountRole.owner)..denyProfile = true;
      await pumpAccount(tester, fake);
      await submitLogin(tester);
      expect(find.byKey(const ValueKey('account-denied')), findsOneWidget);
      expect(find.byKey(const ValueKey('account-role')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('account-sign-out')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('login-submit')), findsOneWidget);
    },
  );

  testWidgets('Auth izleme hatası eski rolü ekrandan kaldırır', (tester) async {
    final fake = FakeAccounts(AccountRole.owner);
    await pumpAccount(tester, fake);
    await submitLogin(tester);
    fake.events.addError(const AuthObservationException());
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('account-role')), findsNothing);
    expect(find.byKey(const ValueKey('login-submit')), findsOneWidget);
  });

  testWidgets('Yenileme pasif hale gelen hesabın eski rolünü kaldırır', (
    tester,
  ) async {
    final fake = FakeAccounts(AccountRole.owner);
    await pumpAccount(tester, fake);
    await submitLogin(tester);
    fake.denyProfile = true;
    await tester.tap(find.text('Hesap erişimini yenile'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('account-role')), findsNothing);
    expect(find.byKey(const ValueKey('account-denied')), findsOneWidget);
  });

  for (final invalid in [
    {'id': 'fixture', 'role': 'owner', 'name': 'Name', 'active': false},
    {'id': 'other', 'role': 'owner', 'name': 'Name', 'active': true},
    {'id': 'fixture', 'role': 'order_operator', 'name': 'Name', 'active': true},
    {'id': 'fixture', 'role': 'owner', 'name': null, 'active': true},
  ]) {
    test('Geçersiz profil güvenli biçimde reddedilir: $invalid', () {
      expect(
        () => AccountProfile.fromJson(invalid, 'fixture'),
        throwsA(isA<AccountAccessException>()),
      );
    });
  }
}
