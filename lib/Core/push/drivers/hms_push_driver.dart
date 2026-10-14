import 'dart:async';
import 'dart:convert';

import 'package:huawei_push/huawei_push.dart' show RemoteMessage;

import 'package:baseX/Core/logger/x_logger.dart';
import 'package:baseX/Core/push/default_hms_push_client.dart';
import 'package:baseX/Core/push/hms_push_client.dart';
import 'package:baseX/Core/push/hms_raw_message.dart';
import 'package:baseX/Core/push/push_driver.dart';
import 'package:baseX/Core/push/push_message.dart';
import 'package:baseX/Core/push/push_permission.dart';
import 'package:baseX/Core/push/push_provider.dart';

/// [PushDriver] backed by Huawei Push Kit.
class HmsPushDriver implements PushDriver {
  /// [backgroundHandler] must be a top-level function annotated with `@pragma('vm:entry-point')`.
  HmsPushDriver({
    this.backgroundHandler,
    HmsPushClient? client,
    this.tokenTimeout = const Duration(seconds: 10),
  }) : _client = client ?? DefaultHmsPushClient() {
    final handler = backgroundHandler;
    if (handler != null) unawaited(_registerBackgroundHandler(handler));
  }

  final void Function(RemoteMessage message)? backgroundHandler;
  final Duration tokenTimeout;
  final HmsPushClient _client;

  String? _lastToken;
  Future<String?>? _tokenRequest;

  Future<void> _registerBackgroundHandler(
    void Function(RemoteMessage message) handler,
  ) async {
    try {
      await _client.registerBackgroundHandler(handler);
    } catch (error) {
      XLogger.error(
        'HMS background handler registration failed: $error',
        className: 'HmsPushDriver',
      );
    }
  }

  @override
  PushProvider get provider => PushProvider.hms;

  @override
  Future<PushPermission> getPermission() async =>
      (await _client.areNotificationsEnabled())
      ? PushPermission.authorized
      : PushPermission.denied;

  @override
  Future<PushPermission> requestPermission() async {
    await _client.requestNotificationsPermission();
    return getPermission();
  }

  @override
  Future<void> setForegroundPresentation() async {}

  /// Concurrent callers share one request; its subscription is always cancelled.
  @override
  Future<String?> getToken() => _tokenRequest ??= _requestToken().whenComplete(
    () => _tokenRequest = null,
  );

  Future<String?> _requestToken() async {
    final result = Completer<String?>();
    final subscription = _client.tokenStream.listen(
      (token) {
        if (token.isEmpty || result.isCompleted) return;
        _lastToken = token;
        result.complete(token);
      },
      onError: (Object error) {
        XLogger.error(
          'HMS token fetch failed: $error',
          className: 'HmsPushDriver',
        );
        if (!result.isCompleted) result.complete(null);
      },
    );
    final timeout = Timer(tokenTimeout, () {
      XLogger.warning(
        'HMS token not received within $tokenTimeout',
        className: 'HmsPushDriver',
      );
      if (!result.isCompleted) result.complete(null);
    });
    try {
      _client.requestToken();
      return await result.future;
    } catch (error) {
      XLogger.error(
        'HMS token fetch failed: $error',
        className: 'HmsPushDriver',
      );
      return null;
    } finally {
      timeout.cancel();
      await subscription.cancel();
    }
  }

  @override
  Future<void> deleteToken() => _client.deleteToken();

  /// Tokens that an in-flight [getToken] is handing back, or that repeat the last one, are skipped.
  @override
  Stream<String> get onTokenRefresh => _client.tokenStream.where((token) {
    if (token.isEmpty || _tokenRequest != null || token == _lastToken) {
      return false;
    }
    _lastToken = token;
    return true;
  });

  @override
  Stream<PushMessage> get onForeground => _client.dataMessages.map(_toMessage);

  @override
  Stream<PushMessage> get onOpened =>
      _client.notificationOpened.map(_toMessage);

  @override
  Future<PushMessage?> getInitialMessage() async {
    final raw = await _client.initialNotification();
    return raw == null ? null : _toMessage(raw);
  }

  PushMessage _toMessage(HmsRawMessage raw) {
    final data = _buildData(raw);
    return PushMessage(
      id: raw.id,
      type: data['type']?.toString(),
      title: raw.title,
      body: raw.body,
      data: data,
    );
  }

  /// Intent extras first, then the decoded `data` JSON on top, so the backend keys win.
  Map<String, dynamic> _buildData(HmsRawMessage raw) => {
    ...Map<String, dynamic>.of(raw.extras)..remove('data'),
    ..._decodeData(raw.extras['data']?.toString()),
    ..._decodeData(raw.rawData),
  };

  Map<String, dynamic> _decodeData(String? rawData) {
    if (rawData == null || rawData.trim().isEmpty) return const {};
    try {
      final decoded = jsonDecode(rawData);
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
      XLogger.warning(
        'HMS message data is not a JSON object',
        className: 'HmsPushDriver',
      );
    } catch (error) {
      XLogger.warning(
        'HMS message data is not valid JSON: $error',
        className: 'HmsPushDriver',
      );
    }
    return const {};
  }
}
