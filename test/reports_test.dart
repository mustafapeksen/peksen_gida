import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peksen_gida/app.dart';
import 'package:peksen_gida/core/routing/app_router.dart';
import 'package:peksen_gida/features/auth/domain/account_repository.dart';
import 'package:peksen_gida/features/auth/presentation/auth_providers.dart';
import 'package:peksen_gida/features/reports/data/report_repository.dart';

import 'products_test.dart' show tapText;

class ReportFake implements ReportRepository {
  int reads = 0;
  bool fail = false, failSave = false, rejectSave = false;
  Completer<void>? loading;
  Map<String, dynamic>? saved;
  final writes = <Map<String, dynamic>>[];
  final queries = <List<String>>[];
  List<Map<String, dynamic>> auditRows = [];
  final data = <String, dynamic>{
    'as_of': '2026-10-13T10:00:00Z',
    'orders': [
      {'status': 'submitted', 'count': 2},
    ],
    'deliveries': {'count': 1, 'total_kurus': '10025'},
    'payments': [
      {'status': 'recorded', 'count': 1, 'total_kurus': '2050'},
    ],
    'inventory': [
      {
        'name': 'Test ürün',
        'base_unit': 'kg',
        'physical_qty': '4.5',
        'reserved_qty': '1.1',
        'available_qty': '3.4',
      },
    ],
    'ratings': [],
  };
  Future<void> check() async {
    reads++;
    await loading?.future;
    if (fail) throw StateError('sensitive payload');
  }

  @override
  Future<Map<String, dynamic>> report(String start, String end) async {
    await check();
    queries.add([start, end]);
    return data;
  }

  @override
  Future<Map<String, dynamic>> salaries(String month) async {
    await check();
    return {
      'employees': [
        {'id': 'employee', 'name': 'Sentetik Çalışan', 'active': true},
      ],
      'records': [],
      'history': [],
    };
  }

  @override
  Future<List<Map<String, dynamic>>> audit(String? time, String? id) async {
    await check();
    return time == null ? auditRows : [];
  }

  @override
  Future<Map<String, dynamic>?> pending() async => saved;
  @override
  Future<void> saveSalary(Map<String, dynamic> params) async {
    writes.add(Map.of(params));
    saved = params;
    if (rejectSave) {
      saved = null;
      throw const SalaryRejected();
    }
    if (failSave) throw StateError('network');
    saved = null;
  }
}

Future<ProviderContainer> mountReports(
  WidgetTester tester,
  ReportFake fake, {
  AccountRole role = AccountRole.manager,
  String section = 'reports',
  AccountRole? Function()? currentRole,
}) async {
  final router = createAppRouter(
    previewEnabled: true,
    initialLocation: '/account/$section',
    isSignedIn: () => true,
  );
  final container = ProviderContainer(
    overrides: [
      appRouterProvider.overrideWithValue(router),
      accountProfileProvider.overrideWith((_) async {
        final selected = currentRole == null ? role : currentRole();
        return selected == null
            ? null
            : AccountProfile(id: 'test', name: 'Test', role: selected);
      }),
      reportRepositoryProvider.overrideWith((_) async => fake),
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
  for (final role in [
    AccountRole.customer,
    AccountRole.salesOperator,
    AccountRole.warehouse,
    AccountRole.accounting,
    AccountRole.driver,
  ]) {
    for (final section in ['reports', 'salary', 'audit']) {
      testWidgets('${role.name} cannot deep link to $section', (tester) async {
        final fake = ReportFake();
        await mountReports(tester, fake, role: role, section: section);
        await tester.pumpAndSettle();
        expect(find.textContaining('erişim yetkiniz yok'), findsOneWidget);
        expect(fake.reads, 0);
      });
    }
  }
  for (final section in ['salary', 'audit']) {
    testWidgets('Manager cannot open $section', (tester) async {
      final fake = ReportFake();
      await mountReports(tester, fake, section: section);
      await tester.pumpAndSettle();
      expect(fake.reads, 0);
      expect(find.textContaining('erişim yetkiniz yok'), findsOneWidget);
    });
  }
  testWidgets(
    'Reports show exact totals and distinguish date/live/all-time scopes on small screen',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final fake = ReportFake();
      await mountReports(tester, fake);
      await tester.pumpAndSettle();
      expect(find.text('submitted: 2'), findsOneWidget);
      await tester.drag(find.byType(ListView), const Offset(0, -320));
      await tester.pumpAndSettle();
      expect(find.text('Sipariş toplamı: 100,25 TL'), findsOneWidget);
      expect(
        find.textContaining('Kaydedildi: 1 kayıt / 20,50 TL'),
        findsOneWidget,
      );
      await tester.drag(find.byType(ListView), const Offset(0, -700));
      await tester.pumpAndSettle();
      expect(find.text('Sürücü puanları — tüm zamanlar'), findsOneWidget);
      expect(find.text('Henüz puan yok.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'Revoked profile removes previous report without another repository read',
    (tester) async {
      AccountRole? role = AccountRole.manager;
      final fake = ReportFake();
      final container = await mountReports(
        tester,
        fake,
        currentRole: () => role,
      );
      await tester.pumpAndSettle();
      expect(find.text('submitted: 2'), findsOneWidget);
      role = AccountRole.accounting;
      container.invalidate(accountProfileProvider);
      await tester.pumpAndSettle();
      expect(find.text('submitted: 2'), findsNothing);
      expect(fake.reads, 1);
      expect(find.textContaining('erişim yetkiniz yok'), findsOneWidget);
    },
  );
  testWidgets('Report loading, safe error and refresh', (tester) async {
    final fake = ReportFake()..loading = Completer<void>();
    await mountReports(tester, fake);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    fake.fail = true;
    fake.loading!.complete();
    await tester.pumpAndSettle();
    expect(find.textContaining('sensitive payload'), findsNothing);
    expect(find.textContaining('Veri alınamadı'), findsOneWidget);
    fake.fail = false;
    await tester.tap(find.byTooltip('Yenile'));
    await tester.pumpAndSettle();
    expect(find.text('submitted: 2'), findsOneWidget);
  });
  testWidgets(
    'Owner salary validates reason and preserves exact cents and request on retry',
    (tester) async {
      final fake = ReportFake()..failSave = true;
      await mountReports(
        tester,
        fake,
        role: AccountRole.owner,
        section: 'salary',
      );
      await tester.pumpAndSettle();
      await tapText(tester, 'Kayıt oluştur');
      await tapText(tester, 'Kaydet');
      expect(fake.writes, isEmpty);
      await tester.enterText(
        find.widgetWithText(TextField, 'Maaş (TL)'),
        '12,35',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Prim (TL)'),
        '0,50',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Gerekçe'),
        'Manuel test',
      );
      await tapText(tester, 'Kaydet');
      expect(fake.writes.single['salary_kurus'], '1235');
      expect(fake.writes.single['bonus_kurus'], '50');
      expect(fake.writes.single['expected_revision'], -1);
      fake.failSave = false;
      await tapText(tester, 'Aynı isteği yeniden dene');
      expect(fake.writes[0], fake.writes[1]);
      expect(find.byType(AlertDialog), findsNothing);
    },
  );
  testWidgets(
    'Rejected stale salary is visible and must reload before a new edit',
    (tester) async {
      final fake = ReportFake()..rejectSave = true;
      await mountReports(
        tester,
        fake,
        role: AccountRole.owner,
        section: 'salary',
      );
      await tester.pumpAndSettle();
      await tapText(tester, 'Kayıt oluştur');
      await tester.enterText(find.widgetWithText(TextField, 'Gerekçe'), 'Test');
      await tapText(tester, 'Kaydet');
      expect(find.textContaining('İşlem reddedildi'), findsOneWidget);
      expect(fake.writes.length, 1);
      await tapText(tester, 'Kapat');
      expect(find.byType(AlertDialog), findsNothing);
    },
  );
  testWidgets('Pending salary survives page entry and blocks another write', (
    tester,
  ) async {
    final fake = ReportFake()
      ..saved = {'request_key': 'same', 'salary_kurus': '123'};
    await mountReports(
      tester,
      fake,
      role: AccountRole.owner,
      section: 'salary',
    );
    await tester.pumpAndSettle();
    expect(find.text('Sonucu bekleyen kayıt'), findsOneWidget);
    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Kayıt oluştur'),
    );
    expect(button.onPressed, isNull);
    await tapText(tester, 'Aynı isteği yeniden dene');
    expect(fake.writes.single['request_key'], 'same');
  });
  testWidgets(
    'Audit shows only projection and paginates, back returns to account',
    (tester) async {
      final fake = ReportFake()
        ..auditRows = List.generate(
          50,
          (i) => {
            'id': '$i',
            'created_at': '2026-10-13T00:00:00Z',
            'actor_name': 'Owner',
            'action': 'salary_changed',
            'entity_type': 'employee_salary_record',
            'entity_id': 'record',
            'new_data': 'sensitive',
          },
        );
      await mountReports(
        tester,
        fake,
        role: AccountRole.owner,
        section: 'audit',
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('sensitive'), findsNothing);
      await tester.scrollUntilVisible(
        find.text('Önceki kayıtlar'),
        700,
        scrollable: find.byType(Scrollable).first,
      );
      await tapText(tester, 'Önceki kayıtlar');
      expect(find.text('Bu sayfada audit kaydı yok.'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Hesabım'), findsOneWidget);
    },
  );
}
