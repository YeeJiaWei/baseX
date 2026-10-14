import 'dart:async';
import 'dart:convert';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:huawei_push/huawei_push.dart';

import 'package:baseX/Core/push/hms_push_client.dart';
import 'package:baseX/Core/push/hms_raw_message.dart';

/// [HmsPushClient] backed by the `huawei_push` plugin and `flutter_local_notifications`.
///
/// The plugin keeps one handler per event channel, so a second subscription replaces the
/// first and any cancel silences the channel. Each plugin stream is therefore subscribed
/// at most once, lazily, and never cancelled; every getter fans out from that single subscription.
class DefaultHmsPushClient implements HmsPushClient {
  /// The sources default to the `Push.*` streams; tests pass fakes.
  DefaultHmsPushClient({
    Stream<String> Function()? tokenSource,
    Stream<RemoteMessage> Function()? dataSource,
    Stream<dynamic> Function()? openedSource,
  }) {
    _tokens = _SharedStream<String>(tokenSource ?? () => Push.getTokenStream);
    _data = _SharedStream<HmsRawMessage>(
      () => (dataSource ?? () => Push.onMessageReceivedStream)().map(
        _fromRemoteMessage,
      ),
    );
    _opened = _SharedStream<HmsRawMessage>(
      () => (openedSource ?? () => Push.onNotificationOpenedApp)().map(
        _fromOpenedEvent,
      ),
    );
  }

  /// Token scope for the app's own AppGallery Connect project.
  static const String tokenScope = '';

  late final _SharedStream<String> _tokens;
  late final _SharedStream<HmsRawMessage> _data;
  late final _SharedStream<HmsRawMessage> _opened;

  AndroidFlutterLocalNotificationsPlugin? get _androidNotifications =>
      FlutterLocalNotificationsPlugin()
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();

  @override
  void requestToken() => Push.getToken(tokenScope);

  @override
  Stream<String> get tokenStream => _tokens.stream;

  @override
  Future<void> deleteToken() => Push.deleteToken(tokenScope);

  @override
  Stream<HmsRawMessage> get dataMessages => _data.stream;

  @override
  Stream<HmsRawMessage> get notificationOpened => _opened.stream;

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

/// Subscribes to [_source] on first access and re-broadcasts it; the subscription is never cancelled.
class _SharedStream<T> {
  _SharedStream(this._source);

  final Stream<T> Function() _source;
  final StreamController<T> _controller = StreamController<T>.broadcast();
  bool _subscribed = false;

  Stream<T> get stream {
    if (!_subscribed) {
      _subscribed = true;
      _source().listen(_controller.add, onError: _controller.addError);
    }
    return _controller.stream;
  }
}
