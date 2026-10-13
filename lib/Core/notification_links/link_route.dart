import 'package:baseX/Core/notification_links/link_guard.dart';
import 'package:baseX/Core/notification_links/link_handler.dart';
import 'package:baseX/Core/notification_links/link_match.dart';

/// Closure shortcut for a [LinkHandler].
class LinkRoute extends LinkHandler {
  LinkRoute(
    this.pattern,
    this.action, {
    this.guards = const [],
    this.public = false,
  });

  @override
  final String pattern;
  @override
  final List<LinkGuard> guards;
  @override
  final bool public;

  final Future<void> Function(LinkMatch link) action;

  @override
  Future<void> handle(LinkMatch link) => action(link);
}
