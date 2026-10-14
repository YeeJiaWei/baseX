import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:baseX/Core/logger/x_logger.dart';
import 'package:baseX/Core/push/push_driver.dart';
import 'package:baseX/Core/push/push_handler.dart';
import 'package:baseX/Core/push/push_message.dart';
import 'package:baseX/Core/push/push_permission.dart';
import 'package:baseX/Core/push/push_platform.dart';
import 'package:baseX/Core/push/push_receipt.dart';
import 'package:baseX/Core/push/push_registration.dart';

/// Push plumbing every app repeats: permission, token lifecycle, listeners and dedup.
class PushNotifications extends GetxService with WidgetsBindingObserver {
  PushNotifications._(this._driver, this._handler);

  static const String tokenKey = 'push_token';
  static const String promptShownKey = 'push_prompt_shown';
  static const Duration unregisterTimeout = Duration(seconds: 5);

  static PushNotifications? _instance;

  /// The bound service; throws when [bind] has not run yet.
  static PushNotifications get instance {
    final service = _instance;
    if (service == null) {
      throw StateError('PushNotifications.instance accessed before bind()');
    }
    return service;
  }

  /// The bound service, or null when nothing has been bound.
  static PushNotifications? get maybeInstance => _instance;

  /// Wires listeners and fetches the token best-effort; never shows the OS prompt.
  static Future<PushNotifications> bind({
    required PushDriver driver,
    required PushHandler handler,
  }) async {
    _instance?.onClose();
    final service = PushNotifications._(driver, handler);
    _instance = service;
    await service._start();
    return service;
  }

  /// Drops the bound singleton.
  @visibleForTesting
  static void reset() {
    _instance?.onClose();
    _instance = null;
  }

  final PushDriver _driver;
  final PushHandler _handler;
  final List<StreamSubscription<Object?>> _subscriptions = [];
  final Set<String> _handledKeys = {};

  String? _token;

  /// The current device token; null until one has been fetched.
  String? get token => _token;

  /// Live OS permission, re-read on every app resume.
  final Rx<PushPermission> permission = PushPermission.notDetermined.obs;

  /// Whether notifications are authorized or provisional.
  bool get isAuthorized =>
      permission.value == PushPermission.authorized ||
      permission.value == PushPermission.provisional;

  /// Type of the last handled message; reset to null then set so `ever` fires on repeats.
  final Rxn<String> lastMessageType = Rxn<String>();

  Future<void> _start() async {
    await _guard('observe lifecycle', () async {
      WidgetsBinding.instance.addObserver(this);
    });
    await _guard('read permission', _readPermission);
    await _guard('foreground presentation', _driver.setForegroundPresentation);
    await _guard('wire listeners', () async => _wireListeners());
    await _guard('initial message', _handleInitialMessage);
    unawaited(_guard('fetch token', _fetchInitialToken));
  }

  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(this);
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    _subscriptions.clear();
    super.onClose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) onResumed();
  }

  /// Re-reads the permission and re-registers when it changed.
  @visibleForTesting
  Future<void> onResumed() => _guard('resume', () async {
        final previous = permission.value;
        await _readPermission();
        if (permission.value != previous) await refreshRegistration();
      });

  /// Shows the OS prompt once per install, then re-registers; later calls only re-read the permission.
  Future<PushPermission> promptIfNeeded() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await _readPermission();

      if (isAuthorized) {
        await prefs.setBool(promptShownKey, true);
        return permission.value;
      }
      if (prefs.getBool(promptShownKey) ?? false) return permission.value;

      permission.value = await _driver.requestPermission();
      await prefs.setBool(promptShownKey, true);
      await refreshRegistration();
    } catch (error) {
      XLogger.error('push prompt failed: $error',
          className: 'PushNotifications');
    }
    return permission.value;
  }

  /// Re-sends the current token with the live permission; failures are logged, not thrown.
  Future<void> refreshRegistration() async {
    try {
      await _readPermission();
      final currentToken =
          _token ?? await _loadStoredToken() ?? await _driver.getToken();
      if (currentToken == null) return;
      await _persistToken(currentToken);
      await _handler.registerToken(_registrationFor(currentToken));
    } catch (error) {
      XLogger.error('push registration failed: $error',
          className: 'PushNotifications');
    }
  }

  /// Removes the current token from the backend within [unregisterTimeout]; failures are logged, not thrown.
  Future<void> unregisterCurrentToken() async {
    try {
      final currentToken = _token ?? await _loadStoredToken();
      if (currentToken == null) return;
      await _handler
          .unregisterToken(currentToken)
          .timeout(unregisterTimeout);
    } on TimeoutException {
      XLogger.error('push unregister timed out after $unregisterTimeout',
          className: 'PushNotifications');
    } catch (error) {
      XLogger.error('push unregister failed: $error',
          className: 'PushNotifications');
    }
  }

  PushPlatform get _platform =>
      Platform.isIOS ? PushPlatform.ios : PushPlatform.android;

  PushRegistration _registrationFor(String deviceToken) => PushRegistration(
        token: deviceToken,
        platform: _platform,
        provider: _driver.provider,
        permission: permission.value,
      );

  Future<void> _guard(String step, Future<void> Function() action) async {
    try {
      await action();
    } catch (error) {
      XLogger.error('push $step failed: $error',
          className: 'PushNotifications');
    }
  }

  Future<void> _readPermission() async =>
      permission.value = await _driver.getPermission();

  void _wireListeners() {
    _subscriptions
      ..add(_driver.onForeground
          .listen(_handleForeground, onError: _logStreamError('foreground')))
      ..add(_driver.onOpened
          .listen(_handleOpened, onError: _logStreamError('opened')))
      ..add(_driver.onTokenRefresh.listen(
          (newToken) => _guard('token refresh', () => _applyToken(newToken)),
          onError: _logStreamError('token refresh')));
  }

  void Function(Object, StackTrace) _logStreamError(String stream) =>
      (error, stackTrace) => XLogger.error('push $stream stream failed: $error',
          className: 'PushNotifications');

  Future<void> _handleInitialMessage() async {
    final message = await _driver.getInitialMessage();
    if (message != null) _handleOpened(message);
  }

  Future<void> _fetchInitialToken() async {
    final fetched = await _driver.getToken();
    if (fetched == null) return;
    await _applyToken(fetched);
  }

  Future<void> _applyToken(String newToken) async {
    final previous = _token ?? await _loadStoredToken();
    await _persistToken(newToken);
    await _handler.registerToken(_registrationFor(newToken));
    if (previous != null && previous != newToken) {
      await _guard('unregister previous token',
          () => _handler.unregisterToken(previous));
    }
  }

  Future<String?> _loadStoredToken() async {
    final prefs = await SharedPreferences.getInstance();
    return _token = prefs.getString(tokenKey);
  }

  Future<void> _persistToken(String newToken) async {
    _token = newToken;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(tokenKey, newToken);
  }

  void _publishType(PushMessage message) {
    lastMessageType.value = null;
    lastMessageType.value = message.type;
  }

  void _handleForeground(PushMessage message) {
    try {
      _publishType(message);
      _handler.onReceipt(message, PushReceipt.received);
      _handler.onForeground(message);
    } catch (error) {
      XLogger.error('push foreground handler failed: $error',
          className: 'PushNotifications');
    }
  }

  void _handleOpened(PushMessage message) {
    try {
      final key = _handler.messageKey(message);
      if (key != null && !_handledKeys.add(key)) return;
      _publishType(message);
      _handler.onReceipt(message, PushReceipt.opened);
      _handler.onOpened(message);
    } catch (error) {
      XLogger.error('push opened handler failed: $error',
          className: 'PushNotifications');
    }
  }
}
