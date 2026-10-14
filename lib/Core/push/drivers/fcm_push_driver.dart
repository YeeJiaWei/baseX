import 'dart:async';
import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';

import 'package:baseX/Core/logger/x_logger.dart';
import 'package:baseX/Core/push/push_driver.dart';
import 'package:baseX/Core/push/push_message.dart';
import 'package:baseX/Core/push/push_payload.dart';
import 'package:baseX/Core/push/push_permission.dart';
import 'package:baseX/Core/push/push_provider.dart';

/// [PushDriver] backed by Firebase Cloud Messaging.
class FcmPushDriver implements PushDriver {
  /// [backgroundHandler] must be a top-level function annotated with `@pragma('vm:entry-point')`.
  FcmPushDriver({this.backgroundHandler, FirebaseMessaging? messaging})
      : _messaging = messaging ?? FirebaseMessaging.instance {
    final handler = backgroundHandler;
    if (handler != null) FirebaseMessaging.onBackgroundMessage(handler);
  }

  final Future<void> Function(RemoteMessage message)? backgroundHandler;
  final FirebaseMessaging _messaging;

  static const int _apnsAttempts = 20;
  static const Duration _apnsInterval = Duration(milliseconds: 500);

  @override
  PushProvider get provider => PushProvider.fcm;

  @override
  Future<PushPermission> getPermission() async => _mapStatus(
      (await _messaging.getNotificationSettings()).authorizationStatus);

  @override
  Future<PushPermission> requestPermission() async =>
      _mapStatus((await _messaging.requestPermission()).authorizationStatus);

  @override
  Future<void> setForegroundPresentation() =>
      _messaging.setForegroundNotificationPresentationOptions(
          alert: true, badge: true, sound: true);

  @override
  Future<String?> getToken() async {
    if (Platform.isIOS && !await _waitForApnsToken()) {
      XLogger.warning('APNS token unavailable; skipping FCM token fetch',
          className: 'FcmPushDriver');
      return null;
    }
    return _messaging.getToken();
  }

  @override
  Future<void> deleteToken() => _messaging.deleteToken();

  @override
  Stream<String> get onTokenRefresh => _messaging.onTokenRefresh;

  @override
  Stream<PushMessage> get onForeground =>
      FirebaseMessaging.onMessage.map(_toMessage);

  @override
  Stream<PushMessage> get onOpened =>
      FirebaseMessaging.onMessageOpenedApp.map(_toMessage);

  @override
  Future<PushMessage?> getInitialMessage() async {
    final message = await _messaging.getInitialMessage();
    return message == null ? null : _toMessage(message);
  }

  Future<bool> _waitForApnsToken() async {
    for (var attempt = 0; attempt < _apnsAttempts; attempt++) {
      if (await _messaging.getAPNSToken() != null) return true;
      await Future<void>.delayed(_apnsInterval);
    }
    return false;
  }

  PushPermission _mapStatus(AuthorizationStatus status) {
    switch (status) {
      case AuthorizationStatus.authorized:
        return PushPermission.authorized;
      case AuthorizationStatus.provisional:
        return PushPermission.provisional;
      case AuthorizationStatus.denied:
        return PushPermission.denied;
      case AuthorizationStatus.notDetermined:
        return PushPermission.notDetermined;
    }
  }

  PushMessage _toMessage(RemoteMessage message) {
    final data = Map<String, dynamic>.from(message.data);
    return PushMessage(
      id: message.messageId,
      title: message.notification?.title,
      body: message.notification?.body,
      payload: PushPayload.fromData(data),
      data: data,
    );
  }
}
