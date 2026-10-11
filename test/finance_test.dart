import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peksen_gida/app.dart';
import 'package:peksen_gida/core/routing/app_router.dart';
import 'package:peksen_gida/features/auth/domain/account_repository.dart';
import 'package:peksen_gida/features/auth/presentation/auth_providers.dart';
import 'package:peksen_gida/features/finance/data/finance_repository.dart';
import 'package:peksen_gida/features/finance/presentation/finance_page.dart';

import 'products_test.dart' show tapText;

class FinanceFake implements FinanceRepository {
  int reads = 0;
  bool failRead = false, failWrite = false, reject = false;
  Completer<void>? loading;
  Map<String, dynamic>? saved;
  final calls = <Map<String, dynamic>>[];
  final rows = <String, List<Map<String, dynamic>>>{
    'orders': [
      {
        'id': 'order',
        'name': 'Test firma',
        'amount_kurus': '20000',
        'balance_kurus': '15000',
        'due_date': null,
        'payments': [
          {
            'id': 'payment',
            'amount_kurus': '5000',
            'method': 'cash',
            'status': 'recorded',
            'collector_id': 'sales',
            'collected_at': '2026-10-11',
          },
        ],
      },
    ],
    'customers': [
      {
        'id': 'customer',
        'name': 'Test firma',
        'limit_kurus': null,
        'exposure_kurus': '15000',
      },
    ],
    'approvals': [
      {
        'id': 'approval',
        'order_id': 'pending',
        'name': 'Test firma',
        'amount_kurus': '10000',
        'exposure_kurus': '25000',
        'limit_kurus': '20000',
      },
    ],
  };
  @override
  Future<List<Map<String, dynamic>>> read(String section) async {
    reads++;
    await loading?.future;
    if (failRead) throw StateError('private detail');
    return rows[section]!;
  }

  @override
  Future<Map<String, dynamic>?> pending() async => saved;
  @override
  Future<void> perform(String action, Map<String, dynamic> params) async {
    final request = {'action': action, 'params': params};
    calls.add(request);
    saved = request;
    if (reject) {
      saved = null;
      throw const FinanceRejected();
    }
    if (failWrite) throw StateError('network');
    saved = null;
  }
}

Future<ProviderContainer> mountFinance(
  WidgetTester tester,
  FinanceFake fake, {
  AccountRole role = AccountRole.salesOperator,
}) async {
  final router = createAppRouter(
    previewEnabled: true,
    initialLocation: '/account/finance',
    isSignedIn: () => true,
  );
  final container = ProviderContainer(
    overrides: [
      appRouterProvider.overrideWithValue(router),
      accountProfileProvider.overrideWith(
        (_) async => AccountProfile(id: 'test', name: 'Test', role: role),
      ),
      financeRepositoryProvider.overrideWith((_) async => fake),
    ],
  );
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    container.dispose();
    router.dispose();
  });
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const PeksenGidaApp(),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
  return container;
}

void main() {
  for (final role in [AccountRole.customer, AccountRole.warehouse]) {
    testWidgets('${role.name} finance deep link denied without read', (
      tester,
    ) async {
      final fake = FinanceFake();
      await mountFinance(tester, fake, role: role);
      await tester.pumpAndSettle();
      expect(find.text('Bu ekrana erişim yetkiniz yok.'), findsOneWidget);
      expect(fake.reads, 0);
    });
  }
  testWidgets(
    'Sales partial POS payment uses exact cents and preserves retry payload',
    (tester) async {
      final fake = FinanceFake()..failWrite = true;
      await mountFinance(tester, fake);
      await tester.pumpAndSettle();
      await tapText(tester, 'Tahsilat kaydet');
      await tester.enterText(
        find.widgetWithText(TextField, 'Tutar (TL)'),
        '12,35',
      );
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('POS').last);
      await tester.pumpAndSettle();
      await tapText(tester, 'Kaydet');
      expect(fake.calls.single['params']['amount_kurus'], '1235');
      expect(fake.calls.single['params']['payment_method'], 'pos');
      expect(
        tester
            .widget<TextField>(find.widgetWithText(TextField, 'Tutar (TL)'))
            .readOnly,
        true,
      );
      fake.failWrite = false;
      await tapText(tester, 'Aynı isteği yeniden dene');
      expect(fake.calls[1], fake.calls[0]);
      expect(find.byType(AlertDialog), findsNothing);
    },
  );
  testWidgets('Payment zero and fractional cents rejected locally', (
    tester,
  ) async {
    final fake = FinanceFake();
    await mountFinance(tester, fake);
    await tester.pumpAndSettle();
    await tapText(tester, 'Tahsilat kaydet');
    for (final value in ['0', '-1', '1,001', 'NaN']) {
      await tester.enterText(
        find.widgetWithText(TextField, 'Tutar (TL)'),
        value,
      );
      await tapText(tester, 'Kaydet');
      expect(fake.calls, isEmpty);
    }
  });
  testWidgets('Accounting only verification, no collection/credit UI', (
    tester,
  ) async {
    final fake = FinanceFake();
    await mountFinance(tester, fake, role: AccountRole.accounting);
    await tester.pumpAndSettle();
    expect(find.text('Tahsilat kaydet'), findsNothing);
    expect(find.text('Cari limitler'), findsNothing);
    await tapText(tester, 'Doğrula');
    await tapText(tester, 'Kaydet');
    expect(fake.calls.single['action'], 'verify_payment');
    expect(fake.calls.single['params']['target_payment'], 'payment');
  });
  testWidgets('Owner credit reason required; explicit zero allowed', (
    tester,
  ) async {
    final fake = FinanceFake();
    await mountFinance(tester, fake, role: AccountRole.owner);
    await tester.pumpAndSettle();
    await tapText(tester, 'Cari limitler');
    await tapText(tester, 'Limit belirle');
    await tester.enterText(find.widgetWithText(TextField, 'Tutar (TL)'), '0');
    await tapText(tester, 'Kaydet');
    expect(fake.calls, isEmpty);
    await tester.enterText(
      find.widgetWithText(TextField, 'Gerekçe (zorunlu)'),
      'Müşteri değerlendirmesi',
    );
    await tapText(tester, 'Kaydet');
    expect(fake.calls.single['action'], 'set_customer_credit_limit');
    expect(fake.calls.single['params']['limit_kurus'], '0');
  });
  testWidgets(
    'Manager credit approval and rejection send reason without revision',
    (tester) async {
      final fake = FinanceFake();
      await mountFinance(tester, fake, role: AccountRole.manager);
      await tester.pumpAndSettle();
      await tapText(tester, 'Cari onaylar');
      for (final title in ['Onayla', 'Reddet']) {
        await tapText(tester, title);
        await tester.enterText(
          find.widgetWithText(TextField, 'Gerekçe (zorunlu)'),
          'Karar',
        );
        await tapText(tester, 'Kaydet');
        expect(fake.calls.last['action'], 'decide_credit_approval');
        expect(fake.calls.last['params']['approve'], title == 'Onayla');
      }
    },
  );
  testWidgets(
    'Uncertain persisted operation disables new payment until resolved',
    (tester) async {
      final fake = FinanceFake()
        ..saved = {
          'action': 'record_payment',
          'params': {
            'target_order': 'order',
            'amount_kurus': '500',
            'payment_method': 'cash',
            'payment_note': '',
            'request_key': 'original',
          },
        };
      final request = fake.saved;
      await mountFinance(tester, fake);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextButton>(
              find.widgetWithText(TextButton, 'Tahsilat kaydet'),
            )
            .onPressed,
        isNull,
      );
      await tapText(tester, 'Bekleyen işlemi yeniden dene');
      expect(fake.calls.single, request);
      expect(
        tester
            .widget<TextButton>(
              find.widgetWithText(TextButton, 'Tahsilat kaydet'),
            )
            .onPressed,
        isNotNull,
      );
    },
  );
  testWidgets('Unavailable balance blocks collection and verification', (
    tester,
  ) async {
    final fake = FinanceFake();
    fake.rows['orders']!.first['balance_kurus'] = null;
    await mountFinance(tester, fake);
    await tester.pumpAndSettle();
    expect(find.textContaining('inceleme gerektiriyor'), findsOneWidget);
    expect(
      tester
          .widget<TextButton>(
            find.widgetWithText(TextButton, 'Tahsilat kaydet'),
          )
          .onPressed,
      isNull,
    );
  });
  testWidgets('Loading error retry and empty list', (tester) async {
    final fake = FinanceFake()..loading = Completer<void>();
    final container = await mountFinance(tester, fake);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    fake.failRead = true;
    fake.loading!.complete();
    await tester.pumpAndSettle();
    expect(find.textContaining('Kayıtlar alınamadı'), findsOneWidget);
    expect(find.textContaining('private detail'), findsNothing);
    fake.failRead = false;
    fake.rows['orders']!.clear();
    container.invalidate(financeRowsProvider);
    await tester.pumpAndSettle();
    expect(find.text('Görüntülenecek kayıt yok.'), findsOneWidget);
  });
  testWidgets('Small screen keyboard and back navigation', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    await mountFinance(tester, FinanceFake());
    await tester.pumpAndSettle();
    await tapText(tester, 'Tahsilat kaydet');
    tester.view.viewInsets = FakeViewPadding(bottom: 250);
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Tutar (TL)'), '1');
    await tapText(tester, 'Kaydet');
    tester.view.resetViewInsets();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Hesabım'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
