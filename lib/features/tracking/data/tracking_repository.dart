import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/networking/supabase_bootstrap.dart';

abstract interface class TrackingRepository {
  Future<List<Map<String, dynamic>>> read();
  Future<bool> control(String run, String publisher, String action);
  Future<bool> publish(
    String run,
    String publisher,
    Map<String, dynamic> sample,
  );
  Stream<void> changes();
}

class SupabaseTrackingRepository implements TrackingRepository {
  SupabaseTrackingRepository(this.client);
  final SupabaseClient client;
  @override
  Future<List<Map<String, dynamic>>> read() async =>
      (await client.rpc('tracking_workspace') as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
  @override
  Future<bool> control(String run, String publisher, String action) async =>
      await client.rpc(
        'tracking_control',
        params: {'target_run': run, 'publisher': publisher, 'action': action},
      ) as bool;
  @override
  Future<bool> publish(
    String run,
    String publisher,
    Map<String, dynamic> sample,
  ) async => await client.rpc(
    'publish_run_location',
    params: {'target_run': run, 'publisher': publisher, ...sample},
  ) as bool;
  @override
  Stream<void> changes() {
    final controller = StreamController<void>();
    final id = client.auth.currentUser?.id;
    if (id == null) {
      controller.close();
      return controller.stream;
    }
    final channel = client.channel(
      'tracking:$id',
      opts: const RealtimeChannelConfig(private: true),
    );
    controller.onListen = () {
      channel
          .onBroadcast(
            event: 'changed',
            callback: (_) {
              if (!controller.isClosed) controller.add(null);
            },
          )
          .subscribe();
    };
    controller.onCancel = () async {
      await client.removeChannel(channel);
    };
    return controller.stream;
  }
}

final trackingRepositoryProvider = FutureProvider<TrackingRepository>((
  ref,
) async {
  final client = await ref.watch(supabaseClientProvider.future);
  if (client == null) throw StateError('Backend unavailable');
  return SupabaseTrackingRepository(client);
});
