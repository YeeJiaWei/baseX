import 'dart:async';

import 'package:huawei_push/huawei_push.dart' show RemoteMessage;

import 'package:baseX/Core/index.dart';

import 'fake_plugin_event_channel.dart';

/// Scriptable [HmsPushClient] with no platform channels.
///
/// Tokens flow through the real [DefaultHmsPushClient] fan-out over a single-handler [tokenChannel].
class FakeHmsPushClient implements HmsPushClient {
  FakeHmsPushClient() {
    _shared = DefaultHmsPushClient(tokenSource: () => tokenChannel.stream);
  }

  final tokenChannel = FakePluginEventChannel<String>();
  late final DefaultHmsPushClient _shared;

  /// Subscriptions currently open on [tokenStream].
  int activeTokenListeners = 0;

  int tokenRequests = 0;
  int deleteCount = 0;
  bool notificationsEnabled = true;
  bool grantOnRequest = true;
  HmsRawMessage? initial;
  void Function(RemoteMessage message)? registeredBackgroundHandler;

  final dataController = StreamController<HmsRawMessage>.broadcast();
  final openedController = StreamController<HmsRawMessage>.broadcast();

  @override
  void requestToken() => tokenRequests++;

  @override
  Stream<String> get tokenStream => Stream<String>.multi((controller) {
    activeTokenListeners++;
    final subscription = _shared.tokenStream.listen(
      controller.add,
      onError: controller.addError,
    );
    controller.onCancel = () {
      activeTokenListeners--;
      return subscription.cancel();
    };
  });

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
