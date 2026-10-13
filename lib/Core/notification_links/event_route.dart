import 'package:baseX/Core/notification_links/event_handler.dart';
import 'package:baseX/Core/notification_links/link_guard.dart';
import 'package:baseX/Core/notification_links/link_match.dart';
import 'package:baseX/Core/notification_links/link_param.dart';

/// Closure shortcut for an [EventHandler].
class EventRoute extends EventHandler {
  EventRoute({
    required this.types,
    required this.action,
    this.require = const {},
    this.aliases = const {},
    this.guards = const [],
    this.public = false,
  });

  @override
  final Set<String> types;
  @override
  final Map<String, LinkParam> require;
  @override
  final Map<String, List<String>> aliases;
  @override
  final List<LinkGuard> guards;
  @override
  final bool public;

  final Future<void> Function(LinkMatch event) action;

  @override
  Future<void> handle(LinkMatch event) => action(event);
}
