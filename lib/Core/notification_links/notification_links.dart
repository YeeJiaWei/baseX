import 'package:baseX/Core/notification_links/event_handler.dart';
import 'package:baseX/Core/notification_links/guard_decision.dart';
import 'package:baseX/Core/notification_links/link_guard.dart';
import 'package:baseX/Core/notification_links/link_handler.dart';
import 'package:baseX/Core/notification_links/link_match.dart';
import 'package:baseX/Core/notification_links/link_pattern.dart';
import 'package:baseX/Core/notification_links/link_source.dart';
import 'package:baseX/Core/notification_links/notification_link_config.dart';

class _RouteEntry {
  const _RouteEntry(this.pattern, this.handler);

  final LinkPattern pattern;
  final LinkHandler handler;
}

/// Routes the links that notifications carry to the app's handlers.
class NotificationLinks {
  NotificationLinks._(this.config) : _routes = _buildRoutes(config.routes);

  static NotificationLinks? _instance;

  /// The bound router; throws when [bind] has not run yet.
  static NotificationLinks get instance {
    final links = _instance;
    if (links == null) {
      throw StateError('NotificationLinks.instance accessed before bind()');
    }
    return links;
  }

  /// The bound router, or null when nothing has been bound.
  static NotificationLinks? get maybeInstance => _instance;

  /// Validates [config]'s routes and registers it; throws when two routes tie.
  static void bind(NotificationLinkConfig config) {
    _instance = NotificationLinks._(config);
  }

  final NotificationLinkConfig config;
  final List<_RouteEntry> _routes;

  bool _held = false;
  Future<bool> Function()? _pending;

  static List<_RouteEntry> _buildRoutes(List<LinkHandler> handlers) {
    final entries = [
      for (final handler in handlers)
        _RouteEntry(LinkPattern.parse(handler.pattern), handler),
    ];

    for (var first = 0; first < entries.length; first++) {
      for (var second = first + 1; second < entries.length; second++) {
        if (entries[first].pattern.conflictsWith(entries[second].pattern)) {
          throw ArgumentError(
            'Routes "${entries[first].pattern.source}" and '
            '"${entries[second].pattern.source}" tie on every segment',
          );
        }
      }
    }

    entries.sort((first, second) =>
        first.pattern.compareSpecificity(second.pattern));
    return entries;
  }

  /// Routes [link]; true when a route ran.
  Future<bool> handle(String? link, {LinkSource source = LinkSource.inbox}) {
    if (_held) {
      _pending = () => _handleLink(link, source);
      return Future.value(false);
    }
    return _handleLink(link, source);
  }

  /// Routes a push event by [type] with its [params]; falls back to [link] when no event route handles it. True when a route ran.
  Future<bool> handleEvent(
    String type, {
    Map<String, dynamic> params = const {},
    String? link,
    LinkSource source = LinkSource.push,
  }) {
    if (_held) {
      _pending = () => _handleEvent(type, params, link, source);
      return Future.value(false);
    }
    return _handleEvent(type, params, link, source);
  }

  /// Queues incoming links instead of running them, until [release] or [discard].
  void hold() => _held = true;

  /// Queues [link] with its source and data without a global hold; it stays queued until [release] or [discard].
  void holdLink(LinkMatch link) {
    _pending = () => _handleUri(link.uri, link.source, link.eventParams);
  }

  /// Ends the hold and runs the queued link, if any.
  Future<void> release() async {
    _held = false;
    final pending = _pending;
    _pending = null;
    if (pending != null) await pending();
  }

  /// Ends the hold and drops the queued link.
  void discard() {
    _held = false;
    _pending = null;
  }

  Future<bool> _handleLink(String? link, LinkSource source) async {
    final uri = _parseLink(link);
    if (uri == null) {
      _reportUnknown(Uri());
      return false;
    }
    return _handleUri(uri, source, const {});
  }

  /// Plain paths (leading slash optional) and `scheme://path` links; null when blank or unparsable.
  Uri? _parseLink(String? link) {
    final trimmed = link?.trim() ?? '';
    if (trimmed.isEmpty) return null;
    if (trimmed.contains('://')) return Uri.tryParse(trimmed);
    return Uri.tryParse('/${trimmed.replaceFirst(RegExp(r'^/+'), '')}');
  }

  Future<bool> _handleUri(
    Uri uri,
    LinkSource source,
    Map<String, dynamic> eventParams,
  ) async {
    try {
      final configuredScheme = config.scheme;
      if (uri.hasScheme && uri.scheme != configuredScheme) {
        _reportUnknown(uri);
        return false;
      }

      final path = LinkPattern.pathSegmentsOf(uri);
      for (final route in _routes) {
        final matched = route.pattern.match(path);
        if (matched == null) continue;

        final link = LinkMatch(
          uri: uri,
          source: source,
          params: matched.params,
          rest: matched.rest,
          eventParams: eventParams,
        );
        final handled = await _attempt(
          link: link,
          public: route.handler.public,
          guards: route.handler.guards,
          canHandle: () => route.handler.canHandle(link),
          handle: () => route.handler.handle(link),
        );
        if (handled) return true;
      }

      _reportUnknown(uri);
      return false;
    } catch (error, stackTrace) {
      _reportError(uri, error, stackTrace);
      return false;
    }
  }

  /// Calls onUnknown; a throw goes to onError instead of escaping.
  void _reportUnknown(Uri uri) {
    try {
      config.onUnknown(uri);
    } catch (error, stackTrace) {
      _reportError(uri, error, stackTrace);
    }
  }

  /// Calls onError; a throw from it is swallowed so the router never rethrows.
  void _reportError(Uri uri, Object error, StackTrace stackTrace) {
    try {
      config.onError(uri, error, stackTrace);
    } catch (_) {}
  }

  Future<bool> _handleEvent(
    String type,
    Map<String, dynamic> eventParams,
    String? link,
    LinkSource source,
  ) async {
    final linkUri = _parseLink(link);
    final uri = linkUri ?? Uri(path: 'event/$type');

    try {
      for (final handler in config.events) {
        if (!handler.types.contains(type)) continue;

        final params = _requiredParams(handler, eventParams);
        if (params == null) continue;

        final event = LinkMatch(
          uri: uri,
          source: source,
          params: params,
          eventParams: eventParams,
        );
        final handled = await _attempt(
          link: event,
          public: handler.public,
          guards: handler.guards,
          canHandle: () => handler.canHandle(event),
          handle: () => handler.handle(event),
        );
        if (handled) return true;
      }
    } catch (error, stackTrace) {
      _reportError(uri, error, stackTrace);
      return false;
    }

    if (linkUri != null) return _handleUri(linkUri, source, eventParams);

    _reportUnknown(uri);
    return false;
  }

  Map<String, String>? _requiredParams(
    EventHandler handler,
    Map<String, dynamic> eventParams,
  ) {
    final params = <String, String>{};
    for (final entry in handler.require.entries) {
      final keys = [entry.key, ...?handler.aliases[entry.key]];
      final value = keys
          .map((key) => eventParams[key])
          .firstWhere((candidate) => candidate != null, orElse: () => null);
      if (!entry.value.accepts(value)) return null;
      params[entry.key] = value.toString();
    }
    return params;
  }

  /// Runs guards, then canHandle, then handle; true when the link is dealt with.
  Future<bool> _attempt({
    required LinkMatch link,
    required bool public,
    required List<LinkGuard> guards,
    required Future<bool> Function() canHandle,
    required Future<void> Function() handle,
  }) async {
    for (final guard in [if (!public) ...config.guards, ...guards]) {
      final result = await guard.check(link);
      switch (result.decision) {
        case GuardDecision.allow:
          break;
        case GuardDecision.skip:
          return false;
        case GuardDecision.stop:
          return true;
      }
    }

    if (!await canHandle()) return false;
    await handle();
    return true;
  }
}
