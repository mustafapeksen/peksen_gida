import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peksen_gida/core/networking/secure_session_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));
  test('PKCE verifier survives reconstruction, stays project isolated and can be removed', () async {
    final first = SecurePkceStorage('https://one.supabase.co');
    await first.setItem(key: 'code-verifier', value: 'synthetic-verifier');
    expect(
      await SecurePkceStorage('https://one.supabase.co')
          .getItem(key: 'code-verifier'),
      'synthetic-verifier',
    );
    expect(
      await SecurePkceStorage('https://two.supabase.co')
          .getItem(key: 'code-verifier'),
      null,
    );
    await first.removeItem(key: 'code-verifier');
    expect(await first.getItem(key: 'code-verifier'), null);
  });
  test('Session survives storage recreation, is project isolated and logout clears it', () async {
    final first = SecureSessionStorage('https://one.supabase.co');
    await first.initialize();
    expect(await first.hasAccessToken(), false);
    await first.persistSession('synthetic-session');
    final reopened = SecureSessionStorage('https://one.supabase.co');
    expect(await reopened.accessToken(), 'synthetic-session');
    expect(
      await SecureSessionStorage('https://two.supabase.co').hasAccessToken(),
      false,
    );
    await reopened.removePersistedSession();
    expect(await first.hasAccessToken(), false);
  });
  test(
    'Pending save followed by logout cannot resurrect a stored session',
    () async {
      final storage = SecureSessionStorage('https://one.supabase.co');
      final saving = storage.persistSession('synthetic-session');
      final deleting = storage.removePersistedSession();
      await Future.wait([saving, deleting]);
      expect(await storage.accessToken(), null);
    },
  );
}
