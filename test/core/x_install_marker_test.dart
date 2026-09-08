import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:baseX/Core/index.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    XInstallMarker.reset();
    XAuthStore.reset();
  });

  tearDown(() {
    XInstallMarker.reset();
    XAuthStore.reset();
  });

  test('fresh when the key is absent', () async {
    SharedPreferences.setMockInitialValues({});

    final marker = XInstallMarker();

    expect(await marker.isFreshInstall, isTrue);
  });

  test('not fresh when the key is true', () async {
    SharedPreferences.setMockInitialValues({'install_marker': true});

    final marker = XInstallMarker();

    expect(await marker.isFreshInstall, isFalse);
  });

  test('memoised true after markSeen', () async {
    SharedPreferences.setMockInitialValues({});
    final marker = XInstallMarker();

    expect(await marker.isFreshInstall, isTrue);
    await marker.markSeen();

    expect(await marker.isFreshInstall, isTrue);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('install_marker'), isTrue);
  });

  test('whenFresh runs the handler once and marks seen', () async {
    SharedPreferences.setMockInitialValues({});
    final marker = XInstallMarker();
    var calls = 0;

    await marker.whenFresh(() async => calls++);

    expect(calls, 1);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('install_marker'), isTrue);
  });

  test('whenFresh skips the handler on a returning install', () async {
    SharedPreferences.setMockInitialValues({'install_marker': true});
    final marker = XInstallMarker();
    var calls = 0;

    await marker.whenFresh(() async => calls++);

    expect(calls, 0);
  });

  test('configure swaps the process-wide instance and its key', () async {
    SharedPreferences.setMockInitialValues({'custom_marker': true});

    XInstallMarker.configure(XInstallMarker(key: 'custom_marker'));

    expect(await XInstallMarker.instance.isFreshInstall, isFalse);
  });

  test(
    'XAuthStore.bind then XInstallMarker.instance.whenFresh: handler still runs and token was cleared',
    () async {
      SharedPreferences.setMockInitialValues({});

      final store = await XAuthStore.bind(InMemoryAuthDriver('leaked'));
      expect(store.cachedToken, isNull);

      var calls = 0;
      await XInstallMarker.instance.whenFresh(() async => calls++);

      expect(calls, 1);
    },
  );
}
