import 'package:flutter/services.dart';

abstract interface class LocationSource {
  Stream<Map<String, dynamic>> get samples;
  Future<bool> start();
  Future<void> stop();
}

class AndroidLocationSource implements LocationSource {
  static const _methods = MethodChannel('peksen/location');
  static const _events = EventChannel('peksen/location/events');
  @override
  Stream<Map<String, dynamic>> get samples => _events
      .receiveBroadcastStream()
      .map((e) => Map<String, dynamic>.from(e as Map));
  @override
  Future<bool> start() async =>
      await _methods.invokeMethod<bool>('start') ?? false;
  @override
  Future<void> stop() async {
    await _methods.invokeMethod<void>('stop');
  }
}
