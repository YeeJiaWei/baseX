import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:baseX/Core/index.dart';
import 'package:baseX/api_service/client/default_api_x_service.dart';
import 'package:baseX/api_service/support/api_request_mixin.dart';
import 'package:baseX/custom_error/index.dart';

/// Scripted transport: answers every request from [respond] and records the
/// [RequestOptions] the interceptor stack actually produced.
class _ScriptedAdapter implements HttpClientAdapter {
  _ScriptedAdapter(this.respond);

  final Future<ResponseBody> Function(RequestOptions options) respond;
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return respond(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _json(Map<String, Object?> body, int statusCode) =>
    ResponseBody.fromString(
      jsonEncode(body),
      statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );

/// Legacy shared-preference token holder — proves the deprecated fallback is
/// not consulted while a store is bound.
class _LegacySharePref extends BaseXSharePref {
  _LegacySharePref(this._token);

  String _token;

  @override
  // ignore: deprecated_member_use_from_same_package
  String get accessToken => _token;

  @override
  // ignore: deprecated_member_use_from_same_package
  set accessToken(String? value) => _token = value ?? '';

  @override
  Locale get languageCode => const Locale('en');

  @override
  set languageCode(Locale? value) {}

  @override
  void saveKeyWithValue(String key, value) {}
}

/// [InMemoryAuthDriver] that counts its lifecycle hooks.
class _RecordingDriver extends InMemoryAuthDriver {
  _RecordingDriver([super.initialToken]);

  int signedOutCalls = 0;
  int unauthorizedCalls = 0;

  @override
  Future<void> onSignedOut() async {
    await super.onSignedOut();
    signedOutCalls++;
  }

  @override
  Future<void> onUnauthorized() async {
    await super.onUnauthorized();
    unauthorizedCalls++;
  }
}

/// [FlutterSecureStorage] whose [read] always throws, simulating a desynced
/// Keystore key (BadPaddingException / BAD_DECRYPT).
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

/// Connection that lets the mapped exception escape instead of routing it to
/// the [ApiRequestMixin.run] callbacks, so tests can assert the error type.
class _RethrowingService extends DefaultApiXService {
  _RethrowingService(super.endpoint);

  @override
  Future<Response?> run(
    Future<Response> Function() request, {
    OnSuccess? onSuccess,
    OnError? onError,
    OnTimeout? onTimeout,
    OnComplete? onComplete,
  }) =>
      request();
}

/// Builds a connection over the real standard interceptor stack, with the
/// transport swapped for [adapter].
DefaultApiXService _service(_ScriptedAdapter adapter) =>
    DefaultApiXService('https://example.test')..httpClientAdapter = adapter;

String? _sentBearer(RequestOptions options) =>
    options.headers[HttpHeaders.authorizationHeader] as String?;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    baseConstant = DefaultBaseConstant();
    XAuthStore.reset();
    XInstallMarker.reset();
    X = null;
    SharedPreferences.setMockInitialValues({'install_marker': true});
    FlutterSecureStorage.setMockInitialValues({});
  });

  tearDown(() {
    XAuthStore.reset();
    XInstallMarker.reset();
    X = null;
  });

  group('bearer header', () {
    test('an authed request carries the cached token', () async {
      await XAuthStore.bind(InMemoryAuthDriver('live'),
          purgeOnFreshInstall: false);
      final adapter = _ScriptedAdapter((_) async => _json({'ok': true}, 200));

      await _service(adapter).get('me');

      expect(_sentBearer(adapter.requests.single), 'Bearer live');
    });

    test('requiredToken: false carries no bearer', () async {
      await XAuthStore.bind(InMemoryAuthDriver('live'),
          purgeOnFreshInstall: false);
      final adapter = _ScriptedAdapter((_) async => _json({'ok': true}, 200));

      await _service(adapter).get('public', requiredToken: false);

      expect(_sentBearer(adapter.requests.single), isNull);
    });

    test('a bound but empty store never falls back to the legacy token',
        () async {
      X = _LegacySharePref('legacy-token');
      await XAuthStore.bind(InMemoryAuthDriver(), purgeOnFreshInstall: false);
      final adapter = _ScriptedAdapter((_) async => _json({'ok': true}, 200));

      await _service(adapter).get('me');

      expect(_sentBearer(adapter.requests.single), isNull);
    });

    test('the legacy token is used only while no store is bound', () async {
      X = _LegacySharePref('legacy-token');
      final adapter = _ScriptedAdapter((_) async => _json({'ok': true}, 200));

      await _service(adapter).get('me');

      expect(_sentBearer(adapter.requests.single), 'Bearer legacy-token');
    });
  });

  group('401 handling', () {
    test('clears the token, raises UnauthorizedException, and the next '
        'request carries no bearer', () async {
      final driver = _RecordingDriver('live');
      await XAuthStore.bind(driver, purgeOnFreshInstall: false);
      final adapter = _ScriptedAdapter(
        (options) async => _sentBearer(options) == 'Bearer live'
            ? _json({'message': 'Unauthenticated.'}, 401)
            : _json({'ok': true}, 200),
      );
      final service = _service(adapter);

      Response? failure;
      await service.get('me', onError: (r) => failure = r);

      expect(failure?.statusCode, 401);
      expect(driver.unauthorizedCalls, 1);
      expect(driver.cachedToken, isNull);
      expect(await driver.readToken(), isNull);

      await service.get('me');
      expect(_sentBearer(adapter.requests.last), isNull);
    });

    test('the caller receives an UnauthorizedException', () async {
      await XAuthStore.bind(InMemoryAuthDriver('live'),
          purgeOnFreshInstall: false);
      final adapter =
          _ScriptedAdapter((_) async => _json({'message': 'nope'}, 401));
      final service = _RethrowingService('https://example.test')
        ..httpClientAdapter = adapter;

      await expectLater(
        service.get('me'),
        throwsA(isA<UnauthorizedException>()),
      );
    });

    test('a 401 whose bearer was already replaced leaves the new token',
        () async {
      final driver = _RecordingDriver('old');
      await XAuthStore.bind(driver, purgeOnFreshInstall: false);
      final arrived = Completer<void>();
      final release = Completer<void>();
      final adapter = _ScriptedAdapter((_) async {
        if (!arrived.isCompleted) arrived.complete();
        await release.future;
        return _json({'message': 'nope'}, 401);
      });

      final inFlight = _service(adapter).get('me', onError: (_) {});
      await arrived.future;
      await driver.signIn('new');
      release.complete();
      await inFlight;

      expect(_sentBearer(adapter.requests.single), 'Bearer old');
      expect(driver.cachedToken, 'new');
      expect(driver.unauthorizedCalls, 0);
    });

    test('a 401 on a requiredToken: false request leaves the token', () async {
      final driver = _RecordingDriver('live');
      await XAuthStore.bind(driver, purgeOnFreshInstall: false);
      final adapter =
          _ScriptedAdapter((_) async => _json({'message': 'nope'}, 401));

      await _service(adapter).get('public', requiredToken: false,
          onError: (_) {});

      expect(driver.cachedToken, 'live');
      expect(driver.unauthorizedCalls, 0);
    });

    test('a 500 leaves the token', () async {
      final driver = _RecordingDriver('live');
      await XAuthStore.bind(driver, purgeOnFreshInstall: false);
      final adapter =
          _ScriptedAdapter((_) async => _json({'message': 'boom'}, 500));

      await _service(adapter).get('me', onError: (_) {});

      expect(driver.cachedToken, 'live');
      expect(driver.unauthorizedCalls, 0);
    });

    test('a non-map error body still completes the request', () async {
      final driver = _RecordingDriver('live');
      await XAuthStore.bind(driver, purgeOnFreshInstall: false);
      final adapter = _ScriptedAdapter(
        (_) async => ResponseBody.fromString('<html>gateway</html>', 502),
      );

      Response? failure;
      await _service(adapter)
          .get('me', onError: (r) => failure = r)
          .timeout(const Duration(seconds: 5));

      expect(failure?.statusCode, 502);
      expect(driver.cachedToken, 'live');
    });

    test('envelope mode raises onUnauthorized for a 200-with-code-401 body',
        () async {
      baseConstant.success200 = true;
      final driver = _RecordingDriver('live');
      await XAuthStore.bind(driver, purgeOnFreshInstall: false);
      final adapter = _ScriptedAdapter(
        (_) async => _json(
          {'code': 401, 'status': false, 'message': 'Unauthenticated.'},
          200,
        ),
      );

      await _service(adapter).get('me', onError: (_) {});

      expect(driver.unauthorizedCalls, 1);
      expect(driver.cachedToken, isNull);
    });
  });

  group('signOut', () {
    test('a throwing remote revoke still clears the token and signs out',
        () async {
      final driver = _RecordingDriver('live');
      await XAuthStore.bind(driver, purgeOnFreshInstall: false);

      await driver.signOut(
        remote: () async => throw DioException(
          requestOptions: RequestOptions(path: '/logout'),
          type: DioExceptionType.connectionError,
        ),
      );

      expect(driver.cachedToken, isNull);
      expect(await driver.readToken(), isNull);
      expect(driver.signedOutCalls, 1);
    });
  });

  group('install marker across launches', () {
    test('bind purges, whenFresh still fires this launch, and the next '
        'process reads not-fresh', () async {
      SharedPreferences.setMockInitialValues({});
      final driver = _RecordingDriver('leaked');

      await XAuthStore.bind(driver);
      expect(driver.cachedToken, isNull, reason: 'fresh install purges');

      // The runXApp hook runs after bind and must still see "fresh".
      var hookRan = 0;
      await XInstallMarker.instance.whenFresh(() async => hookRan++);
      expect(hookRan, 1);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('install_marker'), isTrue);

      // Next cold start: a new marker object re-reads the persisted flag.
      expect(await XInstallMarker().isFreshInstall, isFalse);
    });

    test('an existing install keeps its session', () async {
      SharedPreferences.setMockInitialValues({'install_marker': true});
      final driver = _RecordingDriver('live');

      await XAuthStore.bind(driver);

      expect(driver.cachedToken, 'live');
    });
  });

  group('unreadable secure storage', () {
    test('bind completes logged out and still marks the install seen',
        () async {
      SharedPreferences.setMockInitialValues({});

      await XAuthStore.bind(
        SecureAuthDriver(storage: const _ThrowingSecureStorage()),
      );

      expect(XAuthStore.instance.cachedToken, isNull);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('install_marker'), isTrue);
    });
  });
}
