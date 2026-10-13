import 'package:baseX/Core/notification_links/link_guard.dart';
import 'package:baseX/Core/notification_links/link_match.dart';
import 'package:baseX/Core/notification_links/link_param.dart';

/// A route for push payloads, matched on the payload `type`.
abstract class EventHandler {
  /// Push types this handler serves.
  Set<String> get types;

  /// Fields that must be present and valid, else the handler is skipped.
  Map<String, LinkParam> get require => const {};

  /// Older key names for the same field.
  Map<String, List<String>> get aliases => const {};

  /// Checks run before [handle], in order.
  List<LinkGuard> get guards => const [];

  /// Skips the app-wide guards on the config.
  bool get public => false;

  /// Last-moment veto: false makes the router try the next handler.
  Future<bool> canHandle(LinkMatch event) async => true;

  /// Does the work for the event.
  Future<void> handle(LinkMatch event);
}
