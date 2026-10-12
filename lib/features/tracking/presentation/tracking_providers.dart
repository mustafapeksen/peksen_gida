import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/domain/account_repository.dart';
import '../../auth/domain/auth_repository.dart';
import '../../auth/presentation/auth_providers.dart';
import '../data/tracking_repository.dart';
import '../domain/location_source.dart';
import '../domain/tracking_publisher.dart';

bool canUseTracking(AccountRole role) => const {
  AccountRole.customer,
  AccountRole.driver,
  AccountRole.manager,
  AccountRole.owner,
}.contains(role);

final locationSourceProvider = Provider<LocationSource>(
  (ref) => AndroidLocationSource(),
);
// Kept alive across page navigation; an auth identity change disposes the publisher.
final trackingPublisherProvider = FutureProvider<TrackingPublisher>(
  retry: (_, _) => null,
  (ref) async {
    final identity = ref.watch(
      authSessionProvider.select((s) => s.asData?.value.userId),
    );
    if (identity == null) throw const AccountAccessException();
    final repository = await ref.watch(trackingRepositoryProvider.future);
    final source = ref.watch(locationSourceProvider);
    if (!ref.mounted) throw const AccountAccessException();
    final publisher = TrackingPublisher(repository, source);
    ref.onDispose(publisher.dispose);
    return publisher;
  },
);

final trackingChangesProvider = StreamProvider.autoDispose<void>((ref) async* {
  final session = ref.watch(authSessionProvider).asData?.value;
  if (session?.status != AuthSessionStatus.signedIn) return;
  final profile = await ref.watch(accountProfileProvider.future);
  if (profile == null || !canUseTracking(profile.role)) return;
  final repository = await ref.watch(trackingRepositoryProvider.future);
  // Register this authorized viewer even if dispatch is opened before the map.
  // The read also rechecks access; only invalidations travel on the channel.
  await repository.read();
  yield* repository.changes();
});

final trackingDataProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>(
      retry: (_, _) => null,
      (ref) async {
        final profile = await ref.watch(accountProfileProvider.future);
        if (profile == null || !canUseTracking(profile.role)) {
          throw const AccountAccessException();
        }
        return (await ref.watch(trackingRepositoryProvider.future)).read();
      },
    );
