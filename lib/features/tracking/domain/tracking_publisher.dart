import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/tracking_repository.dart';
import 'location_source.dart';

/// App-scoped publisher. Samples and publisher IDs are never persisted or queued.
class TrackingPublisher extends ChangeNotifier {
  TrackingPublisher(
    this.repository,
    this.source, {
    this.interval = const Duration(seconds: 15),
  });
  final TrackingRepository repository;
  final LocationSource source;
  final Duration interval;
  String? run;
  String? _publisher;
  String message = 'Konum paylaşımı kapalı.';
  StreamSubscription<Map<String, dynamic>>? _subscription;
  Timer? _timer;
  bool _busy = false;
  bool _checking = false;
  bool _disposed = false;
  DateTime? _lastContact;
  int _generation = 0;
  void _notify(String value) {
    message = value;
    if (!_disposed) notifyListeners();
  }

  Future<void> start(String target, String publisher) async {
    await stop();
    final generation = ++_generation;
    try {
      if (!await repository.control(target, publisher, 'start')) {
        _notify('Bu sefer için paylaşım kapalı.');
        return;
      }
      if (generation != _generation || _disposed) return;
      run = target;
      _publisher = publisher;
      _lastContact = DateTime.now();
      _subscription = source.samples.listen(
        (sample) => unawaited(_send(sample)),
        onError: (_) => unawaited(stop()),
      );
      if (!await source.start()) {
        await _send({'tracking_status': 'permission_denied'});
        await stop(clearRemote: false);
        _notify(
          'Takip sorunu: konum veya bildirim izni verilmedi. Sipariş ve sefer değişmedi. Android uygulama izinlerini kontrol edip yeniden deneyin.',
        );
        return;
      }
      if (generation != _generation || _disposed) {
        await source.stop();
        return;
      }
      _notify('Konum paylaşımı açık. Hedef aralık 15 saniye.');
      _timer = Timer.periodic(interval, (_) => unawaited(checkScope()));
    } catch (_) {
      await stop();
      _notify('Konum paylaşımı başlatılamadı.');
    }
  }

  Future<void> _send(Map<String, dynamic> sample) async {
    final target = run;
    final publisher = _publisher;
    if (target == null || publisher == null || _busy) return;
    if (sample['tracking_status'] == 'stopped') {
      await stop();
      return;
    }
    _busy = true;
    try {
      final allowed = await repository.publish(target, publisher, sample);
      if (run != target || _publisher != publisher) return;
      if (!allowed) {
        await stop(clearRemote: false);
        return;
      }
      _lastContact = DateTime.now();
      _notify(
        sample['tracking_status'] == 'live'
            ? 'Konum güncellendi.'
            : 'GPS kapalı veya konum izni kaldırıldı.',
      );
    } catch (_) {
      _notify('Bağlantı yok. Konum saklanmıyor; yeni ölçüm beklenecek.');
    } finally {
      _busy = false;
    }
  }

  Future<void> checkScope() async {
    final target = run;
    final publisher = _publisher;
    if (target == null || publisher == null || _checking) return;
    _checking = true;
    try {
      final allowed = await repository.control(target, publisher, 'check');
      if (run != target || _publisher != publisher) return;
      if (!allowed) {
        await stop(clearRemote: false);
        return;
      }
      _lastContact = DateTime.now();
    } catch (_) {
      if (_lastContact != null &&
          DateTime.now().difference(_lastContact!) >=
              const Duration(seconds: 60)) {
        await stop(clearRemote: false);
        _notify('Takip yetkisi doğrulanamadı. Yeniden başlatın.');
      }
    } finally {
      _checking = false;
    }
  }

  Future<void> stop({bool clearRemote = true}) async {
    ++_generation;
    final target = run;
    final publisher = _publisher;
    run = null;
    _publisher = null;
    _timer?.cancel();
    _timer = null;
    await _subscription?.cancel();
    _subscription = null;
    try {
      await source.stop();
    } catch (_) {
      /* No native channel on unsupported platforms. */
    }
    _notify('Konum paylaşımı kapalı.');
    if (clearRemote && target != null && publisher != null) {
      try {
        await repository.control(target, publisher, 'stop');
      } catch (_) {
        /* Server freshness expires; no offline retry queue. */
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(stop());
    super.dispose();
  }
}
