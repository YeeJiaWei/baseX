import 'package:huawei_push/huawei_push.dart' show RemoteMessage;

import 'package:baseX/Core/push/hms_raw_message.dart';

/// Seam over the `huawei_push` static API and the Android notification permission so [HmsPushDriver] can be tested without platform channels.
abstract class HmsPushClient {
  /// Asks the Push SDK for a token; it arrives on [tokenStream].
  void requestToken();

  /// Emits tokens the Push SDK produced.
  Stream<String> get tokenStream;

  /// Deletes the push token.
  Future<void> deleteToken();

  /// Emits data messages received in the foreground.
  Stream<HmsRawMessage> get dataMessages;

  /// Emits taps on notification messages while the app is running.
  Stream<HmsRawMessage> get notificationOpened;

  /// The notification that launched the app, if any.
  Future<HmsRawMessage?> initialNotification();

  /// Registers a top-level function for data messages received in the background.
  Future<void> registerBackgroundHandler(
    void Function(RemoteMessage message) handler,
  );

  /// Whether the OS lets this app show notifications.
  Future<bool> areNotificationsEnabled();

  /// Shows the Android 13+ notification prompt; true when granted.
  Future<bool> requestNotificationsPermission();
}
