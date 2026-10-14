import 'package:flutter_test/flutter_test.dart';

import 'package:baseX/Core/index.dart';

import 'fake_push_driver.dart';

void main() {
  final fcmDriver = FakePushDriver();
  final hmsDriver = FakePushDriver()..provider = PushProvider.hms;

  Future<PushDriver?> resolve({
    bool isIOS = false,
    bool gms = false,
    bool hms = false,
  }) => resolvePushDriver(
    fcm: () => fcmDriver,
    hms: () => hmsDriver,
    isIOS: isIOS,
    isGms: () async => gms,
    isHms: () async => hms,
  );

  test('iOS uses FCM', () async {
    expect(await resolve(isIOS: true), same(fcmDriver));
  });

  test('a device with Google services uses FCM', () async {
    expect(await resolve(gms: true, hms: true), same(fcmDriver));
  });

  test('a device with HMS and no Google services uses HMS', () async {
    expect(await resolve(hms: true), same(hmsDriver));
  });

  test('a device with neither has no push driver', () async {
    expect(await resolve(), isNull);
  });

  test('a failing check falls back to FCM', () async {
    final driver = await resolvePushDriver(
      fcm: () => fcmDriver,
      hms: () => hmsDriver,
      isIOS: false,
      isGms: () async => throw StateError('boom'),
    );

    expect(driver, same(fcmDriver));
  });
}
