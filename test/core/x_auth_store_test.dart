import 'dart:io';
import 'dart:ui';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:baseX/Core/index.dart';
import 'package:baseX/api_service/interceptor/auth_interceptor.dart';

/// [InMemoryAuthDriver] subclass that flags whether its [onFreshInstall]
/// override ran, to assert `bind()` calls the overridden driver hook.
class _FlaggingAuthDriver extends InMemoryAuthDriver {
  _FlaggingAuthDriver([super.initialToken]);

  bool freshInstallRan = false;

  @override
  Future<void> onFreshInstall() async {
    await super.onFreshInstall();
    freshInstallRan = true;
  }
}

/// [InMemoryAuthDriver] subclass that counts [read] calls, to assert
/// [XAuthStore.setToken] updates the cache directly instead of re-reading.
class _CountingReadDriver extends InMemoryAuthDriver {
  int readCalls = 0;

  @override
  Future<String?> read() {
    readCalls++;
    return super.read();
  }
}

/// [FlutterSecureStorage] subclass whose [read] always throws, simulating a
/// desynced Keystore key (BadPaddingException / BAD_DECRYPT).
class _ThrowingSecureStorage extends FlutterSecureStorage {
  const _ThrowingSecureStorage();

  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) =>
      throw PlatformException(code: 'BAD_DECRYPT');
}

class _FakeSharePref extends BaseXSharePref {
  String _token = '';

  @override
  // ignore: deprecated_member_use
  String get accessToken => _token;

  @override
  // ignore: deprecated_member_use
  set accessToken(String? value) => _token = value ?? '';

  @override
  Locale get languageCode => const Locale('en');

  @override
  set languageCode(Locale? value) {}

  @override
  void saveKeyWithValue(String key, value) {}
}

/// Runs the interceptor and returns the resolved request headers.
Map<String, dynamic> _headersFor({bool requiredToken = true}) {
  final options =
      RequestOptions(path: '/x', extra: {'requiredToken': requiredToken});
  AuthInterceptor().onRequest(options, RequestInterceptorHandler());
  return options.headers;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    XAuthStore.reset();
    XInstallMarker.reset();
    X = null;
    FlutterSecureStorage.setMockInitialValues({});
    // Marker present by default so unrelated tests aren't hit by the
    // fresh-install purge that `bind()` now runs automatically; the
    // 'bind fresh-install purge' group below overrides this per case.
    SharedPreferences.setMockInitialValues({'install_marker': true});
  });

  tearDown(() {
    XInstallMarker.reset();
  });

  group('SecureAuthDriver', () {
    test('bind hydrates the cache from secure storage', () async {
      FlutterSecureStorage.setMockInitialValues({'bearer_token': 'stored-token'});

      final store = await XAuthStore.bind(SecureAuthDriver());

      expect(store.cachedToken, 'stored-token');
      expect(store.hasToken, isTrue);
      expect(XAuthStore.instance, same(store));
    });

    test('setToken persists and updates the cache', () async {
      final store = await XAuthStore.bind(SecureAuthDriver());

      await store.setToken('fresh');

      expect(store.cachedToken, 'fresh');
      expect(await store.readToken(), 'fresh');
    });

    test('setToken(null) and setToken("") clear the token', () async {
      final store = await XAuthStore.bind(SecureAuthDriver());
      await store.setToken('fresh');

      await store.setToken(null);
      expect(store.cachedToken, isNull);
      expect(await store.readToken(), isNull);
      expect(store.hasToken, isFalse);

      await store.setToken('again');
      await store.setToken('');
      expect(store.cachedToken, isNull);
      expect(await store.readToken(), isNull);
    });

    test('honours a custom key', () async {
      FlutterSecureStorage.setMockInitialValues({'other_key': 'v'});

      final store = await XAuthStore.bind(SecureAuthDriver(key: 'other_key'));

      expect(store.cachedToken, 'v');
    });

    test('a read that throws (BAD_DECRYPT) recovers as logged out', () async {
      FlutterSecureStorage.setMockInitialValues({'bearer_token': 'undecryptable'});

      final store = await XAuthStore.bind(
        SecureAuthDriver(storage: const _ThrowingSecureStorage()),
      );

      expect(store.cachedToken, isNull);
      expect(store.hasToken, isFalse);
    });
  });

  group('cache contract', () {
    test('hydrate loads the cache from the driver', () async {
      final driver = InMemoryAuthDriver('preset');
      expect(driver.cachedToken, isNull);

      await driver.hydrate();

      expect(driver.cachedToken, 'preset');
    });

    test('setToken updates the cache directly, without re-reading', () async {
      final driver = await XAuthStore.bind(_CountingReadDriver());
      final readsBefore = driver.readCalls;

      await driver.setToken('fresh');

      expect(driver.cachedToken, 'fresh');
      expect(driver.readCalls, readsBefore);
    });

    test('readToken bypasses the cache', () async {
      final store = await XAuthStore.bind(SecureAuthDriver());
      expect(store.cachedToken, isNull);

      await const FlutterSecureStorage().write(key: 'bearer_token', value: 'external-write');

      expect(store.cachedToken, isNull);
      expect(await store.readToken(), 'external-write');
    });
  });

  group('singleton', () {
    test('instance throws before bind', () {
      expect(XAuthStore.maybeInstance, isNull);
      expect(() => XAuthStore.instance, throwsA(isA<StateError>()));
    });
  });

  group('AuthInterceptor', () {
    test('adds the header when the bound store has a token', () async {
      await XAuthStore.bind(InMemoryAuthDriver('abc'));

      final headers = _headersFor();

      expect(headers[HttpHeaders.authorizationHeader], 'Bearer abc');
    });

    test('omits the header when the bound store is empty', () async {
      await XAuthStore.bind(InMemoryAuthDriver());

      final headers = _headersFor();

      expect(headers.containsKey(HttpHeaders.authorizationHeader), isFalse);
    });

    test('omits the header when the request did not opt in', () async {
      await XAuthStore.bind(InMemoryAuthDriver('abc'));

      final headers = _headersFor(requiredToken: false);

      expect(headers.containsKey(HttpHeaders.authorizationHeader), isFalse);
    });

    test('falls back to X.accessToken when no store is bound', () async {
      // ignore: deprecated_member_use
      X = _FakeSharePref()..accessToken = 'legacy';

      final headers = _headersFor();

      expect(headers[HttpHeaders.authorizationHeader], 'Bearer legacy');
    });

    test('omits the header when the legacy token is empty', () async {
      X = _FakeSharePref();

      final headers = _headersFor();

      expect(headers.containsKey(HttpHeaders.authorizationHeader), isFalse);
    });
  });

  group('bind fresh-install purge', () {
    test('with no marker purges the token and sets the marker', () async {
      SharedPreferences.setMockInitialValues({});

      final store = await XAuthStore.bind(InMemoryAuthDriver('leaked'));

      expect(store.cachedToken, isNull);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('install_marker'), isTrue);
    });

    test('with marker present keeps the token', () async {
      SharedPreferences.setMockInitialValues({'install_marker': true});

      final store = await XAuthStore.bind(InMemoryAuthDriver('kept'));

      expect(store.cachedToken, 'kept');
    });

    test('with purgeOnFreshInstall false keeps the token and skips the marker', () async {
      SharedPreferences.setMockInitialValues({});

      final store = await XAuthStore.bind(
        InMemoryAuthDriver('kept'),
        purgeOnFreshInstall: false,
      );

      expect(store.cachedToken, 'kept');
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('install_marker'), isNull);
    });

    test('runs a driver subclass override of onFreshInstall', () async {
      SharedPreferences.setMockInitialValues({});
      final driver = _FlaggingAuthDriver('leaked');

      final store = await XAuthStore.bind(driver);

      expect(driver.freshInstallRan, isTrue);
      expect(store.cachedToken, isNull);
    });

    test('honours a custom marker key', () async {
      // Default key already marked, but bind is told to use a different one,
      // so it must still see this as a fresh install under that key.
      SharedPreferences.setMockInitialValues({'install_marker': true});

      final store = await XAuthStore.bind(
        InMemoryAuthDriver('leaked'),
        installMarker: XInstallMarker(key: 'custom_marker'),
      );

      expect(store.cachedToken, isNull);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('custom_marker'), isTrue);
    });
  });
}
