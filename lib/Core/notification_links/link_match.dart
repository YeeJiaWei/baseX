import 'dart:core' as core;
import 'dart:core';

import 'package:baseX/Core/notification_links/link_pattern.dart';
import 'package:baseX/Core/notification_links/link_source.dart';

/// A link that matched a route, with the values the handler reads.
class LinkMatch {
  const LinkMatch({
    required this.uri,
    this.source = LinkSource.inbox,
    this.params = const {},
    this.rest = const [],
    this.eventParams = const {},
  });

  /// Builds the match [pattern] would produce for [uri]; for tests.
  factory LinkMatch.fromUri(
    Uri uri, {
    required String pattern,
    LinkSource source = LinkSource.inbox,
    Map<String, dynamic> eventParams = const {},
  }) {
    final matched =
        LinkPattern.parse(pattern).match(LinkPattern.pathSegmentsOf(uri));
    if (matched == null) {
      throw ArgumentError.value(
        uri,
        'uri',
        'does not match pattern "$pattern"',
      );
    }
    return LinkMatch(
      uri: uri,
      source: source,
      params: matched.params,
      rest: matched.rest,
      eventParams: eventParams,
    );
  }

  final Uri uri;
  final LinkSource source;
  final Map<String, String> params;

  /// Segments captured by a trailing `**`.
  final List<String> rest;

  /// The payload `params` with their JSON types when the link came from an event, else empty; [params] holds path params.
  final Map<String, dynamic> eventParams;

  /// The query string parameters.
  Map<String, String> get query => uri.queryParameters;

  /// A path param as text, or null when absent.
  String? param(String name) => params[name];

  /// A path param as an int; only valid on a `{name:int}` param.
  core.int int(String name) {
    final value = params[name];
    final parsed = value == null ? null : core.int.tryParse(value);
    if (parsed == null) {
      throw StateError('Param "$name" is missing or not an int: $value');
    }
    return parsed;
  }
}
