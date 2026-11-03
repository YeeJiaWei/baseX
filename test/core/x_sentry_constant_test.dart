import 'package:baseX/Core/index.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

class _ValidDsnSentry extends XSentryConstant {
  const _ValidDsnSentry();

  @override
  String get dsn => 'https://x@y/1';
}

class _PlaceholderDsnSentry extends XSentryConstant {
  const _PlaceholderDsnSentry();

  @override
  String get dsn => 'SET_ME';
}

class _BareConstant extends DefaultBaseConstant {}

void main() {
  test('XErrorTrackingConstant is enabled only outside debug unless overridden', () {
    expect(
      const XErrorTrackingConstant().enabled,
      !kDebugMode || XErrorTrackingConstant.debugOverride,
    );
  });

  test('XSentryConstant defaults: no DSN, development, full tracing, off', () {
    const sentry = XSentryConstant();
    expect(sentry.dsn, '');
    expect(sentry.hasValidDsn, isFalse);
    expect(sentry.environment, 'development');
    expect(sentry.tracesSampleRate, 1.0);
    expect(sentry.enabled, isFalse);
  });

  test('a subclass DSN with a URL is valid and follows the base enabled rule', () {
    const sentry = _ValidDsnSentry();
    expect(sentry.hasValidDsn, isTrue);
    expect(
      sentry.enabled,
      !kDebugMode || XErrorTrackingConstant.debugOverride,
    );
  });

  test('a placeholder DSN is invalid and keeps Sentry off', () {
    const sentry = _PlaceholderDsnSentry();
    expect(sentry.hasValidDsn, isFalse);
    expect(sentry.enabled, isFalse);
  });

  test('DefaultBaseConstant.errorTracking defaults to null', () {
    expect(_BareConstant().errorTracking, isNull);
  });
}
