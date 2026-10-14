import 'package:baseX/Core/notification_links/notification_links.dart';
import 'package:baseX/Core/push/push_message.dart';
import 'package:baseX/Core/push/push_provider.dart';
import 'package:baseX/Core/push/push_receipt.dart';
import 'package:baseX/Core/push/push_registration.dart';

/// App-side hooks for the domain-specific parts of push handling.
abstract class PushHandler {
  /// Sends the token, its provider and the live OS permission to the backend.
  Future<void> registerToken(PushRegistration registration);

  /// Removes the token from the backend; [provider] is the service the token was issued by.
  Future<void> unregisterToken(String token, PushProvider provider);

  /// Called when a message arrives while the app is in the foreground.
  void onForeground(PushMessage message) {}

  /// Called on a tap on a push: app running, in background, or cold start; routes it through [NotificationLinks] when bound.
  void onOpened(PushMessage message) {
    NotificationLinks.maybeInstance?.handleEvent(
      message.payload.type ?? '',
      params: message.payload.params,
      link: message.payload.link,
    );
  }

  /// Called with each delivery stage of a message.
  void onReceipt(PushMessage message, PushReceipt receipt) {}

  /// Key used to drop repeat taps: the payload delivery id, else the platform message id.
  String? messageKey(PushMessage message) =>
      message.payload.deliveryId ?? message.id;
}
