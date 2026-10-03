import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Tests may disable the preview. The router independently enforces kDebugMode,
/// so a provider override cannot enable it in profile or release builds.
final developmentPreviewEnabledProvider = Provider<bool>((ref) => kDebugMode);
