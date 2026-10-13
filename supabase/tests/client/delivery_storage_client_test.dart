// Disposable LOCAL SDK acceptance. Credentials are supplied in memory by the
// existing runner, never printed. Reset local DB after this committed fixture.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'tracking_realtime_test.dart' show sql;

void main() {
  test('Local real SDK delivery and private Storage role/size/MIME boundaries', () async {
    final url = Platform.environment['PEKSEN_AUTH_TEST_URL'];
    final key = Platform.environment['PEKSEN_AUTH_TEST_KEY'];
    final password = Platform.environment['PEKSEN_AUTH_TEST_INPUT'];
    if (url != 'http://127.0.0.1:55321' || key == null || password == null) {
      throw TestFailure('Use the local auth test runner.');
    }
    Future<SupabaseClient> login(String email) async {
      final client = SupabaseClient(
        url!,
        key,
        authOptions: const AuthClientOptions(autoRefreshToken: false),
      );
      addTearDown(client.dispose);
      try {
        await client.auth.signInWithPassword(email: email, password: password);
      } catch (_) {
        throw TestFailure('Local login failed; sensitive details suppressed.');
      }
      return client;
    }

    var serial = 10;
    const order = '35000000-0000-4000-8000-000000000001';
    const run = '13000000-0000-4000-8000-000000000070';
    Future<Map> action(
      SupabaseClient client,
      String type, [
      Map<String, dynamic> extra = const {},
    ]) async => await client.rpc(
      'delivery_action',
      params: {
        'action': type,
        'data': {'order_id': order, ...extra},
        'request_key':
            '13000000-0000-4000-8000-${(serial++).toString().padLeft(12, '0')}',
      },
    ) as Map;
    try {
      await sql("""
        insert into vehicles(id,plate) values('$run','SDK-DELIVERY');
        insert into delivery_runs(id,vehicle_id,primary_driver_id,status,started_at)
         values('$run','$run','30000000-0000-4000-8000-000000000005','in_progress',now());
        update orders set status='out_for_delivery' where id='$order';
        insert into delivery_stops(run_id,order_id,sequence,status,assigned_by)
         values('$run','$order',1,'assigned','30000000-0000-4000-8000-000000000006');
      """);
      final driver = await login('driver@peksen.invalid');
      final customer = await login('customer.a@peksen.invalid');
      final manager = await login('manager@peksen.invalid');
      final accounting = await login('accounting@peksen.invalid');
      expect(
        (await action(driver, 'driver_confirm'))['status'],
        'delivery_pending_confirmation',
      );
      expect(
        (await action(customer, 'dispute', {
          'reason': 'Synthetic dispute',
        }))['status'],
        'delivery_disputed',
      );
      final reservation = await action(driver, 'evidence', {
        'mime_type': 'image/png',
      });
      final path = reservation['object_name'] as String;
      final png = base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/l1cAAAAASUVORK5CYII=',
      );
      const bucket = 'delivery-evidence';
      await driver.storage
          .from(bucket)
          .uploadBinary(
            path,
            png,
            fileOptions: const FileOptions(contentType: 'image/png'),
          );
      expect(await driver.storage.from(bucket).download(path), png);
      expect(await manager.storage.from(bucket).download(path), png);
      await expectLater(
        customer.storage.from(bucket).download(path),
        throwsA(isA<StorageException>()),
      );
      await expectLater(
        accounting.storage.from(bucket).download(path),
        throwsA(isA<StorageException>()),
      );
      final anon = SupabaseClient(url!, key);
      addTearDown(anon.dispose);
      await expectLater(
        anon.storage.from(bucket).download(path),
        throwsA(isA<StorageException>()),
      );
      await expectLater(
        driver.storage
            .from(bucket)
            .uploadBinary(
              path,
              png,
              fileOptions: const FileOptions(
                contentType: 'image/png',
                upsert: true,
              ),
            ),
        throwsA(isA<StorageException>()),
      );
      // DELETE can return no rows; verify that the original file still exists.
      try {
        await driver.storage.from(bucket).remove([path]);
      } on StorageException {
        /* denied */
      }
      expect(await driver.storage.from(bucket).download(path), png);
      final large =
          (await action(driver, 'evidence', {
                'mime_type': 'image/png',
              }))['object_name']
              as String;
      await expectLater(
        driver.storage
            .from(bucket)
            .uploadBinary(
              large,
              Uint8List(5242881),
              fileOptions: const FileOptions(contentType: 'image/png'),
            ),
        throwsA(isA<StorageException>()),
      );
      final bad =
          (await action(driver, 'evidence', {
                'mime_type': 'image/png',
              }))['object_name']
              as String;
      await expectLater(
        driver.storage
            .from(bucket)
            .uploadBinary(
              bad,
              Uint8List.fromList('html'.codeUnits),
              fileOptions: const FileOptions(contentType: 'text/html'),
            ),
        throwsA(isA<StorageException>()),
      );
      expect(
        (await action(manager, 'resolve', {
          'reason': 'Verified synthetic exception',
        }))['status'],
        'delivered',
      );
      await expectLater(
        driver.rpc(
          'record_payment',
          params: {
            'target_order': order,
            'amount_kurus': 1,
            'payment_method': 'cash',
            'payment_note': null,
            'request_key': '13000000-0000-4000-8000-000000000090',
          },
        ),
        throwsA(isA<PostgrestException>()),
      );
      expect(
        (await action(customer, 'rate', {
          'score': 5,
          'reasons': <String>[],
        }))['score'],
        5,
      );
      expect(await manager.storage.from(bucket).download(path), png);
      await expectLater(
        driver.storage
            .from(bucket)
            .uploadBinary(
              bad,
              png,
              fileOptions: const FileOptions(contentType: 'image/png'),
            ),
        throwsA(isA<StorageException>()),
      );
    } catch (error) {
      if (error is TestFailure) rethrow;
      throw TestFailure(
        'Local delivery/Storage operation failed (${error.runtimeType}); sensitive details suppressed.',
      );
    }
  }, timeout: const Timeout(Duration(minutes: 3)));
}
