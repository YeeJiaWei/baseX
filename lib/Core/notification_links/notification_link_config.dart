import 'package:baseX/Core/logger/x_logger.dart';
import 'package:baseX/Core/notification_links/event_handler.dart';
import 'package:baseX/Core/notification_links/link_guard.dart';
import 'package:baseX/Core/notification_links/link_handler.dart';

/// The app's route table for notification links.
abstract class NotificationLinkConfig {
  /// Optional scheme links may carry, e.g. 'shop' for `shop://orders/1042`; plain paths always route.
  String? get scheme => null;

  /// Path routes; order does not matter, precedence decides.
  List<LinkHandler> get routes;

  /// Push-payload routes, tried before falling back to the payload link.
  List<EventHandler> get events => const [];

  /// Guards run before every route's own guards; a route opts out with `public`.
  List<LinkGuard> get guards => const [];

  /// Called when nothing matched.
  void onUnknown(Uri uri) => XLogger.warning(
        'No notification route for $uri',
        className: 'NotificationLinks',
      );

  /// Called when a handler or guard throws; the router never rethrows.
  void onError(Uri uri, Object error, StackTrace stackTrace) => XLogger.error(
        'Notification link $uri failed: $error',
        className: 'NotificationLinks',
      );
}
