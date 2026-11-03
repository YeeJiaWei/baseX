import 'package:baseX/base_x.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

/// Sentry settings with working defaults; subclass and override any getter, then return it from DefaultBaseConstant.errorTracking.
class XSentryConstant extends XErrorTrackingConstant {
  const XSentryConstant();

  /// The project DSN, written as a literal in the app's subclass; empty keeps Sentry off.
  String get dsn => '';

  /// The Sentry environment tag; the APP_ENV flavor name.
  String? get environment => flavorFromEnv().name;

  /// Share of transactions traced; 0.2 in production, 1.0 elsewhere.
  double get tracesSampleRate =>
      flavorFromEnv() == Flavor.production ? 0.2 : 1.0;

  /// Escape hatch to set any other [SentryFlutterOptions] after the getters above are applied.
  void configure(SentryFlutterOptions options) {}

  /// Whether [dsn] looks like a URL, so a placeholder never makes the SDK throw.
  bool get hasValidDsn => dsn.startsWith('http');

  /// Whether Sentry starts; the base rule plus a valid [dsn].
  @override
  bool get enabled => super.enabled && hasValidDsn;
}
