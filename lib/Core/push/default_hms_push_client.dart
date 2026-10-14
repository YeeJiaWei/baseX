import 'dart:convert';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:huawei_push/huawei_push.dart';

import 'package:baseX/Core/push/hms_push_client.dart';
import 'package:baseX/Core/push/hms_raw_message.dart';

/// [HmsPushClient] backed by the `huawei_push` plugin and `flutter_local_notifications`.
class DefaultHmsPushClient implements HmsPushClient {
  /// Token scope for the app's own AppGallery Connect project.
  static const String tokenScope = '';

  AndroidFlutterLocalNotificationsPlugin? get _androidNotifications =>
      FlutterLocalNotificationsPlugin()
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();

  @override
  void requestToken() => Push.getToken(tokenScope);

  @override
  Stream<String> get tokenStream => Push.getTokenStream;

  @override
  Future<void> deleteToken() => Push.deleteToken(tokenScope);

  @override
  Stream<HmsRawMessage> get dataMessages =>
      Push.onMessageReceivedStream.map(_fromRemoteMessage);

  @override
  Stream<HmsRawMessage> get notificationOpened =>
      Push.onNotificationOpenedApp.map(_fromOpenedEvent);

  @override
  Future<HmsRawMessage?> initialNotification() async {
    final event = await Push.getInitialNotification();
    return event is Map ? _fromOpenedEvent(event) : null;
  }

  @override
  Future<void> registerBackgroundHandler(
    void Function(RemoteMessage message) handler,
  ) => Push.registerBackgroundMessageHandler(handler);

  @override
  Future<bool> areNotificationsEnabled() async =>
      await _androidNotifications?.areNotificationsEnabled() ?? false;

  @override
  Future<bool> requestNotificationsPermission() async =>
      await _androidNotifications?.requestNotificationsPermission() ?? false;

  HmsRawMessage _fromRemoteMessage(RemoteMessage message) => HmsRawMessage(
    id: message.messageId,
    rawData: message.data,
    title: message.notification?.title,
    body: message.notification?.body,
  );

  /// The tap event is `{uriPage, remoteMessage, extras}`; `remoteMessage.data` is a JSON string.
  HmsRawMessage _fromOpenedEvent(dynamic event) {
    final map = event is String ? jsonDecode(event) : event;
    final remote = map is Map ? map['remoteMessage'] : null;
    final extras = map is Map ? map['extras'] : null;
    final notification = remote is Map ? remote['notification'] : null;
    return HmsRawMessage(
      id: remote is Map ? remote['messageId']?.toString() : null,
      rawData: remote is Map ? remote['data']?.toString() : null,
      title: notification is Map ? notification['title']?.toString() : null,
      body: notification is Map ? notification['body']?.toString() : null,
      extras: extras is Map ? Map<String, dynamic>.from(extras) : const {},
    );
  }
}
