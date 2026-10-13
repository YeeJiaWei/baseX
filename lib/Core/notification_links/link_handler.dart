import 'package:baseX/Core/notification_links/link_guard.dart';
import 'package:baseX/Core/notification_links/link_match.dart';

/// A route for a path pattern; extend it for logic that deserves its own class.
abstract class LinkHandler {
  /// Path pattern, e.g. 'orders/{id:int}'.
  String get pattern;

  /// Checks run before [handle], in order.
  List<LinkGuard> get guards => const [];

  /// Skips the app-wide guards on the config.
  bool get public => false;

  /// Last-moment veto: false makes the router try the next matching route.
  Future<bool> canHandle(LinkMatch link) async => true;

  /// Does the work: navigate, call services, show a dialog.
  Future<void> handle(LinkMatch link);
}
