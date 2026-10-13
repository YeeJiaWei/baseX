import 'package:baseX/Core/push/push_message.dart';
import 'package:baseX/Core/push/push_permission.dart';
import 'package:baseX/Core/push/push_platform.dart';
import 'package:baseX/Core/push/push_receipt.dart';

/// App-side hooks for the domain-specific parts of push handling.
abstract class PushHandler {
  /// Sends the token and the live OS permission to the backend.
  Future<void> registerToken(
      String token, PushPlatform platform, PushPermission permission);

  /// Removes the token from the backend.
  Future<void> unregisterToken(String token);

  /// Called when a message arrives while the app is in the foreground.
  void onForeground(PushMessage message) {}

  /// Called on a tap on a push: app running, in background, or cold start.
  void onOpened(PushMessage message) {}

  /// Called with each delivery stage of a message.
  void onReceipt(PushMessage message, PushReceipt receipt) {}

  /// Key used to drop repeat taps; override when the backend sends its own delivery id.
  String? messageKey(PushMessage message) => message.id;
}
