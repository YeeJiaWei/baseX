import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:baseX/Core/index.dart';
import 'package:baseX/api_service/interceptor/api_error_interceptor.dart';
import 'package:baseX/api_service/support/http_type_x.dart';

/// [InMemoryAuthDriver] subclass that records every lifecycle hook call.
class _RecordingDriver extends InMemoryAuthDriver {
  _RecordingDriver([super.initialToken]);

  final List<Map<String, Object?>> signedInMeta = [];
  final List<String?> signedInPreviousTokens = [];
  int signedOutCalls = 0;
  int unauthorizedCalls = 0;

  @override
  Future<void> onSignedIn(Map<String, Object?> meta, {String? previousToken}) async {
    await super.onSignedIn(meta, previousToken: previousToken);
    signedInMeta.add(meta);
    signedInPreviousTokens.add(previousToken);
  }

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

/// Builds a 401 [DioException] as the transport would deliver it.
DioException _unauthorizedError({
  required bool requiredToken,
  String? bearer,
  int statusCode = 401,
}) {
  final options = RequestOptions(
    path: '/x',
    extra: {'requiredToken': requiredToken},
    headers: {
      if (bearer != null) HttpHeaders.authorizationHeader: 'Bearer $bearer',
    },
  );
  return DioException(
    requestOptions: options,
    type: DioExceptionType.badResponse,
    response: Response(
      requestOptions: options,
      statusCode: statusCode,
      data: const {'message': 'x'},
    ),
  );
}

/// [ErrorInterceptorHandler] that records the outcome instead of completing a
/// future nothing in the test would consume.
class _CapturingHandler extends ErrorInterceptorHandler {
  final Completer<void> done = Completer<void>();

  @override
  void next(DioException err) => _finish();

  @override
  void reject(DioException error, [bool callFollowingErrorInterceptor = false]) =>
      _finish();

  @override
  void resolve(Response response) => _finish();

  void _finish() {
    if (!done.isCompleted) done.complete();
  }
}

/// Runs the error interceptor and waits for it to hand off to the handler.
Future<void> _runOnError(DioException err) async {
  final handler = _CapturingHandler();
  ApiErrorInterceptor(DefaultBaseXHttp()).onError(err, handler);
  await handler.done.future;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    XAuthStore.reset();
    XInstallMarker.reset();
    X = null;
    SharedPreferences.setMockInitialValues({'install_marker': true});
  });

  tearDown(() {
    XAuthStore.reset();
    XInstallMarker.reset();
  });

  group('signIn', () {
    test('stores the token and calls onSignedIn with meta + previous token', () async {
      final driver = await XAuthStore.bind(_RecordingDriver('old'));

      await driver.signIn('new', meta: const {'ability': 'user', 'userId': 7});

      expect(driver.cachedToken, 'new');
      expect(await driver.readToken(), 'new');
      expect(driver.signedInMeta.single, {'ability': 'user', 'userId': 7});
      expect(driver.signedInPreviousTokens.single, 'old');
    });

    test('reports a null previous token on a first sign-in', () async {
      final driver = await XAuthStore.bind(_RecordingDriver());

      await driver.signIn('first');

      expect(driver.signedInPreviousTokens.single, isNull);
      expect(driver.signedInMeta.single, isEmpty);
    });
  });

  group('signOut', () {
    test('calls remote once, clears the token and calls onSignedOut', () async {
      final driver = await XAuthStore.bind(_RecordingDriver('live'));
      var remoteCalls = 0;

      await driver.signOut(remote: () async => remoteCalls++);

      expect(remoteCalls, 1);
      expect(driver.cachedToken, isNull);
      expect(await driver.readToken(), isNull);
      expect(driver.signedOutCalls, 1);
    });

    test('swallows a throwing remote and still clears', () async {
      final driver = await XAuthStore.bind(_RecordingDriver('live'));

      await driver.signOut(remote: () async => throw Exception('boom'));

      expect(driver.cachedToken, isNull);
      expect(driver.signedOutCalls, 1);
    });

    test('skips remote when there is no token', () async {
      final driver = await XAuthStore.bind(_RecordingDriver());
      var remoteCalls = 0;

      await driver.signOut(remote: () async => remoteCalls++);

      expect(remoteCalls, 0);
      expect(driver.signedOutCalls, 1);
    });
  });

  group('onUnauthorized', () {
    test('clears the token by default', () async {
      final driver = await XAuthStore.bind(_RecordingDriver('live'));

      await driver.onUnauthorized();

      expect(driver.cachedToken, isNull);
      expect(await driver.readToken(), isNull);
      expect(driver.unauthorizedCalls, 1);
    });
  });

  group('ApiErrorInterceptor 401 handling', () {
    test('clears the token when the rejected bearer is the current one', () async {
      final driver = await XAuthStore.bind(_RecordingDriver('live'));

      await _runOnError(_unauthorizedError(requiredToken: true, bearer: 'live'));

      expect(driver.unauthorizedCalls, 1);
      expect(driver.cachedToken, isNull);
    });

    test('leaves a newer token alone when the rejected bearer differs', () async {
      final driver = await XAuthStore.bind(_RecordingDriver('newer'));

      await _runOnError(_unauthorizedError(requiredToken: true, bearer: 'stale'));

      expect(driver.unauthorizedCalls, 0);
      expect(driver.cachedToken, 'newer');
    });

    test('ignores a request that did not require a token', () async {
      final driver = await XAuthStore.bind(_RecordingDriver('live'));

      await _runOnError(_unauthorizedError(requiredToken: false, bearer: 'live'));

      expect(driver.unauthorizedCalls, 0);
      expect(driver.cachedToken, 'live');
    });

    test('ignores a non-401 failure', () async {
      final driver = await XAuthStore.bind(_RecordingDriver('live'));

      await _runOnError(
        _unauthorizedError(requiredToken: true, bearer: 'live', statusCode: 500),
      );

      expect(driver.unauthorizedCalls, 0);
      expect(driver.cachedToken, 'live');
    });
  });
}
