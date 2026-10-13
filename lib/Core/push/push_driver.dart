import 'package:baseX/Core/push/push_message.dart';
import 'package:baseX/Core/push/push_permission.dart';

/// Transport contract for a push provider (FCM, HMS, ...).
abstract class PushDriver {
  /// Reads the OS permission; never prompts.
  Future<PushPermission> getPermission();

  /// Shows the OS permission prompt.
  Future<PushPermission> requestPermission();

  /// Enables the system banner while the app is in the foreground (iOS).
  Future<void> setForegroundPresentation();

  /// Fetches the device token; null when unavailable.
  Future<String?> getToken();

  /// Invalidates the current device token.
  Future<void> deleteToken();

  /// Emits new tokens when the provider rotates them.
  Stream<String> get onTokenRefresh;

  /// Emits messages received while the app is in the foreground.
  Stream<PushMessage> get onForeground;

  /// Emits messages whose notification was tapped while the app was running.
  Stream<PushMessage> get onOpened;

  /// The message that launched the app from a terminated state, if any.
  Future<PushMessage?> getInitialMessage();
}
