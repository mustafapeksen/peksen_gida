import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../../../core/config/map_style_config.dart';

typedef TrackingMapBuilder = Widget Function(double latitude, double longitude);
final trackingMapBuilderProvider = Provider<TrackingMapBuilder>((ref) {
  final style = ref.watch(mapStyleConfigProvider);
  return (latitude, longitude) {
    if (style == null) {
      return const Center(child: Text('Harita sağlayıcısı yapılandırılmadı.'));
    }
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return const Center(
        child: Text('Harita Android uygulamasında görüntülenir.'),
      );
    }
    return TrackingMap(
      latitude: latitude,
      longitude: longitude,
      style: style.styleUrl,
    );
  };
});

class TrackingMap extends StatefulWidget {
  const TrackingMap({
    super.key,
    required this.latitude,
    required this.longitude,
    required this.style,
  });
  final double latitude, longitude;
  final String style;
  @override
  State<TrackingMap> createState() => _TrackingMapState();
}

class _TrackingMapState extends State<TrackingMap> {
  MapLibreMapController? controller;
  Circle? marker;
  bool ready = false;
  bool failed = false;
  LatLng get point => LatLng(widget.latitude, widget.longitude);
  Future<void> updateMarker() async {
    if (!ready || controller == null || !mounted) return;
    try {
      if (marker == null) {
        marker = await controller!.addCircle(
          CircleOptions(
            geometry: point,
            circleColor: '#176B48',
            circleRadius: 10,
            circleStrokeColor: '#ffffff',
            circleStrokeWidth: 3,
          ),
        );
      } else {
        await controller!.updateCircle(marker!, CircleOptions(geometry: point));
      }
      await controller!.moveCamera(CameraUpdate.newLatLng(point));
    } catch (_) {
      if (mounted) setState(() => failed = true);
    }
  }

  @override
  void didUpdateWidget(covariant TrackingMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.latitude != widget.latitude ||
        oldWidget.longitude != widget.longitude) {
      updateMarker();
    }
  }

  @override
  Widget build(BuildContext context) => failed
      ? const Center(
          child: Text('Harita yüklenemedi. Bağlantıyı kontrol edin.'),
        )
      : MapLibreMap(
          styleString: widget.style,
          initialCameraPosition: CameraPosition(target: point, zoom: 13),
          myLocationEnabled:
              false, // Customers never publish their own position.
          onMapCreated: (value) => controller = value,
          onStyleLoadedCallback: () {
            ready = true;
            updateMarker();
          },
        );
}
