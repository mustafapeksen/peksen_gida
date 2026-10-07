import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peksen_gida/features/auth/domain/account_lifecycle.dart';
import 'package:peksen_gida/features/auth/domain/account_repository.dart';
import 'package:peksen_gida/features/auth/presentation/auth_providers.dart';
import 'package:peksen_gida/features/auth/presentation/onboarding_page.dart';
import 'package:peksen_gida/features/auth/presentation/account_admin_page.dart';

class FakeLifecycle implements AccountLifecycle {
  int registrations = 0, invitationsSent = 0;
  bool fail = false;
  @override
  Future<void> register(
    String name,
    String company,
    String email,
    String password,
  ) async {
    registrations++;
    if (fail) throw StateError('PRIVATE server message');
  }

  @override
  Future<void> resend(String email, EmailCodePurpose purpose) async {}
  @override
  Future<void> verify(
    String email,
    String code,
    EmailCodePurpose purpose,
    String password,
  ) async {}
  @override
  Future<void> invite(
    String name,
    String email,
    AccountRole role,
    String? customerId,
  ) async {
    invitationsSent++;
  }

  @override
  Future<List<Map<String, dynamic>>> accounts() async => [];
  @override
  Future<List<Map<String, dynamic>>> invitations() async => [];
  @override
  Future<void> revokeInvitation(String id) async {}
  @override
  Future<void> setActive(String userId, bool active) async {}
  @override
  Future<void> changePassword(
    String currentPassword,
    String newPassword,
  ) async {}
}

void main() {
  test(
    'New credentials use backend UTF-8 byte limit and character minimum',
    () {
      expect(validNewPassword('a' * 7), false);
      expect(validNewPassword('a' * 8), true);
      expect(validNewPassword('a' * 72), true);
      expect(validNewPassword('a' * 73), false);
      expect(validNewPassword('ş' * 36), true);
      expect(validNewPassword('ş' * 37), false);
      expect(validNewPassword('😀' * 7), false);
      expect(validNewPassword('😀' * 18), true);
      expect(validNewPassword('😀' * 19), false);
    },
  );
  Future<void> show(
    WidgetTester tester,
    Widget page,
    FakeLifecycle fake, {
    AccountRole role = AccountRole.customer,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          accountLifecycleProvider.overrideWith((ref) async => fake),
          accountProfileProvider.overrideWith(
            (ref) async =>
                AccountProfile(id: 'fixture', name: 'Fixture', role: role),
          ),
        ],
        child: MaterialApp(home: page),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('Signup validates required company and password before network', (
    tester,
  ) async {
    final fake = FakeLifecycle();
    await show(
      tester,
      const OnboardingPage(purpose: EmailCodePurpose.signup),
      fake,
    );
    await tester.tap(find.byKey(const ValueKey('onboarding-submit')));
    await tester.pump();
    expect(fake.registrations, 0);
    expect(find.textContaining('Alanları doldurun'), findsOneWidget);
  });
  testWidgets('Signup sends once, clears password and advances to code entry', (
    tester,
  ) async {
    final fake = FakeLifecycle();
    await show(
      tester,
      const OnboardingPage(purpose: EmailCodePurpose.signup),
      fake,
    );
    for (final field in {
      'signup-name': 'Test',
      'signup-company': 'Firma',
      'onboarding-email': 'test@peksen.invalid',
      'onboarding-password': 'synthetic-input',
    }.entries) {
      await tester.enterText(find.byKey(ValueKey(field.key)), field.value);
    }
    await tester.ensureVisible(find.byKey(const ValueKey('onboarding-submit')));
    await tester.tap(find.byKey(const ValueKey('onboarding-submit')));
    await tester.pumpAndSettle();
    expect(fake.registrations, 1);
    expect(find.byKey(const ValueKey('onboarding-code')), findsOneWidget);
    expect(find.text('synthetic-input'), findsNothing);
  });
  testWidgets('Signup errors hide server details and clear password', (
    tester,
  ) async {
    final fake = FakeLifecycle()..fail = true;
    await show(
      tester,
      const OnboardingPage(purpose: EmailCodePurpose.signup),
      fake,
    );
    for (final field in {
      'signup-name': 'Test',
      'signup-company': 'Firma',
      'onboarding-email': 'test@peksen.invalid',
      'onboarding-password': 'synthetic-input',
    }.entries) {
      await tester.enterText(find.byKey(ValueKey(field.key)), field.value);
    }
    await tester.ensureVisible(find.byKey(const ValueKey('onboarding-submit')));
    await tester.tap(find.byKey(const ValueKey('onboarding-submit')));
    await tester.pumpAndSettle();
    expect(find.textContaining('PRIVATE'), findsNothing);
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('onboarding-password')))
          .controller!
          .text,
      isEmpty,
    );
  });
  for (final purpose in EmailCodePurpose.values) {
    testWidgets(
      '${purpose.name}: small viewport and keyboard remain scrollable',
      (tester) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await show(tester, OnboardingPage(purpose: purpose), FakeLifecycle());
        tester.view.viewInsets = const FakeViewPadding(bottom: 260);
        addTearDown(tester.view.resetViewInsets);
        await tester.tap(find.byKey(const ValueKey('onboarding-email')));
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.byKey(const ValueKey('onboarding-submit')),
          180,
          scrollable: find
              .descendant(
                of: find.byType(ListView),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), null);
      },
    );
  }
  testWidgets('Customer cannot open account management UI', (tester) async {
    await show(tester, const AccountAdminPage(), FakeLifecycle());
    expect(find.text('Hesap yönetimi yetkiniz yok.'), findsOneWidget);
    expect(find.byKey(const ValueKey('invite-send')), findsNothing);
  });
  testWidgets('Manager invitation dropdown excludes all privileged roles', (
    tester,
  ) async {
    await show(
      tester,
      const AccountAdminPage(),
      FakeLifecycle(),
      role: AccountRole.manager,
    );
    await tester.tap(find.byKey(const ValueKey('invite-role')));
    await tester.pumpAndSettle();
    expect(find.text('İşletme sahibi'), findsNothing);
    expect(find.text('Muhasebe'), findsNothing);
    expect(find.text('Yönetici'), findsNothing);
    expect(find.text('Depo'), findsWidgets);
  });
}
