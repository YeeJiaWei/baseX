import 'dart:async';

import 'package:huawei_push/huawei_push.dart' show RemoteMessage;

import 'package:baseX/Core/index.dart';

/// Scriptable [HmsPushClient] with no platform channels.
class FakeHmsPushClient implements HmsPushClient {
  int tokenRequests = 0;
  int deleteCount = 0;
  bool notificationsEnabled = true;
  bool grantOnRequest = true;
  HmsRawMessage? initial;
  void Function(RemoteMessage message)? registeredBackgroundHandler;

  final tokenController = StreamController<String>.broadcast();
  final dataController = StreamController<HmsRawMessage>.broadcast();
  final openedController = StreamController<HmsRawMessage>.broadcast();

  @override
  void requestToken() => tokenRequests++;

  @override
  Stream<String> get tokenStream => tokenController.stream;

  @override
  Future<void> deleteToken() async => deleteCount++;

  @override
  Stream<HmsRawMessage> get dataMessages => dataController.stream;

  @override
  Stream<HmsRawMessage> get notificationOpened => openedController.stream;

  @override
  Future<HmsRawMessage?> initialNotification() async => initial;

  @override
  Future<void> registerBackgroundHandler(
    void Function(RemoteMessage message) handler,
  ) async {
    registeredBackgroundHandler = handler;
  }

  @override
  Future<bool> areNotificationsEnabled() async => notificationsEnabled;

  @override
  Future<bool> requestNotificationsPermission() async {
    notificationsEnabled = grantOnRequest;
    return grantOnRequest;
  }
}
