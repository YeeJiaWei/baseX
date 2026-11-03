import 'package:flutter/foundation.dart';

/// Base error tracking settings BaseConstant.errorTracking can return; every member has a default, so apps subclass only to override.
class ErrorTrackingConstant {
  const ErrorTrackingConstant();

  /// Turns tracking on in debug builds too, via --dart-define=ERROR_TRACKING_DEBUG=true.
  static const bool debugOverride = bool.fromEnvironment('ERROR_TRACKING_DEBUG');

  /// Whether tracking starts; on in release and profile builds, and in debug only with [debugOverride].
  bool get enabled => !kDebugMode || debugOverride;
}
