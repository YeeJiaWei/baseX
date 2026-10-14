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
  bool _fetchingToken = false;

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

  @override
  Future<String?> getToken() async {
    _fetchingToken = true;
    try {
      final tokens = _client.tokenStream;
      final firstToken = tokens
          .firstWhere((token) => token.isNotEmpty)
          .timeout(tokenTimeout);
      _client.requestToken();
      final token = await firstToken;
      _lastToken = token;
      return token;
    } on TimeoutException {
      XLogger.warning(
        'HMS token not received within $tokenTimeout',
        className: 'HmsPushDriver',
      );
      return null;
    } catch (error) {
      XLogger.error(
        'HMS token fetch failed: $error',
        className: 'HmsPushDriver',
      );
      return null;
    } finally {
      _fetchingToken = false;
    }
  }

  @override
  Future<void> deleteToken() => _client.deleteToken();

  /// Tokens that [getToken] is already handing back, or that repeat the last one, are skipped.
  @override
  Stream<String> get onTokenRefresh => _client.tokenStream.where((token) {
    if (token.isEmpty || _fetchingToken || token == _lastToken) {
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
