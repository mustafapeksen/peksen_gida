// Local-only Auth + mail catcher + Edge Function integration. No credentials
// are printed, serialized to disk or sent to an external mail service.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:peksen_gida/core/networking/secure_session_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:peksen_gida/features/auth/data/supabase_account_lifecycle.dart';
import 'package:peksen_gida/features/auth/data/supabase_account_repository.dart';
import 'package:peksen_gida/features/auth/domain/account_lifecycle.dart';
import 'package:peksen_gida/features/auth/domain/account_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // Unlike widget tests this suite intentionally talks to loopback Auth/SMTP.
  HttpOverrides.global = null;
  // Host test substitutes only native secure storage; Auth/SMTP/Edge are real local services.
  setUp(() {
    // This Flutter test lives under supabase/tests rather than test/.
    // ignore: invalid_use_of_visible_for_testing_member
    FlutterSecureStorage.setMockInitialValues({});
  });
  final url = Platform.environment['PEKSEN_AUTH_TEST_URL'];
  final key = Platform.environment['PEKSEN_AUTH_TEST_KEY'];
  final input = Platform.environment['PEKSEN_AUTH_TEST_INPUT'];
  if (url != 'http://127.0.0.1:55321' || key == null || input == null) {
    throw StateError('Run the local auth check wrapper.');
  }
  SupabaseClient client() {
    final c = SupabaseClient(
      url!,
      key,
      authOptions: AuthClientOptions(
        autoRefreshToken: false,
        authFlowType: AuthFlowType.pkce,
        pkceAsyncStorage: SecurePkceStorage(url),
      ),
    );
    addTearDown(c.dispose);
    return c;
  }

  Future<dynamic> mailJson(String path) async {
    final http = HttpClient();
    try {
      final req = await http.getUrl(Uri.parse('http://127.0.0.1:55324$path'));
      final res = await req.close();
      if (res.statusCode != 200) throw const AccountLifecycleException();
      return jsonDecode(await utf8.decoder.bind(res).join());
    } finally {
      http.close();
    }
  }

  Future<String> codeFor(String email, String subject) async {
    for (var attempt = 0; attempt < 20; attempt++) {
      final result = await mailJson('/api/v1/messages');
      for (final item in result['messages'] as List) {
        if (!(item['Subject'] as String).contains(subject)) continue;
        if (!(item['To'] as List).any((to) => to['Address'] == email)) continue;
        final detail = await mailJson('/api/v1/message/${item['ID']}');
        final code = RegExp(r'\b\d{6}\b')
            .firstMatch(detail['Text'] as String? ?? '');
        if (code != null) return code.group(0)!;
      }
      await Future<void>.delayed(const Duration(milliseconds: 500));
    }
    throw TestFailure('Local email code did not arrive (content suppressed).');
  }

  var stage = 'initial';
  Future<void> safe(Future<void> Function() action) async {
    try {
      await action();
    } on TestFailure {
      rethrow;
    } catch (_) {
      throw TestFailure(
        'Local onboarding failed at $stage; sensitive server details suppressed.',
      );
    }
  }

  final customerInput = input.substring(0, 32);
  final suffix = DateTime.now().microsecondsSinceEpoch;
  test(
    'Customer PKCE signup, code verification, recovery and credential change',
    () => safe(() async {
      final c = client();
      final flow = SupabaseAccountLifecycle(c),
          repo = SupabaseAccountRepository(c);
      final email = 'signup.$suffix@peksen.invalid';
      stage = 'PKCE signup request';
      await flow.register(
        'Synthetic customer',
        'Synthetic company',
        email,
        customerInput,
      );
      expect(c.auth.currentSession == null, isTrue);
      await expectLater(
        repo.signIn(email, customerInput),
        throwsA(isA<SignInException>()),
      );
      stage = 'signup email code';
      await flow.verify(
        email,
        await codeFor(email, 'kayıt'),
        EmailCodePurpose.signup,
        '',
      );
      expect(
        (await repo.loadProfile(c.auth.currentUser!.id)).role,
        AccountRole.customer,
      );
      stage = 'backend length rejection';
      await expectLater(
        c.auth.updateUser(UserAttributes(password: 'short7!')),
        throwsA(isA<AuthException>()),
      );
      await expectLater(
        c.auth.updateUser(UserAttributes(password: 'ş' * 37)),
        throwsA(isA<AuthException>()),
      );
      await repo.signOut();
      stage = 'PKCE recovery request';
      await flow.resend(email, EmailCodePurpose.recovery);
      stage = 'recovery email code';
      final recoveryCode = await codeFor(email, 'yenileme');
      await expectLater(
        flow.verify(email, recoveryCode, EmailCodePurpose.recovery, 'ş' * 37),
        throwsA(isA<AccountLifecycleException>()),
      );
      expect(c.auth.currentSession == null, isTrue);
      await flow.verify(
        email,
        recoveryCode,
        EmailCodePurpose.recovery,
        '${customerInput}R',
      );
      expect(c.auth.currentSession == null, isTrue);
      await expectLater(
        repo.signIn(email, customerInput),
        throwsA(isA<SignInException>()),
      );
      await repo.signIn(email, '${customerInput}R');
      stage = 'credential change';
      await flow.changePassword('${customerInput}R', '${customerInput}N');
      expect(c.auth.currentSession == null, isTrue);
      await repo.signIn(email, '${customerInput}N');
      expect(
        (await repo.loadProfile(c.auth.currentUser!.id)).role,
        AccountRole.customer,
      );
    }),
    timeout: const Timeout(Duration(minutes: 2)),
  );
  test(
    'Manager invitation via Edge and email yields only its DB-selected role',
    () => safe(() async {
      final manager = client(), worker = client();
      await SupabaseAccountRepository(manager)
          .signIn('manager@peksen.invalid', input);
      final admin = SupabaseAccountLifecycle(manager),
          flow = SupabaseAccountLifecycle(worker);
      final email = 'worker.$suffix@peksen.invalid';
      stage = 'send invitation';
      await admin.invite(
        'Synthetic worker',
        email,
        AccountRole.warehouse,
        null,
      );
      stage = 'email verification';
      await flow.verify(
        email,
        await codeFor(email, 'davet'),
        EmailCodePurpose.invite,
        input,
      );
      final repo = SupabaseAccountRepository(worker);
      expect(
        (await repo.loadProfile(worker.auth.currentUser!.id)).role,
        AccountRole.warehouse,
      );
      // Completion retry does not consume OTP again or change a provisioned role.
      stage = 'invitation completion retry';
      await flow.verify(
        email,
        '000000',
        EmailCodePurpose.invite,
        '${customerInput}Ignored',
      );
      expect(
        (await repo.loadProfile(worker.auth.currentUser!.id)).role,
        AccountRole.warehouse,
      );
      await repo.signOut();
      // The duplicate completion must not overwrite the original credential.
      await repo.signIn(email, input);
      await expectLater(
        admin.invite(
          'Denied',
          'privileged.$suffix@peksen.invalid',
          AccountRole.owner,
          null,
        ),
        throwsA(isA<AccountLifecycleException>()),
      );
      final owner = client();
      await SupabaseAccountRepository(owner)
          .signIn('owner@peksen.invalid', input);
      final control = SupabaseAccountLifecycle(owner);
      await control.setActive(worker.auth.currentUser!.id, false);
      await expectLater(
        repo.loadProfile(worker.auth.currentUser!.id),
        throwsA(isA<AccountAccessException>()),
      );
      await control.setActive(worker.auth.currentUser!.id, true);
      expect(
        (await repo.loadProfile(worker.auth.currentUser!.id)).role,
        AccountRole.warehouse,
      );
    }),
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test(
    'Invitation retries after credential save but before DB acceptance',
    () => safe(() async {
      final manager = client(), worker = client();
      await SupabaseAccountRepository(manager)
          .signIn('manager@peksen.invalid', input);
      final email = 'partial.$suffix@peksen.invalid';
      stage = 'partial invitation';
      await SupabaseAccountLifecycle(manager)
          .invite('Partial worker', email, AccountRole.warehouse, null);
      await worker.auth.verifyOTP(
        email: email,
        token: await codeFor(email, 'davet'),
        type: OtpType.invite,
      );
      await worker.auth.updateUser(UserAttributes(password: customerInput));
      expect(await worker.rpc('account_invitation_accepted'), isFalse);
      // Simulates interruption after Auth saved the credential, before RPC.
      await SupabaseAccountLifecycle(worker)
          .verify(email, '000000', EmailCodePurpose.invite, customerInput);
      expect(await worker.rpc('account_invitation_accepted'), isTrue);
      expect(
        (await SupabaseAccountRepository(worker)
                .loadProfile(worker.auth.currentUser!.id))
            .role,
        AccountRole.warehouse,
      );
    }),
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test(
    'Revoked invitation cannot create an application profile after email verification',
    () => safe(() async {
      final manager = client(), worker = client();
      await SupabaseAccountRepository(manager)
          .signIn('manager@peksen.invalid', input);
      final admin = SupabaseAccountLifecycle(manager),
          flow = SupabaseAccountLifecycle(worker);
      final email = 'revoked.$suffix@peksen.invalid';
      stage = 'send invitation';
      await admin.invite('Revoked worker', email, AccountRole.driver, null);
      final invitation = (await admin.invitations()).singleWhere(
        (i) => i['email'] == email,
      );
      await admin.revokeInvitation(invitation['id'] as String);
      await expectLater(
        flow.verify(
          email,
          await codeFor(email, 'davet'),
          EmailCodePurpose.invite,
          input,
        ),
        throwsA(isA<AccountLifecycleException>()),
      );
      await expectLater(
        SupabaseAccountRepository(worker)
            .loadProfile(worker.auth.currentUser!.id),
        throwsA(isA<AccountAccessException>()),
      );
    }),
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
