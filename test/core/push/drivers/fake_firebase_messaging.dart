import 'package:firebase_messaging/firebase_messaging.dart';

/// [FirebaseMessaging] answering permission calls with a fixed status; other members are unsupported.
class FakeFirebaseMessaging implements FirebaseMessaging {
  FakeFirebaseMessaging(this.status);

  final AuthorizationStatus status;

  NotificationSettings get _settings => NotificationSettings(
        alert: AppleNotificationSetting.enabled,
        announcement: AppleNotificationSetting.notSupported,
        authorizationStatus: status,
        badge: AppleNotificationSetting.enabled,
        carPlay: AppleNotificationSetting.notSupported,
        lockScreen: AppleNotificationSetting.enabled,
        notificationCenter: AppleNotificationSetting.enabled,
        showPreviews: AppleShowPreviewSetting.always,
        timeSensitive: AppleNotificationSetting.notSupported,
        criticalAlert: AppleNotificationSetting.notSupported,
        sound: AppleNotificationSetting.enabled,
        providesAppNotificationSettings: AppleNotificationSetting.notSupported,
      );

  @override
  Future<NotificationSettings> getNotificationSettings() async => _settings;

  @override
  Future<NotificationSettings> requestPermission({
    bool alert = true,
    bool announcement = false,
    bool badge = true,
    bool carPlay = false,
    bool criticalAlert = false,
    bool provisional = false,
    bool sound = true,
    bool providesAppNotificationSettings = false,
  }) async =>
      _settings;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} is not faked');
}
