import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peksen_gida/app.dart';
import 'package:peksen_gida/core/config/supabase_config.dart';
import 'package:peksen_gida/core/networking/supabase_bootstrap.dart';
import 'package:peksen_gida/features/auth/data/supabase_auth_repository.dart';
import 'package:peksen_gida/features/auth/domain/auth_repository.dart';
import 'package:peksen_gida/features/auth/presentation/auth_providers.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

SupabaseConfig get testConfig => SupabaseConfig.fromValues(
  url: 'https://synthetic.supabase.co',
  publishableKey: 'sb_publishable_synthetic_only',
)!;

class FakeAuthClient extends GoTrueClient {
  FakeAuthClient() : super(autoRefreshToken: false);
  final events = StreamController<AuthState>.broadcast();
  Session? snapshot;

  @override
  Stream<AuthState> get onAuthStateChange => events.stream;
  @override
  Session? get currentSession => snapshot;

  @override
  Future<void> dispose() async {
    await events.close();
    super.dispose();
  }
}

Session syntheticSession() => Session(
  accessToken: 'synthetic-not-a-token',
  tokenType: 'bearer',
  user: const User(
    id: 'synthetic-user',
    appMetadata: {},
    userMetadata: {'role': 'owner'},
    aud: 'authenticated',
    createdAt: '2026-10-03T00:00:00Z',
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Yapılandırma yoksa SDK çağrılmaz; auth unavailable olur', () async {
    var calls = 0;
    final container = ProviderContainer(
      overrides: [
        supabaseConfigProvider.overrideWithValue(null),
        supabaseInitializerProvider.overrideWithValue((_) async {
          calls++;
          throw StateError('must not initialize');
        }),
      ],
    );
    addTearDown(container.dispose);
    container.listen(authSessionProvider, (_, _) {});
    expect(await container.read(supabaseClientProvider.future), isNull);
    expect(
      (await container.read(authSessionProvider.future)).status,
      AuthSessionStatus.unavailable,
    );
    expect(calls, 0);
  });

  test('Eşzamanlı okuyucular tek istemci başlangıcını paylaşır', () async {
    var calls = 0;
    final client = SupabaseClient(
      testConfig.url,
      testConfig.clientKey,
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );
    addTearDown(client.dispose);
    final container = ProviderContainer(
      overrides: [
        supabaseConfigProvider.overrideWithValue(testConfig),
        supabaseInitializerProvider.overrideWithValue((config) async {
          calls++;
          expect(config.url, testConfig.url);
          return client;
        }),
      ],
    );
    addTearDown(container.dispose);
    final clients = await Future.wait([
      container.read(supabaseClientProvider.future),
      container.read(supabaseClientProvider.future),
    ]);
    expect(clients, everyElement(same(client)));
    expect(calls, 1);
  });

  test('Gerçek SDK başlangıcı oturum saklamadan ağsız tamamlanır', () async {
    final client = await initializeSupabaseClient(testConfig);
    addTearDown(() => Supabase.instance.dispose());
    expect(client.auth.currentSession, isNull);
    final state = await SupabaseAuthRepository(client.auth)
        .watchSession()
        .first;
    expect(state.status, AuthSessionStatus.signedOut);
  });

  test(
    'Başlangıç hatası hassas ayrıntıyı dışarı taşımaz veya tekrar denemez',
    () async {
      var calls = 0;
      final container = ProviderContainer(
        overrides: [
          supabaseConfigProvider.overrideWithValue(testConfig),
          supabaseInitializerProvider.overrideWithValue((_) async {
            calls++;
            throw StateError('sensitive-request-detail');
          }),
        ],
      );
      addTearDown(container.dispose);
      await expectLater(
        container.read(supabaseClientProvider.future),
        throwsA(isA<BackendInitializationException>()),
      );
      expect(
        container.read(supabaseClientProvider).error.toString(),
        isNot(contains('sensitive-request-detail')),
      );
      expect(calls, 1);
    },
  );

  test(
    'Auth ilk snapshot, giriş/çıkış, hata ve abonelik iptalini aktarır',
    () async {
      final auth = FakeAuthClient()..snapshot = syntheticSession();
      addTearDown(auth.dispose);
      final states = <AuthSession>[];
      final errors = <Object>[];
      final subscription = SupabaseAuthRepository(auth)
          .watchSession()
          .listen(states.add, onError: errors.add);
      await Future<void>.delayed(Duration.zero);
      expect(states.single.userId, 'synthetic-user');
      auth.events.add(const AuthState(AuthChangeEvent.signedOut, null));
      auth.events.add(AuthState(AuthChangeEvent.signedIn, syntheticSession()));
      auth.events.addError(StateError('sensitive-auth-detail'));
      await Future<void>.delayed(Duration.zero);
      expect(states.map((s) => s.status), [
        AuthSessionStatus.signedIn,
        AuthSessionStatus.signedOut,
        AuthSessionStatus.signedIn,
      ]);
      expect(errors.single, isA<AuthObservationException>());
      expect(
        errors.single.toString(),
        isNot(contains('sensitive-auth-detail')),
      );
      await subscription.cancel();
      expect(auth.events.hasListener, isFalse);
    },
  );

  testWidgets('Başlangıç sürerken ve hata sonrası önizleme kullanılabilir', (
    tester,
  ) async {
    final pending = Completer<SupabaseClient>();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          supabaseConfigProvider.overrideWithValue(testConfig),
          supabaseInitializerProvider.overrideWithValue((_) => pending.future),
        ],
        child: const PeksenGidaApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Bağlantı hazırlanıyor…'), findsOneWidget);
    pending.completeError(StateError('sensitive-init-detail'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Bağlantı hazırlığı tamamlanamadı.'),
      findsOneWidget,
    );
    expect(find.textContaining('sensitive-init-detail'), findsNothing);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const ValueKey('login-submit')))
          .onPressed,
      isNull,
    );
    final preview = find.byKey(const ValueKey('preview-entry'));
    await tester.ensureVisible(preview);
    await tester.tap(preview);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('role-owner')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('İstemci hazır olsa da giriş kapalı ve önizleme bağımsızdır', (
    tester,
  ) async {
    // The SDK owns an isolate; create/dispose it outside the widget fake clock.
    final client = (await tester.runAsync(
      () async => SupabaseClient(
        testConfig.url,
        testConfig.clientKey,
        authOptions: const AuthClientOptions(autoRefreshToken: false),
      ),
    ))!;
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.runAsync(client.dispose);
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          supabaseConfigProvider.overrideWithValue(testConfig),
          supabaseInitializerProvider.overrideWithValue((_) async => client),
        ],
        child: const PeksenGidaApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.textContaining('sunucu bağlantısı doğrulanmadı'),
      findsOneWidget,
    );
    expect(
      tester
          .widget<FilledButton>(find.byKey(const ValueKey('login-submit')))
          .onPressed,
      isNull,
    );
    expect(client.auth.currentSession, isNull);
    expect(tester.takeException(), isNull);
  });
}
